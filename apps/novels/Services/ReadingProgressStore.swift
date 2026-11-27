import CloudKit
import Foundation

nonisolated struct ReadingProgress: Codable, Equatable {
    struct Anchor: Codable, Equatable, Hashable {
        let rendition: String
        let paragraph: Int

        func index(in rendition: String, count: Int) -> Int? {
            guard self.rendition == rendition, (0 ..< count).contains(paragraph) else { return nil }
            return paragraph
        }
    }

    let chapter: Int
    let anchor: Anchor?
    let updatedAt: Date

    func supersedesLocal(_ local: Self?) -> Bool {
        local.map { updatedAt >= $0.updatedAt } ?? true
    }

    func fits(chapterCount: Int) -> Bool {
        chapter > 0 && chapter <= chapterCount
    }

    static func decode(_ data: Data) -> Self? {
        guard let progress = try? JSONDecoder().decode(Self.self, from: data),
              progress.chapter > 0, progress.anchor.map({ $0.paragraph >= 0 }) ?? true
        else { return nil }
        return progress
    }
}

@MainActor
final class ReadingProgressStore {
    static let shared = ReadingProgressStore()

    private struct Entry: Codable, Equatable {
        let progress: ReadingProgress
        let isLocal: Bool
        let pending: Bool
    }

    private let defaults = UserDefaults.standard
    private lazy var repository = FileBookRepository(root: AppPaths.booksRoot())
    private let storageKey = "readingProgress.v1"
    private lazy var entries = loadEntries()
    private lazy var database = CKContainer(identifier: "iCloud.com.tungxuan.novels").privateCloudDatabase
    private var inFlight: [String: Task<Void, Never>] = [:]

    func progressOnOpen(bookId: String) async -> (progress: ReadingProgress, isLocal: Bool)? {
        let sync = synchronize(bookId: bookId)
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let fetch = Task {
            await sync.value
            continuation.finish()
        }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(2))
            continuation.finish()
        }
        for await _ in stream {}
        fetch.cancel()
        timeout.cancel()
        return entries[bookId].map { ($0.progress, $0.isLocal) }
    }

    func save(bookId: String, chapter: Int, anchor: ReadingProgress.Anchor?) {
        let previous = entries[bookId]?.progress
        let now = Date()
        let updatedAt = max(now, previous?.updatedAt.addingTimeInterval(0.001) ?? now)
        let progress = ReadingProgress(chapter: chapter, anchor: anchor, updatedAt: updatedAt)
        setEntry(Entry(progress: progress, isLocal: true, pending: true), bookId: bookId)
        synchronize(bookId: bookId)
    }

    func retryPending() {
        for (bookId, entry) in entries where entry.pending {
            synchronize(bookId: bookId)
        }
    }

    @discardableResult
    private func synchronize(bookId: String) -> Task<Void, Never> {
        if let running = inFlight[bookId] {
            return running
        }
        let task = Task {
            defer { inFlight[bookId] = nil }
            do {
                // One retry reads the changed record before attempting another conditional save.
                do {
                    try await reconcile(bookId: bookId)
                } catch let error as CKError where error.code == .serverRecordChanged {
                    try await reconcile(bookId: bookId)
                }
            } catch {
                // Keep unsent local progress for the next open or foreground entry.
            }
        }
        inFlight[bookId] = task
        return task
    }

    private func reconcile(bookId: String) async throws {
        let id = CKRecord.ID(recordName: SHA256.hex(bookId))
        var record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "ReadingProgress", recordID: id)
        }
        let remote = (record["checkpoint"] as? Data).flatMap(ReadingProgress.decode)
        if let remote, remote.supersedesLocal(entries[bookId]?.progress) {
            guard let book = try repository.book(slug: bookId), remote.fits(chapterCount: book.count) else { return }
            let isLocal = entries[bookId]?.isLocal == true && entries[bookId]?.progress == remote
            setEntry(Entry(progress: remote, isLocal: isLocal, pending: false), bookId: bookId)
            return
        }
        while let entry = entries[bookId], entry.pending {
            let progress = entry.progress
            record["checkpoint"] = try JSONEncoder().encode(progress) as NSData
            let result = try await database.modifyRecords(saving: [record], deleting: [])
            guard let saved = result.saveResults[id] else { return }
            record = try saved.get()
            if entries[bookId]?.progress == progress {
                setEntry(Entry(progress: progress, isLocal: true, pending: false), bookId: bookId)
            }
        }
    }

    private func loadEntries() -> [String: Entry] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private func setEntry(_ entry: Entry, bookId: String) {
        guard entries[bookId] != entry else { return }
        entries[bookId] = entry
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
