@testable import novels
import XCTest

final class AIReadingServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    @MainActor
    private func makeSettings(
        chunkSize: Int? = nil,
        headersJSON: String = "",
        extraBodyJSON: String = ""
    ) -> SettingsStore {
        let suite = UserDefaults(suiteName: "test.svc.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        if let chunkSize {
            settings.aiMinChunkSize = chunkSize
        }
        settings.aiCustomHeadersJSON = headersJSON
        settings.aiExtraBodyJSON = extraBodyJSON
        settings.openaiAPIURL = "http://localhost:8317/v1/chat/completions"
        settings.openaiModel = "gpt-4o"
        settings.save()
        return settings
    }

    private func makeClient(settings: SettingsStore) -> AIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        let session = URLSession(configuration: config)
        return AIClient(settings: settings, session: session)
    }

    func testCacheHitReturnsWithoutNetwork() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        let cached = ProcessedChapter(
            bookId: "slug",
            chapterNumber: 1,
            mode: .rewrite,
            content: "cached",
            contentHash: SHA256.hex("cached"),
            createdAt: now,
            updatedAt: now
        )
        try cache.upsert(cached)
        let settings = await makeSettings()
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        var networkCalled = false
        AIMockURLProtocol.handler = { _ in
            networkCalled = true
            XCTFail("should not call network on cache hit")
            throw URLError(.badServerResponse)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 1,
            mode: .rewrite,
            rawText: "raw"
        )
        XCTAssertEqual(output, "cached")
        XCTAssertFalse(networkCalled)
    }

    func testMissChunksMergesAndCaches() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 1300)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        let raw = String(repeating: "a", count: 2600)
        var callCount = 0
        AIMockURLProtocol.handler = { _ in
            callCount += 1
            let content = callCount == 1 ? "part-one" : "part-two"
            let json = "{\"choices\":[{\"message\":{\"content\":\"\(content)\"}}]}"
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:8317/v1/chat/completions")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 2,
            mode: .rewrite,
            rawText: raw
        )
        XCTAssertEqual(output, "part-one\npart-two")
        XCTAssertEqual(callCount, 2)
        let stored = try cache.get(bookId: "slug", chapterNumber: 2, mode: .rewrite)
        XCTAssertEqual(stored?.content, "part-one\npart-two")
        XCTAssertEqual(stored?.contentHash, SHA256.hex("part-one\npart-two"))
    }

    func testDedupPreventsParallelDuplicate() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 1300)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        var callCount = 0
        AIMockURLProtocol.handler = { _ in
            callCount += 1
            // Keep first request in-flight briefly so second caller dedups
            Thread.sleep(forTimeInterval: 0.15)
            let json = "{\"choices\":[{\"message\":{\"content\":\"deduped\"}}]}"
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:8317/v1/chat/completions")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        async let first = service.processedContent(
            bookId: "slug",
            chapterNumber: 3,
            mode: .rewrite,
            rawText: "hello world"
        )
        async let second = service.processedContent(
            bookId: "slug",
            chapterNumber: 3,
            mode: .rewrite,
            rawText: "hello world"
        )
        let results = try await[first, second]
        XCTAssertEqual(results[0], "deduped")
        XCTAssertEqual(results[1], "deduped")
        XCTAssertEqual(callCount, 1)
    }

    func testModeNoneNeverCached() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings()
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        AIMockURLProtocol.handler = { _ in
            XCTFail("mode none should not hit network")
            throw URLError(.badServerResponse)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 5,
            mode: .none,
            rawText: "raw text"
        )
        XCTAssertEqual(output, "raw text")
        XCTAssertEqual(try cache.countAll(), 0)
    }

    func testReprocessOverwritesCache() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "slug",
            chapterNumber: 4,
            mode: .rewrite,
            content: "old",
            contentHash: SHA256.hex("old"),
            createdAt: now,
            updatedAt: now
        ))
        let settings = await makeSettings()
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        AIMockURLProtocol.handler = { _ in
            let json = "{\"choices\":[{\"message\":{\"content\":\"new\"}}]}"
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:8317/v1/chat/completions")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await service.reprocess(
            bookId: "slug",
            chapterNumber: 4,
            mode: .rewrite,
            rawText: "raw for reprocess"
        )
        XCTAssertEqual(output, "new")
        let stored = try cache.get(bookId: "slug", chapterNumber: 4, mode: .rewrite)
        XCTAssertEqual(stored?.content, "new")
        XCTAssertEqual(stored?.contentHash, SHA256.hex("new"))
    }

    func testInvalidHeadersIgnored() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(headersJSON: "{bad", extraBodyJSON: "not json")
        // Verify effectiveHeaders is empty despite invalid JSON
        let headers = await MainActor.run { settings.effectiveHeaders() }
        XCTAssertTrue(headers.isEmpty)
        let body = await MainActor.run { settings.effectiveExtraBody() }
        XCTAssertTrue(body.isEmpty)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        AIMockURLProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await service.processedContent(
            bookId: "b",
            chapterNumber: 1,
            mode: .rewrite,
            rawText: "hello world this is a test"
        )
        XCTAssertEqual(output, "ok")
    }
}
