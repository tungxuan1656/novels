@testable import novels
import XCTest

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
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
        let lock = NSLock()
        AIMockURLProtocol.handler = { _ in
            lock.lock()
            callCount += 1
            let content = callCount == 1 ? "part-one" : "part-two"
            lock.unlock()
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
        XCTAssertEqual(output.split(separator: "\n").map(String.init).sorted(), ["part-one", "part-two"])
        XCTAssertEqual(callCount, 2)
        let stored = try cache.get(bookId: "slug", chapterNumber: 2, mode: .rewrite)
        XCTAssertEqual(stored?.content, output)
        XCTAssertEqual(stored?.contentHash, SHA256.hex(output))
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

    func testReprocessDedupsParallelDuplicate() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 1300)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        var callCount = 0
        let lock = NSLock()
        AIMockURLProtocol.handler = { _ in
            lock.lock()
            callCount += 1
            lock.unlock()
            // Keep first request in-flight briefly so the second caller takes over
            Thread.sleep(forTimeInterval: 0.15)
            let json = "{\"choices\":[{\"message\":{\"content\":\"reprocessed\"}}]}"
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:8317/v1/chat/completions")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        // R1 last-writer-wins: the second reprocess cancels the first in-flight
        // pipeline, so only one network call is made; exactly one caller wins.
        let task1 = Task {
            try await service.reprocess(
                bookId: "slug",
                chapterNumber: 6,
                mode: .rewrite,
                rawText: "hello world"
            )
        }
        let task2 = Task {
            try await service.reprocess(
                bookId: "slug",
                chapterNumber: 6,
                mode: .rewrite,
                rawText: "hello world"
            )
        }
        var succeeded: [String] = []
        var cancelled = 0
        for task in [task1, task2] {
            do {
                try succeeded.append(await task.value)
            } catch {
                XCTAssertTrue(error is CancellationError, "loser must be cancelled, got \(error)")
                cancelled += 1
            }
        }
        XCTAssertEqual(succeeded, ["reprocessed"])
        XCTAssertEqual(cancelled, 1)
        lock.lock()
        let calls = callCount
        lock.unlock()
        XCTAssertEqual(calls, 1)
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

    private func chunkMarker(from request: URLRequest) -> String {
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
        guard let data = bodyData,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = obj["messages"] as? [[String: Any]],
              let chunkText = messages.last?["content"] as? String,
              let first = chunkText.first
        else {
            return ""
        }
        return String(first)
    }

    func testParallelOrderingPreservedWithReverseDelays() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 500)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        var segments: [String] = []
        for index in 0 ..< 5 {
            segments.append(String(repeating: "\(index)", count: 500))
        }
        let raw = segments.joined()
        AIMockURLProtocol.handler = { request in
            let marker = self.chunkMarker(from: request)
            let index = Int(marker) ?? 0
            // Reverse delays: later chunks finish first
            Thread.sleep(forTimeInterval: Double(4 - index) * 0.05)
            let json = "{\"choices\":[{\"message\":{\"content\":\"out-\(index)\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 10,
            mode: .rewrite,
            rawText: raw
        )
        XCTAssertEqual(output, "out-0\n\nout-1\n\nout-2\n\nout-3\n\nout-4")
    }

    func testPerChunkTwoAttemptsThenFailsFastNoPartialCache() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 500)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        let raw = String(repeating: "A", count: 500) + String(repeating: "B", count: 500)
        var attemptsByMarker: [String: Int] = [:]
        let lock = NSLock()
        AIMockURLProtocol.handler = { request in
            let marker = self.chunkMarker(from: request)
            lock.lock()
            attemptsByMarker[marker, default: 0] += 1
            lock.unlock()
            if marker == "A" {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("{\"error\":\"server\"}".utf8))
            }
            let json = "{\"choices\":[{\"message\":{\"content\":\"got-\(marker)\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        do {
            _ = try await service.processedContent(
                bookId: "slug",
                chapterNumber: 11,
                mode: .rewrite,
                rawText: raw
            )
            XCTFail("should throw after per-chunk bounded retry")
        } catch {
            // Bounded retry: failed chunk A requested exactly twice, then chapter aborts.
            lock.lock()
            let attemptsA = attemptsByMarker["A"] ?? 0
            lock.unlock()
            XCTAssertEqual(attemptsA, 2)
            // No partial cache write on chapter failure.
            XCTAssertNil(try cache.get(bookId: "slug", chapterNumber: 11, mode: .rewrite))
        }
    }

    func testOneChunkRetryDoesNotDuplicateOtherChunks() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 500)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        let raw = String(repeating: "A", count: 500)
            + String(repeating: "B", count: 500)
            + String(repeating: "C", count: 500)
        var attemptsByMarker: [String: Int] = [:]
        let lock = NSLock()
        AIMockURLProtocol.handler = { request in
            let marker = self.chunkMarker(from: request)
            lock.lock()
            attemptsByMarker[marker, default: 0] += 1
            let attempt = attemptsByMarker[marker] ?? 0
            lock.unlock()
            if marker == "B", attempt == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("{\"error\":\"server\"}".utf8))
            }
            let json = "{\"choices\":[{\"message\":{\"content\":\"got-\(marker)\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 13,
            mode: .rewrite,
            rawText: raw
        )
        XCTAssertEqual(output, "got-A\n\ngot-B\n\ngot-C")
        lock.lock()
        let attempts = attemptsByMarker
        lock.unlock()
        XCTAssertEqual(attempts["A"], 1, "attempts \(attempts)")
        XCTAssertEqual(attempts["B"], 2, "attempts \(attempts)")
        XCTAssertEqual(attempts["C"], 1, "attempts \(attempts)")
    }

    func testCancelThrowsCancellationError() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 500)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"slow\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        // Single attempt: no retry backoff; outer cancellation surfaces as CancellationError
        // via the cooperative sleep before the network call (deterministic, no timing flake).
        let raw = String(repeating: "x", count: 1200)
        let task = Task<String, Error> {
            try await Task.sleep(nanoseconds: 500_000_000)
            return try await service.reprocess(
                bookId: "slug",
                chapterNumber: 12,
                mode: .rewrite,
                rawText: raw
            )
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("should throw CancellationError")
        } catch {
            XCTAssertTrue(error is CancellationError, "expected CancellationError, got \(error)")
        }
    }

    func testReasoningFallbackSucceedsViaService() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings()
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":null,\"reasoning_content\":\"noi dung suy luan\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 20,
            mode: .rewrite,
            rawText: "hello world this is a test"
        )
        XCTAssertEqual(output, "noi dung suy luan")
    }

    func testTwoRunsOfSameChapterHaveDistinctRunIds() async throws {
        await DiagnosticsLog.shared.clear()
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings()
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"out\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let runA = UUID()
        _ = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 20,
            mode: .rewrite,
            rawText: "hello world first run",
            runId: runA
        )
        // Same chapter reprocessed (manual retry) gets its own row.
        let runB = UUID()
        _ = try await service.reprocess(
            bookId: "slug",
            chapterNumber: 20,
            mode: .rewrite,
            rawText: "hello world second run",
            runId: runB
        )
        XCTAssertNotEqual(runA, runB)
        let entries = await DiagnosticsLog.shared.snapshot()
            .filter { $0.chapterNumber == 20 }
        XCTAssertFalse(entries.isEmpty)
        let runsA = entries.filter { $0.runId == runA }
        let runsB = entries.filter { $0.runId == runB }
        XCTAssertFalse(runsA.isEmpty, "first run must log under runA")
        XCTAssertFalse(runsB.isEmpty, "reprocess must log under runB")
        XCTAssertTrue(runsA.allSatisfy { $0.runId == runA })
        XCTAssertTrue(runsB.allSatisfy { $0.runId == runB })
        // Every entry of this chapter belongs to exactly one of the two runs.
        XCTAssertEqual(runsA.count + runsB.count, entries.count, "entries \(entries.map { $0.event ?? "api" })")
    }

    func testAutoRunIdAssignedAndSharedAcrossRetry() async throws {
        await DiagnosticsLog.shared.clear()
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings(chunkSize: 500)
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        let raw = String(repeating: "A", count: 500) + String(repeating: "B", count: 500)
        var calls = 0
        let lock = NSLock()
        AIMockURLProtocol.handler = { request in
            lock.lock()
            calls += 1
            let attempt = calls
            lock.unlock()
            if attempt == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("{\"error\":\"server\"}".utf8))
            }
            let json = "{\"choices\":[{\"message\":{\"content\":\"recovered\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        // No explicit runId: service assigns one and shares it across the retry.
        _ = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 21,
            mode: .rewrite,
            rawText: raw
        )
        let entries = await DiagnosticsLog.shared.snapshot()
            .filter { $0.chapterNumber == 21 }
        XCTAssertFalse(entries.isEmpty)
        let runIds = Set(entries.compactMap { $0.runId })
        XCTAssertEqual(runIds.count, 1, "all entries of one call share one run, got \(runIds)")
        // Both retry attempts of the failed chunk carry the same run.
        let api = entries.filter { $0.kind == .api }
        XCTAssertTrue(api.count >= 2, "attempt 1 fail + attempt 2 entries, got \(api.count)")
        XCTAssertTrue(api.allSatisfy { $0.runId == runIds.first })
    }
}
