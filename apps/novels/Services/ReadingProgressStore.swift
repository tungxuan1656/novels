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

    nonisolated struct Entry: Codable, Equatable {
        let progress: ReadingProgress
        let isLocal: Bool
        let pending: Bool

        func resolving(_ remote: ReadingProgress, chapterCount: Int) -> Self {
            guard remote.fits(chapterCount: chapterCount) else {
                return Self(progress: progress, isLocal: isLocal, pending: false)
            }
            return Self(progress: remote, isLocal: isLocal && progress == remote, pending: false)
        }
    }

    private struct Account {
        let owner: String
        let token: (any NSObjectProtocol)?
        let generation: Int
    }

    private let defaults = UserDefaults.standard
    private lazy var repository = FileBookRepository(root: AppPaths.booksRoot())
    private let storageKey = "readingProgress.v2"
    private let localOnly = "local"
    private lazy var entries = loadEntries()
    private lazy var container = CKContainer(identifier: "iCloud.com.tungxuan.novels")
    private var inFlight: [String: Task<Bool, Never>] = [:]
    private var account: Account?
    private var generation = 0
    private var accountObservers: [any NSObjectProtocol] = []

    private init() {
        accountObservers = [Notification.Name.CKAccountChanged, .NSUbiquityIdentityDidChange].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.accountChanged() }
            }
        }
    }

    func progressOnOpen(bookId: String) async -> (progress: ReadingProgress, isLocal: Bool)? {
        let sync = synchronize(bookId: bookId)
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let fetch = Task {
            continuation.yield(await sync.value)
            continuation.finish()
        }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(2))
            continuation.finish()
        }
        var result = stream.makeAsyncIterator()
        let verified = await result.next() == true
        fetch.cancel()
        timeout.cancel()
        let entry = verified ? latestEntry(bookId: bookId) : entries[localOnly]?[bookId]
        return entry.map { ($0.progress, $0.isLocal) }
    }

    func save(bookId: String, chapter: Int, anchor: ReadingProgress.Anchor?) {
        let known = account.flatMap { isCurrent($0) ? $0 : nil }
        let previous = latestEntry(bookId: bookId)?.progress
        let now = Date()
        let updatedAt = max(now, previous?.updatedAt.addingTimeInterval(0.001) ?? now)
        let progress = ReadingProgress(chapter: chapter, anchor: anchor, updatedAt: updatedAt)
        setEntry(Entry(progress: progress, isLocal: true, pending: false), bookId: bookId, owner: localOnly)
        if let known, known.token != nil {
            enqueue(progress, bookId: bookId, owner: known.owner)
            return
        }
        guard let known else {
            synchronize(bookId: bookId)
            return
        }
        Task {
            // CloudKit-only signing may have no ubiquity token. Verify this edit against the known account now.
            guard let verified = try? await verifiedAccount(), verified.owner == known.owner,
                  verified.generation == known.generation, entries[localOnly]?[bookId]?.progress == progress,
                  (entries[verified.owner]?[bookId]?.progress.updatedAt ?? .distantPast) < updatedAt
            else { return }
            enqueue(progress, bookId: bookId, owner: verified.owner)
        }
    }

    private func enqueue(_ progress: ReadingProgress, bookId: String, owner: String) {
        setEntry(Entry(progress: progress, isLocal: true, pending: true), bookId: bookId, owner: owner)
        synchronize(bookId: bookId)
    }

    func retryPending() {
        Task {
            guard let verified = try? await verifiedAccount() else { return }
            for (bookId, entry) in entries[verified.owner, default: [:]] where entry.pending {
                synchronize(bookId: bookId)
            }
        }
    }

    private var identityToken: (any NSObjectProtocol)? {
        FileManager.default.ubiquityIdentityToken
    }

    private var currentOwner: String? {
        guard let account, isCurrent(account) else { return nil }
        return account.owner
    }

    private func isCurrent(_ verified: Account) -> Bool {
        verified.generation == generation && tokensMatch(verified.token, identityToken)
    }

    private func tokensMatch(_ before: (any NSObjectProtocol)?, _ after: (any NSObjectProtocol)?) -> Bool {
        before?.isEqual(after) ?? (after == nil)
    }

    private func verifiedAccount() async throws -> Account? {
        let started = generation
        let token = identityToken
        let id = try await container.userRecordID()
        guard !Task.isCancelled, started == generation, tokensMatch(token, identityToken) else { return nil }
        let owner = SHA256.hex(id.recordName)
        if let account, account.owner != owner {
            invalidateAccount()
        }
        let verified = Account(owner: owner, token: token, generation: generation)
        account = verified
        return verified
    }

    private func invalidateAccount() {
        generation += 1
        account = nil
    }

    private func accountChanged() {
        invalidateAccount()
        for task in inFlight.values {
            task.cancel()
        }
        inFlight.removeAll()
        retryPending()
    }

    @discardableResult
    private func synchronize(bookId: String) -> Task<Bool, Never> {
        if let running = inFlight[bookId] {
            return running
        }
        let task = Task {
            defer {
                if !Task.isCancelled {
                    inFlight[bookId] = nil
                }
            }
            do {
                guard let verified = try await verifiedAccount() else { return false }
                // Retry one conditional-write conflict, but never in a different account.
                do {
                    try await reconcile(bookId: bookId, account: verified)
                } catch let error as CKError where error.code == .serverRecordChanged {
                    guard let refreshed = try await verifiedAccount(), refreshed.owner == verified.owner,
                          refreshed.generation == verified.generation else { return false }
                    try await reconcile(bookId: bookId, account: refreshed)
                }
                return !Task.isCancelled && isCurrent(verified)
            } catch {
                // Keep unsent local progress for the next open or foreground entry.
                return false
            }
        }
        inFlight[bookId] = task
        return task
    }

    private func reconcile(bookId: String, account verified: Account) async throws {
        guard !Task.isCancelled, isCurrent(verified) else { return }
        let owner = verified.owner
        let database = container.privateCloudDatabase
        let id = CKRecord.ID(recordName: SHA256.hex(bookId))
        var record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "ReadingProgress", recordID: id)
        }
        guard let fetchedFor = try await verifiedAccount(), fetchedFor.owner == owner,
              fetchedFor.generation == verified.generation, isCurrent(fetchedFor) else { return }
        let local = entries[owner]?[bookId]
        let remote = (record["checkpoint"] as? Data).flatMap(ReadingProgress.decode)
        if let remote, remote.supersedesLocal(local?.progress) {
            let count = try repository.book(slug: bookId)?.count ?? 0
            if let local {
                setEntry(local.resolving(remote, chapterCount: count), bookId: bookId, owner: owner)
            } else if remote.fits(chapterCount: count) {
                setEntry(Entry(progress: remote, isLocal: false, pending: false), bookId: bookId, owner: owner)
            }
            return
        }
        while entries[owner]?[bookId]?.pending == true {
            // Revalidate after the fetch and every suspension before submitting private data.
            guard let refreshed = try await verifiedAccount(), refreshed.owner == owner,
                  refreshed.generation == verified.generation, isCurrent(refreshed),
                  let entry = entries[owner]?[bookId], entry.pending else { return }
            let progress = entry.progress
            record["checkpoint"] = try JSONEncoder().encode(progress) as NSData
            let result = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .ifServerRecordUnchanged
            )
            guard !Task.isCancelled, isCurrent(refreshed), let saved = result.saveResults[id] else { return }
            record = try saved.get()
            if entries[owner]?[bookId] == entry {
                setEntry(Entry(progress: progress, isLocal: true, pending: false), bookId: bookId, owner: owner)
            }
        }
    }

    private func latestEntry(bookId: String) -> Entry? {
        let local = entries[localOnly]?[bookId]
        guard let owner = currentOwner, let scoped = entries[owner]?[bookId] else { return local }
        return scoped.progress.supersedesLocal(local?.progress) ? scoped : local
    }

    private func loadEntries() -> [String: [String: Entry]] {
        let decoder = JSONDecoder()
        let stored = defaults.data(forKey: storageKey)
        if let stored, let decoded = try? decoder.decode([String: [String: Entry]].self, from: stored) {
            return decoded
        }
        guard let data = defaults.data(forKey: "readingProgress.v1") else { return [:] }
        return [localOnly: Self.localEntries(from: data)]
    }

    nonisolated static func localEntries(from legacyData: Data) -> [String: Entry] {
        let legacy = (try? JSONDecoder().decode([String: Entry].self, from: legacyData)) ?? [:]
        // Old edits have no account provenance. Keep them on this device only.
        return legacy.filter(\.value.isLocal).mapValues {
            Entry(progress: $0.progress, isLocal: true, pending: false)
        }
    }

    private func setEntry(_ entry: Entry, bookId: String, owner: String) {
        guard entries[owner]?[bookId] != entry else { return }
        entries[owner, default: [:]][bookId] = entry
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
