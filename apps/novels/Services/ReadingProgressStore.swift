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
    static let shared: ReadingProgressStore = {
        let store = ReadingProgressStore(
            defaults: .standard,
            cloud: ReadingProgressCloud.live(),
            chapterCount: { try FileBookRepository(root: AppPaths.booksRoot()).book(slug: $0)?.count ?? 0 }
        )
        if store.cloud != nil {
            store.observeAccount()
        }
        return store
    }()

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
        let token: String?
        let generation: Int
    }

    private struct Binding: Codable {
        let token: String
        let owner: String
    }

    private let defaults: UserDefaults
    private let cloud: ReadingProgressCloud?
    private let chapterCount: (String) throws -> Int
    private let storageKey = "readingProgress.v2"
    private let bindingKey = "readingProgress.account.v1"
    private let localOnly = "local"
    private lazy var entries = loadEntries()
    private lazy var binding = loadBinding()
    private var provisional: [String: (token: String, progress: ReadingProgress)] = [:]
    private var inFlight: [String: Task<Bool, Never>] = [:]
    private var account: Account?
    private var generation = 0

    init(defaults: UserDefaults, cloud: ReadingProgressCloud?, chapterCount: @escaping (String) throws -> Int) {
        self.defaults = defaults
        self.cloud = cloud
        self.chapterCount = chapterCount
    }

    private func observeAccount() {
        for name in [Notification.Name.CKAccountChanged, .NSUbiquityIdentityDidChange] {
            _ = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.accountChanged() }
            }
        }
    }

    func progressOnOpen(bookId: String) async -> (progress: ReadingProgress, isLocal: Bool)? {
        guard cloud != nil else { return entries[localOnly]?[bookId].map { ($0.progress, true) } }
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
        let token = cloud?.token()
        let known = account.flatMap { isCurrent($0) ? $0 : nil }
        let previous = latestEntry(bookId: bookId)?.progress
        let now = Date()
        let updatedAt = max(now, previous?.updatedAt.addingTimeInterval(0.001) ?? now)
        let progress = ReadingProgress(chapter: chapter, anchor: anchor, updatedAt: updatedAt)
        setEntry(Entry(progress: progress, isLocal: true, pending: false), bookId: bookId, owner: localOnly)
        guard cloud != nil else { return }
        if let token {
            if let owner = known?.owner ?? (binding?.token == token ? binding?.owner : nil) {
                enqueue(progress, bookId: bookId, owner: owner)
            } else {
                provisional[bookId] = (token, progress)
                synchronize(bookId: bookId)
            }
        } else if let known {
            // Without a token, verify this edit immediately against the previously known account.
            Task {
                guard let verified = try? await verifiedAccount(), verified.owner == known.owner,
                      verified.generation == known.generation, entries[localOnly]?[bookId]?.progress == progress,
                      (entries[verified.owner]?[bookId]?.progress.updatedAt ?? .distantPast) < updatedAt
                else { return }
                enqueue(progress, bookId: bookId, owner: verified.owner)
            }
        } else {
            synchronize(bookId: bookId)
        }
    }

    private func enqueue(_ progress: ReadingProgress, bookId: String, owner: String) {
        setEntry(Entry(progress: progress, isLocal: true, pending: true), bookId: bookId, owner: owner)
        synchronize(bookId: bookId)
    }

    @discardableResult
    func retryPending() -> Task<Void, Never> {
        Task {
            guard let verified = try? await verifiedAccount() else { return }
            let tasks = entries[verified.owner, default: [:]].filter(\.value.pending)
                .map { synchronize(bookId: $0.key) }
            for task in tasks {
                _ = await task.value
            }
        }
    }

    private var currentOwner: String? {
        guard let account, isCurrent(account) else { return nil }
        return account.owner
    }

    private func isCurrent(_ verified: Account) -> Bool {
        verified.generation == generation && verified.token == cloud?.token()
    }

    private func verifiedAccount() async throws -> Account? {
        guard let cloud else { return nil }
        let started = generation
        let token = cloud.token()
        let owner = try await cloud.owner()
        guard !Task.isCancelled, started == generation, token == cloud.token() else { return nil }
        if let account, account.owner != owner {
            invalidateAccount()
        }
        let verified = Account(owner: owner, token: token, generation: generation)
        account = verified
        if let token, binding?.token != token || binding?.owner != owner {
            let current = Binding(token: token, owner: owner)
            binding = current
            defaults.set(try? JSONEncoder().encode(current), forKey: bindingKey)
        }
        let candidates = provisional
        provisional.removeAll()
        for (bookId, candidate) in candidates where candidate.token == token {
            guard entries[localOnly]?[bookId]?.progress == candidate.progress,
                  (entries[owner]?[bookId]?.progress.updatedAt ?? .distantPast) < candidate.progress.updatedAt
            else { continue }
            enqueue(candidate.progress, bookId: bookId, owner: owner)
        }
        return verified
    }

    private func invalidateAccount() {
        generation += 1
        account = nil
        provisional.removeAll()
    }

    @discardableResult
    func accountChanged() -> Task<Void, Never> {
        invalidateAccount()
        for task in inFlight.values {
            task.cancel()
        }
        inFlight.removeAll()
        return retryPending()
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
        guard let cloud, !Task.isCancelled, isCurrent(verified) else { return }
        let owner = verified.owner
        let id = CKRecord.ID(recordName: SHA256.hex(bookId))
        var record: CKRecord
        do {
            record = try await cloud.fetch(id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "ReadingProgress", recordID: id)
        }
        guard let fetchedFor = try await verifiedAccount(), fetchedFor.owner == owner,
              fetchedFor.generation == verified.generation, isCurrent(fetchedFor) else { return }
        let local = entries[owner]?[bookId]
        let remote = (record["checkpoint"] as? Data).flatMap(ReadingProgress.decode)
        if let remote, remote.supersedesLocal(local?.progress) {
            let count = try chapterCount(bookId)
            if let local {
                setEntry(local.resolving(remote, chapterCount: count), bookId: bookId, owner: owner)
            } else if remote.fits(chapterCount: count) {
                setEntry(Entry(progress: remote, isLocal: false, pending: false), bookId: bookId, owner: owner)
            }
            return
        }
        var checked = fetchedFor
        while let entry = entries[owner]?[bookId], entry.pending {
            let progress = entry.progress
            record["checkpoint"] = try JSONEncoder().encode(progress) as NSData
            record = try await cloud.save(record)
            guard !Task.isCancelled, isCurrent(checked) else { return }
            if entries[owner]?[bookId] == entry {
                setEntry(Entry(progress: progress, isLocal: true, pending: false), bookId: bookId, owner: owner)
                return
            }
            // A newer edit arrived during the write. Revalidate before sending it.
            guard let refreshed = try await verifiedAccount(), refreshed.owner == owner,
                  refreshed.generation == verified.generation, isCurrent(refreshed) else { return }
            checked = refreshed
        }
    }

    private func latestEntry(bookId: String) -> Entry? {
        let local = entries[localOnly]?[bookId]
        guard let owner = currentOwner, let scoped = entries[owner]?[bookId] else { return local }
        return scoped.progress.supersedesLocal(local?.progress) ? scoped : local
    }

    private func loadBinding() -> Binding? {
        guard let data = defaults.data(forKey: bindingKey) else { return nil }
        return try? JSONDecoder().decode(Binding.self, from: data)
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
