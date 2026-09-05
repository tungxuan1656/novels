// swiftlint:disable:next blanket_disable_command
// swiftlint:disable all
// swiftformat:disable all
@testable import novels
import XCTest

final class MockBookRepo: BookRepository {
    let slug: String
    let count: Int
    var fileExists: ((String, Int) -> Bool)?
    init(slug: String, count: Int) {
        self.slug = slug
        self.count = count
    }

    func listBooks() throws -> [Book] {
        []
    }

    func book(slug: String) throws -> Book? {
        if let check = fileExists, !check(slug, -1) {
            return nil
        }
        guard slug == self.slug else { return nil }
        return Book(
            id: slug,
            name: "t",
            author: "a",
            count: count,
            references: (1 ... count).map { "Chap \($0)" }
        )
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        if let check = fileExists, !check(slug, number) {
            throw BookRepositoryError.missingChapterFile(slug: slug, number: number)
        }
        guard slug == self.slug else { throw BookRepositoryError.bookNotFound(slug: slug) }
        guard number >= 1 && number <= count else {
            throw BookRepositoryError.invalidChapterNumber(number: number, count: count)
        }
        return "<p>Content \(number)</p>"
    }

    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}

final class TrackingAIClient {
    var calls: [Int] = []
    var delayPerCall: UInt64 = 10_000_000
    var shouldFail: [Int: Error] = [:]
    // Chapters mapped here fail the next N mock transport attempts, then succeed.
    var failRemaining: [Int: Int] = [:]

    func service(cache: ProcessedChapterCaching, settings: SettingsStore) -> AIReadingService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        AIMockURLProtocol.handler = { request in
            var bodyData = request.httpBody
            if bodyData == nil, let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate(); stream.close() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read > 0 {
                        data.append(buffer, count: read)
                    } else {
                        break
                    }
                }
                bodyData = data
            }
            let data = bodyData ?? Data()
            var userContent = ""
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msgs = body["messages"] as? [[String: String]]
            {
                userContent = msgs.last?["content"] ?? ""
            } else if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let msgs = body["messages"] as? [[String: Any]]
            {
                userContent = (msgs.last?["content"] as? String) ?? ""
            }
            // userContent is chunk text like "Content N" or part of it
            // Extract number from raw content embedded
            let num: Int = {
                // find last int token
                let tokens = userContent.split(separator: " ")
                for token in tokens.reversed() {
                    if let val = Int(token) {
                        return val
                    }
                }
                // fallback: scan digits
                let digits = userContent.filter { $0.isNumber }
                // not ideal; try to parse trailing number
                // Also handle "Content N" case is second token
                let parts = userContent.split(separator: " ")
                if parts.count >= 2, let v = Int(parts[1]) {
                    return v
                }
                return 0
            }()
            self.calls.append(num)
            if let remaining = self.failRemaining[num], remaining > 0 {
                self.failRemaining[num] = remaining - 1
                throw NSError(
                    domain: "ai",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "flaky \(num)"]
                )
            }
            if let err = self.shouldFail[num] {
                throw err
            }
            if self.delayPerCall > 0 {
                Thread.sleep(forTimeInterval: Double(self.delayPerCall) / 1_000_000_000)
            }
            let json = "{\"choices\":[{\"message\":{\"content\":\"AI \(num)\"}}]}"
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                json.data(using: .utf8)!
            )
        }
        let session = URLSession(configuration: config)
        let client = AIClient(settings: settings, session: session)
        return AIReadingService(cache: cache, client: client, settings: settings)
    }
}

final class ThrowingBatchCache: ProcessedChapterCaching {
    let real: SQLiteProcessedChapterCache
    init(real: SQLiteProcessedChapterCache) {
        self.real = real
    }

    func get(bookId: String, chapterNumber: Int, mode: AIMode) throws -> ProcessedChapter? {
        try real.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode)
    }

    func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) throws -> Set<Int> {
        throw SQLiteError.exec(message: "boom")
    }

    func upsert(_ pc: ProcessedChapter) throws {
        try real.upsert(pc)
    }

    func clearAll() throws {
        try real.clearAll()
    }

    func clear(bookId: String) throws {
        try real.clear(bookId: bookId)
    }

    func countAll() throws -> Int {
        try real.countAll()
    }

    func count(bookId: String) throws -> Int {
        try real.count(bookId: bookId)
    }

    func allBookIds() throws -> [String] {
        try real.allBookIds()
    }
}

final class PrefetchManagerTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    @MainActor
    func makeManagerEnv(
        prefetchCount: Int = 3,
        totalChapters: Int = 10,
        mode: AIMode = .rewrite
    ) throws -> (PrefetchManager, SQLiteProcessedChapterCache, SettingsStore, MockBookRepo, TrackingAIClient) {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = UserDefaults(suiteName: "pref.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.prefetchCount = prefetchCount
        settings.save()
        let repo = MockBookRepo(slug: "book-slug", count: totalChapters)
        let client = TrackingAIClient()
        return (PrefetchManager(), cache, settings, repo, client)
    }

    func testEligibilityModeNoneDoesNothing() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv()
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 5,
            mode: .none,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 200_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(client.calls.count, 0)
        XCTAssertEqual(try cache.countAll(), 0)
    }

    func testBatchCheckSkipsCached() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "book-slug",
            chapterNumber: 2,
            mode: .rewrite,
            content: "cached2",
            contentHash: "h2",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "book-slug",
            chapterNumber: 3,
            mode: .rewrite,
            content: "cached3",
            contentHash: "h3",
            createdAt: now,
            updatedAt: now
        ))
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(client.calls.contains(4), "expected 4 in \(client.calls)")
        XCTAssertFalse(client.calls.contains(2), "unexpected 2 in \(client.calls)")
        XCTAssertFalse(client.calls.contains(3), "unexpected 3 in \(client.calls) cache should skip")
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
    }

    func testSequentialProcessingInOrder() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 5)
        client.delayPerCall = 50_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 5,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(client.calls, [2, 3, 4], "got \(client.calls)")
    }

    func testCancellationStopsRemaining() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 5, totalChapters: 10)
        client.delayPerCall = 300_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 400_000_000)
        await manager.cancel()
        try await Task.sleep(nanoseconds: 400_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning)
        XCTAssertTrue(client.calls.count < 5)
    }

    func testSingleChapterFailureDoesNotAbortBatch() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 5)
        client.shouldFail = [3: NSError(domain: "ai", code: 500, userInfo: [NSLocalizedDescriptionKey: "fail 3"])]
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 5,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let status = await manager.currentStatus()
        XCTAssertEqual(status.errors.count, 1, "errors \(status.errors) calls \(client.calls)")
        XCTAssertTrue(client.calls.contains(2), "should contain 2, got \(client.calls)")
        XCTAssertTrue(client.calls.contains(4), "should contain 4, got \(client.calls)")
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 2, mode: .rewrite), "2 should be cached")
        XCTAssertNil(
            try cache.get(bookId: "book-slug", chapterNumber: 3, mode: .rewrite),
            "3 should not be cached, calls \(client.calls)"
        )
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 4, mode: .rewrite), "4 should be cached")
    }

    func testInvalidPrefetchCountCoercedTo3() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 1001, totalChapters: 10)
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(client.calls.count, 3)
        XCTAssertEqual(client.calls, [2, 3, 4])
        let manager2 = PrefetchManager()
        let suite2 = try XCTUnwrap(UserDefaults(suiteName: "pref2.\(UUID().uuidString)"))
        let settings2 = await MainActor.run {
            let store = SettingsStore(userDefaults: suite2)
            store.prefetchCount = -1
            store.save()
            return store
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        let repo2 = MockBookRepo(slug: "s", count: 10)
        let client2 = TrackingAIClient()
        let svc2 = client2.service(cache: cache, settings: settings2)
        await manager2.start(
            bookId: "s",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings2,
            cache: cache,
            aiService: svc2,
            repository: repo2
        )
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(client2.calls.count, 3)
    }

    func testBookDeletedMidRunCancelsRemaining() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        client.delayPerCall = 200_000_000
        repo.fileExists = { _, number in
            if number == -1 {
                // book existence check sentinel; after first, simulate deletion
                return true
            }
            if number >= 3 {
                return false
            }
            return true
        }
        // Override to make book disappear after first call: use counter
        var callNumber = 0
        let original = repo.fileExists
        repo.fileExists = { slug, number in
            if number == -1 {
                callNumber += 1
                // after first iteration book still exists, then deleted
                return callNumber <= 1
            }
            if number >= 3 {
                return false
            }
            // also gate on callNumber
            if callNumber > 1 {
                return false
            }
            return original?(slug, number) ?? true
        }
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning)
        XCTAssertTrue(client.calls.count <= 2)
    }

    func testEffectivePrefetchCountClampsOutOfRange() async throws {
        let (_, _, settings, _, _) = try await makeManagerEnv()
        let cases: [(input: Int, expected: Int)] = [
            (-1, 3),
            (1001, 3),
            (Int.max, 3),
            (0, 0),
            (1, 1),
            (99, 99),
            (100, 100),
            (1000, 1000),
        ]
        for (input, expected) in cases {
            await MainActor.run { settings.prefetchCount = input }
            let actual = await MainActor.run { settings.effectivePrefetchCount() }
            XCTAssertEqual(actual, expected, "effectivePrefetchCount(\(input))")
            // Read-only: stored value stays untouched until save().
            let stored = await MainActor.run { settings.prefetchCount }
            XCTAssertEqual(stored, input, "stored prefetchCount must stay \(input)")
        }
    }

    func testMissingChapterErrorCarriesOwnRunId() async throws {
        await DiagnosticsLog.shared.clear()
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        // Chapter 3 vanished from disk; 2 and 4 prefetch normally.
        repo.fileExists = { _, number in number != 3 }
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(status.errors.count, 1)
        let entries = await DiagnosticsLog.shared.snapshot()
        let missing = entries.filter {
            $0.event == "prefetch.error-continue" && $0.chapterNumber == 3
        }
        // feat-024 Phase 1 (Lane P, see docs/plans/feat-024.md): the queue
        // requeues a failed chapter at the tail at most once, so the missing
        // chapter logs twice (initial + one retry) under distinct runIds
        // while errors[] still records it once. Spec amendment in Lane S.
        XCTAssertEqual(missing.count, 2, "initial + one tail-requeue retry")
        let missingRuns = Set(missing.compactMap { $0.runId })
        XCTAssertEqual(missingRuns.count, 2, "each attempt is its own run")
        let missingRun = try XCTUnwrap(missing.first?.runId, "missing-chapter error must carry a runId")
        // Chapters 2 and 4 each ran under their own distinct runs.
        let starts2 = entries.filter { $0.event == "chunk.start" && $0.chapterNumber == 2 }
        let starts4 = entries.filter { $0.event == "chunk.start" && $0.chapterNumber == 4 }
        XCTAssertFalse(starts2.isEmpty)
        XCTAssertFalse(starts4.isEmpty)
        let run2 = try XCTUnwrap(starts2.first?.runId)
        let run4 = try XCTUnwrap(starts4.first?.runId)
        XCTAssertNotEqual(run2, run4, "each prefetched chapter is its own run")
        XCTAssertNotEqual(missingRun, run2)
        XCTAssertNotEqual(missingRun, run4)
        for run in missingRuns where run != missingRun {
            XCTAssertNotEqual(run, run2)
            XCTAssertNotEqual(run, run4)
        }
    }

    // MARK: - feat-023 Phase 4: bounded retry + overlap-preserving window

    func testFailedChapterRetriedOnceInBatch() async throws {
        // Transient failure is recovered inside the same batch with at most one
        // retry (2 attempts total): no error recorded, chapter cached.
        // The single in-batch retry is the per-chunk attempt loop in AIClient;
        // the manager must never re-issue a failed chapter inside one batch
        // (that would amplify into 2x2 attempts and break the count==2 contract).
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 5)
        client.failRemaining = [3: 1]
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 5,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
        XCTAssertTrue(status.errors.isEmpty, "errors \(status.errors)")
        XCTAssertEqual(
            client.calls.filter { $0 == 3 }.count,
            2,
            "chapter 3 attempted at most twice (1 initial + <=1 retry), got \(client.calls)"
        )
        XCTAssertNotNil(
            try cache.get(bookId: "book-slug", chapterNumber: 3, mode: .rewrite),
            "3 cached after in-batch retry"
        )
    }

    func testFailedChapterPrioritizedInNextWindow() async throws {
        // feat-024 Phase 1 (Lane P, see docs/plans/feat-024.md): the durable
        // FIFO queue replaces the failed-first store with an in-queue
        // attempts<=1 tail requeue, so a clean restart issues plain miss
        // order ([3,4,6]) and no `retry-enqueue` detail is logged. The
        // chapter-prefetch.md §4 amendment lands in Lane S (Phase 4).
        // Backward navigation makes the failed chapter (6) larger than the
        // fresh misses (3,4), so failed-first [6,3,4] differs from ascending.
        await DiagnosticsLog.shared.clear()
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 2, totalChapters: 10)
        client.shouldFail = [6: NSError(domain: "ai", code: 500, userInfo: [NSLocalizedDescriptionKey: "fail 6"])]
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 4,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let firstStatus = await manager.currentStatus()
        XCTAssertFalse(firstStatus.isRunning, "status \(firstStatus)")
        XCTAssertEqual(firstStatus.errors.count, 1, "errors \(firstStatus.errors)")
        client.shouldFail = [:]
        await MainActor.run { settings.prefetchCount = 4 }
        let callsBeforeSecond = client.calls.count
        await manager.start(
            bookId: "book-slug",
            currentChapter: 2,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let newCalls = Array(client.calls.dropFirst(callsBeforeSecond))
        XCTAssertEqual(newCalls, [3, 4, 6], "restart issues plain miss order, got \(newCalls)")
        XCTAssertNotNil(
            try cache.get(bookId: "book-slug", chapterNumber: 6, mode: .rewrite),
            "6 cached after next-window retry"
        )
        let entries = await DiagnosticsLog.shared.snapshot()
        let checks = entries.filter { $0.event == "prefetch.batchCheck" }
        XCTAssertFalse(
            checks.contains { ($0.detail ?? "").contains("retry-enqueue") },
            "failed-first removed: batchCheck must not carry retry-enqueue, got \(checks.map { $0.detail })"
        )
    }

    func testOverlappingStartKeepsRunningBatch() async throws {
        // Same book+mode with non-empty overlap keeps the running batch:
        // kept chapters are processed exactly once, only the new tail is
        // appended (overlapKept/topUpAdded on the existing batchCheck event).
        await DiagnosticsLog.shared.clear()
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 4, totalChapters: 10)
        client.delayPerCall = 300_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 2,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 3_000_000_000)
        XCTAssertEqual(client.calls, [2, 3, 4, 5, 6], "kept chapters exactly once + new tail, got \(client.calls)")
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
        XCTAssertTrue(status.errors.isEmpty, "errors \(status.errors)")
        XCTAssertEqual(status.totalChapters, 5, "totals updated with top-up, got \(status)")
        let entries = await DiagnosticsLog.shared.snapshot()
        let checks = entries.filter { $0.event == "prefetch.batchCheck" }
        XCTAssertTrue(
            checks.contains { ($0.detail ?? "").contains("overlapKept=3") && ($0.detail ?? "").contains("topUpAdded=1") },
            "batchCheck must carry overlapKept=3/topUpAdded=1, got \(checks.map { $0.detail })"
        )
    }

    func testJumpFarRestarts() async throws {
        // Far jump with empty overlap is a clean restart (boundary of the
        // overlap-keep rule): the new window is fully processed.
        // (Characterization: restart-on-every-start is the pre-023 behavior.)
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        client.delayPerCall = 300_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 7,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(Array(client.calls.suffix(3)), [8, 9, 10], "new window fully processed, got \(client.calls)")
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 8, mode: .rewrite))
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 9, mode: .rewrite))
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 10, mode: .rewrite))
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
    }

    // MARK: - PR 26 review (parked M4): top-up must recompute total, not accumulate

    func testSteadyTopUpKeepsTotalEqualToWindow() async throws {
        // PR 26 review finding (parked M4): every top-up did
        // `totalChapters += topUpAdded` while `ensureWindow` silently drops
        // out-of-window entries, so steady goNext inflated the
        // `Đang tải trước processed/total` display unbounded (N=20 at ch450
        // grew 20→~30 over 10 nexts). Total must be recomputed so it holds
        // at the window size while the worker is still on its first chapter.
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 30)
        client.delayPerCall = 300_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 30,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        // Worker is still on chapter 2 (300ms/call): both top-ups reconcile
        // against processed=0, so total must stay 4 (3 queued + 1 in flight).
        try await Task.sleep(nanoseconds: 150_000_000)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 2,
            totalChapters: 30,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 3,
            totalChapters: 30,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        let status = await manager.currentStatus()
        XCTAssertEqual(status.totalChapters, 4, "steady top-up must recompute total, got \(status)")
        await manager.cancel(reason: "testDone")
    }

    func testFarJumpTopUpTotalEqualsActualWindow() async throws {
        // PR 26 review finding (parked M4): a far same-book jump filters
        // pending down to ~0 then appends the fresh window; accumulating
        // total reported 40 for a 20-window. Total must equal the actual
        // remaining work: 3 queued + 1 stale in-flight chapter.
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 30)
        client.delayPerCall = 300_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 30,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        // Worker is still on chapter 2 (300ms/call) when the far jump lands.
        try await Task.sleep(nanoseconds: 150_000_000)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 20,
            totalChapters: 30,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        let status = await manager.currentStatus()
        XCTAssertEqual(status.totalChapters, 4, "far-jump total must equal actual window work, got \(status)")
        await manager.cancel(reason: "testDone")
    }

    // MARK: - feat-023 Phase 5: resource worst-case guards

    func testNoRuntimeCapWindowIsHonored() async throws {
        // Per feat-024 plan Phase 3 + settings-schema BR-08 note: no runtime
        // hardCap; N=1000 issues the full window, paced by the sequential
        // worker and budgets. The public 0...1000-else-3 policy, budgets, and
        // timeouts are unchanged; batchCheck logs the single consumed N.
        await DiagnosticsLog.shared.clear()
        // N=20 issues the full 20-chapter window once.
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 20, totalChapters: 50)
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 50,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 5_000_000_000)
        XCTAssertEqual(client.calls, Array(2 ... 21), "N=20 honored, got \(client.calls)")
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
        var entries = await DiagnosticsLog.shared.snapshot()
        var checks = entries.filter { $0.event == "prefetch.batchCheck" }
        XCTAssertTrue(
            checks.contains {
                let detail = $0.detail ?? ""
                return detail.contains("storedN=20") && detail.contains("effectiveN=20") && !detail.contains("appliedCap")
            },
            "batchCheck must carry single N without appliedCap, got \(checks.map { $0.detail })"
        )
        // N=1000 (top of the legal range) is honored, paced sequentially.
        await DiagnosticsLog.shared.clear()
        let (manager2, cache2, settings2, repo2, client2) = try await makeManagerEnv(prefetchCount: 1000, totalChapters: 50)
        let svc2 = client2.service(cache: cache2, settings: settings2)
        await manager2.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 50,
            mode: .rewrite,
            settings: settings2,
            cache: cache2,
            aiService: svc2,
            repository: repo2
        )
        try await Task.sleep(nanoseconds: 6_000_000_000)
        XCTAssertEqual(client2.calls, Array(2 ... 50), "N=1000 honored paced, got \(client2.calls)")
        let status2 = await manager2.currentStatus()
        XCTAssertFalse(status2.isRunning, "status \(status2)")
        entries = await DiagnosticsLog.shared.snapshot()
        checks = entries.filter { $0.event == "prefetch.batchCheck" }
        XCTAssertTrue(
            checks.contains {
                let detail = $0.detail ?? ""
                return detail.contains("storedN=1000") && detail.contains("effectiveN=1000") && !detail.contains("appliedCap")
            },
            "batchCheck must carry single N without appliedCap, got \(checks.map { $0.detail })"
        )
    }

    func testCacheQueryFailureKeepsPriorState() async throws {
        // A batchStatus throw keeps the prior status (never miss-all) and logs
        // on an existing event instead of refetching everything as misses.
        await DiagnosticsLog.shared.clear()
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let settled = await manager.currentStatus()
        XCTAssertFalse(settled.isRunning, "status \(settled)")
        let callsBefore = client.calls.count
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: settings,
            cache: ThrowingBatchCache(real: cache),
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(client.calls.count, callsBefore, "no refetch on query failure, got \(client.calls)")
        let kept = await manager.currentStatus()
        XCTAssertEqual(kept, settled, "prior state kept")
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertTrue(
            entries.contains { $0.event == "prefetch.error-continue" && ($0.detail ?? "").contains("cacheQueryFailed") },
            "query failure must be logged, got \(entries.map { ($0.event, $0.detail) })"
        )
    }

    func testQueryFailureDuringRunningBatchKeepsTailMark() async throws {
        // P-Important-1 pin: a cache query failure must not mutate shared
        // window state — the running end-of-book batch keeps its tailMark.
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 10, totalChapters: 100)
        client.delayPerCall = 300_000_000
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 98,
            totalChapters: 100,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 100,
            mode: .rewrite,
            settings: settings,
            cache: ThrowingBatchCache(real: cache),
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 2_500_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
        XCTAssertTrue(
            status.message.contains("còn 2 chương cuối"),
            "running batch keeps its tailMark, got \(status.message)"
        )
    }

    func testEndOfBookMessageNamesRemainingChapters() async throws {
        // current=98, total=100, N=10: the window holds the last 2 chapters and
        // the terminal message names them instead of a generic done.
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 10, totalChapters: 100)
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 98,
            totalChapters: 100,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
        XCTAssertEqual(client.calls, [99, 100], "got \(client.calls)")
        XCTAssertTrue(
            (status.message).contains("còn 2 chương cuối"),
            "end-of-book message must name the remaining chapters, got \(status.message)"
        )
        // Mid-book contrast: generic done without the tail marker.
        await MainActor.run { settings.prefetchCount = 3 }
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 100,
            mode: .rewrite,
            settings: settings,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let mid = await manager.currentStatus()
        XCTAssertFalse(mid.isRunning, "status \(mid)")
        XCTAssertEqual(mid.message, "Đã hoàn tất", "mid-book message stays generic, got \(mid.message)")
    }
}
