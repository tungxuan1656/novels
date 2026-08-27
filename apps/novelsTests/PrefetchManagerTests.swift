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

final class PrefetchManagerTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    @MainActor
    func makeManagerEnv(
        prefetchCount: Int = 3,
        totalChapters: Int = 10,
        mode: AIMode = .translate
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
            mode: .translate,
            content: "cached2",
            contentHash: "h2",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "book-slug",
            chapterNumber: 3,
            mode: .translate,
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
            mode: .translate,
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
            mode: .translate,
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
            mode: .translate,
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
            mode: .translate,
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
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 2, mode: .translate), "2 should be cached")
        XCTAssertNil(
            try cache.get(bookId: "book-slug", chapterNumber: 3, mode: .translate),
            "3 should not be cached, calls \(client.calls)"
        )
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 4, mode: .translate), "4 should be cached")
    }

    func testInvalidPrefetchCountCoercedTo3() async throws {
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 99, totalChapters: 10)
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .translate,
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
            store.prefetchCount = 0
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
            mode: .translate,
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
            mode: .translate,
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
}
