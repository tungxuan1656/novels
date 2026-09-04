@testable import novels
import XCTest

// swiftlint:disable trailing_comma

// swiftlint:disable:next type_body_length
final class DiagnosticsLogTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await DiagnosticsLog.shared.clear()
        AIMockURLProtocol.handler = nil
    }

    override func tearDown() async throws {
        await DiagnosticsLog.shared.clear()
        AIMockURLProtocol.handler = nil
        try await super.tearDown()
    }

    @MainActor
    private func makeSettings(verbose: Bool = false, headersJSON: String = "") -> SettingsStore {
        let suite = UserDefaults(suiteName: "test.diag.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.openaiAPIURL = "http://localhost:8317/v1/chat/completions"
        settings.openaiModel = "gpt-4o"
        settings.aiCustomHeadersJSON = headersJSON
        settings.diagnosticsVerbose = verbose
        settings.save()
        return settings
    }

    private func makeClient(settings: SettingsStore) -> AIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        return AIClient(settings: settings, session: URLSession(configuration: config))
    }

    private func okHandler(content: String = "ok") -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"\(content)\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
    }

    // MARK: - Redaction

    func testSensitiveHeadersRedacted() {
        let redacted = DiagnosticsRedactor.redactedHeaders([
            "Authorization": "Bearer secret-123",
            "X-Api-Key": "key-abc",
            "Cookie": "session=xyz",
            "Content-Type": "application/json",
        ])
        XCTAssertEqual(redacted["Authorization"], "<redacted>")
        XCTAssertEqual(redacted["X-Api-Key"], "<redacted>")
        XCTAssertEqual(redacted["Cookie"], "<redacted>")
        XCTAssertEqual(redacted["Content-Type"], "application/json")
        XCTAssertTrue(DiagnosticsRedactor.isSensitiveHeader("AUTHORIZATION"))
        XCTAssertTrue(DiagnosticsRedactor.isSensitiveHeader("x-api-key"))
        XCTAssertFalse(DiagnosticsRedactor.isSensitiveHeader("Content-Type"))
    }

    func testAuthAndPromptNeverRawInEntries() async throws {
        let secret = "Bearer super-secret-xyz-999"
        let prompt = "SYSTEM-SECRET-PROMPT-12345"
        let settings = await makeSettings(verbose: true, headersJSON: "{\"Authorization\":\"\(secret)\"}")
        let client = makeClient(settings: settings)
        AIMockURLProtocol.handler = okHandler()
        _ = try await client.complete(prompt: prompt, chunk: "hello-chunk")
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertFalse(entries.isEmpty)
        let requestEntries = entries.filter { $0.kind == .api && $0.statusCode == nil }
        XCTAssertEqual(requestEntries.count, 1)
        XCTAssertEqual(requestEntries.first?.headersRedacted?["Authorization"], "<redacted>")
        XCTAssertEqual(requestEntries.first?.host, "http://localhost:8317/v1/chat/completions")
        XCTAssertEqual(requestEntries.first?.snippet, "hello-chunk")
        for entry in entries {
            let values = (entry.headersRedacted ?? [:]).values.joined(separator: " ")
            let combined = "\(entry.debugSummary) \(entry.detail ?? "") \(entry.snippet ?? "") \(values)"
            XCTAssertFalse(combined.contains(secret), "raw secret leaked in \(entry)")
            XCTAssertFalse(combined.contains(prompt), "raw prompt leaked in \(entry)")
        }
    }

    func testSnippetOnlyWhenVerbose() async throws {
        let quiet = await makeSettings(verbose: false)
        let quietClient = makeClient(settings: quiet)
        AIMockURLProtocol.handler = okHandler(content: "reply-text")
        _ = try await quietClient.complete(prompt: "sys", chunk: "chunk-body")
        let quietEntries = await DiagnosticsLog.shared.snapshot()
        XCTAssertFalse(quietEntries.isEmpty)
        XCTAssertTrue(quietEntries.allSatisfy { $0.snippet == nil })
        XCTAssertEqual(quietEntries.first?.bodyLen, "chunk-body".utf8.count)
        XCTAssertNotNil(quietEntries.first?.bodyHashPrefix)
    }

    // MARK: - Ring buffer

    func testEvictionKeepsLast500() async {
        for index in 0 ..< 501 {
            await DiagnosticsLog.shared.append(LogEntry(
                sessionId: DiagnosticsLog.sessionId,
                bookId: "evict",
                chapterNumber: index,
                event: "evict.probe",
                detail: "i=\(index)"
            ))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertEqual(entries.count, 500)
        XCTAssertEqual(entries.first?.detail, "i=1")
        XCTAssertEqual(entries.last?.detail, "i=500")
    }

    // MARK: - Timeout config

    func testTimeoutConfigurationValues() {
        let config = AIClient.defaultConfiguration()
        XCTAssertEqual(config.timeoutIntervalForRequest, 180)
        XCTAssertEqual(config.timeoutIntervalForResource, 600)
        XCTAssertTrue(config.waitsForConnectivity)
        XCTAssertEqual(AIClient.requestTimeout, 180)
        XCTAssertEqual(AIClient.resourceTimeout, 600)
    }

    // MARK: - Settings

    func testDiagnosticsVerboseDefaultsFalseAndPersists() async throws {
        let suiteName = "test.diag.verbose.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let first = await MainActor.run { SettingsStore(userDefaults: defaults) }
        let initial = await MainActor.run { first.diagnosticsVerbose }
        XCTAssertFalse(initial)
        await MainActor.run {
            first.diagnosticsVerbose = true
            first.save()
        }
        let second = await MainActor.run { SettingsStore(userDefaults: defaults) }
        let reloaded = await MainActor.run { second.diagnosticsVerbose }
        XCTAssertTrue(reloaded)
    }

    // MARK: - Chunk instrumentation

    func testChunkStartSuccessShareRequestIdWithAPIEntries() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = await makeSettings()
        let client = makeClient(settings: settings)
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        var callCount = 0
        let lock = NSLock()
        AIMockURLProtocol.handler = { request in
            lock.lock()
            callCount += 1
            let content = "part-\(callCount)"
            lock.unlock()
            return try self.okHandler(content: content)(request)
        }
        let output = try await service.processedContent(
            bookId: "slug",
            chapterNumber: 2,
            mode: .rewrite,
            rawText: String(repeating: "a", count: 2600)
        )
        // Parallel TaskGroup: chunk completion order is nondeterministic, compare as set.
        XCTAssertEqual(output.split(separator: "\n").map(String.init).sorted(), ["part-1", "part-2"])
        let entries = await DiagnosticsLog.shared.snapshot()
        let starts = entries.filter { $0.event == "chunk.start" }
        let successes = entries.filter { $0.event == "chunk.success" }
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(successes.count, 2)
        XCTAssertTrue(starts.allSatisfy { $0.chunkTotal == 2 })
        XCTAssertTrue(starts.allSatisfy { ($0.detail ?? "").contains("chunkCount=2") })
        for start in starts {
            let correlated = entries.contains {
                $0.kind == .api && $0.requestId == start.requestId && $0.statusCode == nil
            }
            XCTAssertTrue(correlated, "chunk.start requestId has no matching api request entry")
        }
        let saves = entries.filter { $0.event == "cache.save" }
        XCTAssertEqual(saves.count, 1)
        XCTAssertTrue((saves.first?.detail ?? "").contains("outputHash="))
        XCTAssertFalse((saves.first?.detail ?? "").contains("slug#2#rewrite"))
    }

    // MARK: - Prefetch markers

    private struct PrefetchEnv {
        let manager: PrefetchManager
        let cache: SQLiteProcessedChapterCache
        let settings: SettingsStore
        let repo: MockBookRepo
        let tracking: TrackingAIClient
    }

    @MainActor
    private func makePrefetchEnv(
        prefetchCount: Int = 3,
        totalChapters: Int = 10
    ) throws -> PrefetchEnv {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = UserDefaults(suiteName: "test.diag.pref.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.prefetchCount = prefetchCount
        settings.save()
        let repo = MockBookRepo(slug: "book-slug", count: totalChapters)
        return PrefetchEnv(
            manager: PrefetchManager(),
            cache: cache,
            settings: settings,
            repo: repo,
            tracking: TrackingAIClient()
        )
    }

    func testPrefetchBatchCheckAndSkipMarkers() async throws {
        let env = try await makePrefetchEnv()
        let service = env.tracking.service(cache: env.cache, settings: env.settings)
        await env.manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: env.settings,
            cache: env.cache,
            aiService: service,
            repository: env.repo
        )
        try await Task.sleep(nanoseconds: 900_000_000)
        var entries = await DiagnosticsLog.shared.snapshot()
        let checks = entries.filter { $0.event == "prefetch.batchCheck" }
        XCTAssertEqual(checks.count, 1)
        XCTAssertTrue((checks.first?.detail ?? "").contains("rangeFrom=2"))
        XCTAssertTrue((checks.first?.detail ?? "").contains("rangeTo=4"))
        XCTAssertTrue((checks.first?.detail ?? "").contains("miss=3"))

        await DiagnosticsLog.shared.clear()
        await env.manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 10,
            mode: .rewrite,
            settings: env.settings,
            cache: env.cache,
            aiService: service,
            repository: env.repo
        )
        try await Task.sleep(nanoseconds: 300_000_000)
        entries = await DiagnosticsLog.shared.snapshot()
        let skips = entries.filter { $0.event == "prefetch.skip" }
        XCTAssertTrue(skips.contains { ($0.detail ?? "").contains("reason=allCached") })
    }

    func testPrefetchErrorContinueMarker() async throws {
        let env = try await makePrefetchEnv()
        env.tracking.shouldFail = [
            3: NSError(domain: "ai", code: 500, userInfo: [NSLocalizedDescriptionKey: "fail 3"]),
        ]
        let service = env.tracking.service(cache: env.cache, settings: env.settings)
        await env.manager.start(
            bookId: "book-slug",
            currentChapter: 1,
            totalChapters: 5,
            mode: .rewrite,
            settings: env.settings,
            cache: env.cache,
            aiService: service,
            repository: env.repo
        )
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let entries = await DiagnosticsLog.shared.snapshot()
        let continues = entries.filter { $0.event == "prefetch.error-continue" }
        XCTAssertTrue(continues.contains { $0.chapterNumber == 3 })
        XCTAssertEqual(PrefetchManager.perChapterBudget, 600)
        XCTAssertEqual(PrefetchManager.globalBudget, 1800)
    }

    func testPrefetchCancelMarker() async throws {
        let env = try await makePrefetchEnv()
        await env.manager.cancel(reason: "chapterChange")
        let entries = await DiagnosticsLog.shared.snapshot()
        let cancels = entries.filter { $0.event == "prefetch.cancel" }
        XCTAssertTrue(cancels.contains { ($0.detail ?? "").contains("reason=chapterChange") })
    }

    // MARK: - Response shape (feat-017)

    func testShapeParserKinds() {
        let nullData = Data("{\"choices\":[{\"message\":{\"content\":null,\"reasoning_content\":\"r\"}}]}".utf8)
        let nullShape = AIResponseShape.parse(nullData)
        XCTAssertEqual(nullShape.responseJsonKeys, ["choices"])
        XCTAssertEqual(nullShape.choicesCount, 1)
        XCTAssertEqual(nullShape.contentKind, "null")
        XCTAssertEqual(nullShape.hasReasoningContent, true)
        XCTAssertEqual(nullShape.hasToolCalls, false)

        let emptyData = Data("{\"choices\":[]}".utf8)
        let emptyShape = AIResponseShape.parse(emptyData)
        XCTAssertEqual(emptyShape.choicesCount, 0)
        XCTAssertEqual(emptyShape.contentKind, "missing")

        let envelopeData = Data("{\"data\":{\"choices\":[]}}".utf8)
        let envelopeShape = AIResponseShape.parse(envelopeData)
        XCTAssertEqual(envelopeShape.responseJsonKeys, ["data"])
        XCTAssertNil(envelopeShape.choicesCount)
        XCTAssertEqual(envelopeShape.contentKind, "missing")

        let toolsData = Data("{\"choices\":[{\"message\":{\"content\":null,\"tool_calls\":[{\"id\":\"x\"}]}}]}".utf8)
        let toolsShape = AIResponseShape.parse(toolsData)
        XCTAssertEqual(toolsShape.hasToolCalls, true)
        XCTAssertEqual(toolsShape.contentKind, "null")
    }

    func testShapeFailureKeepsRedaction() async throws {
        let secret = "Bearer shape-secret-456"
        let settings = await makeSettings(verbose: true, headersJSON: "{\"Authorization\":\"\(secret)\"}")
        let client = makeClient(settings: settings)
        let raw = "{\"choices\":[{\"message\":{\"content\":null,\"tool_calls\":[{\"id\":\"t1\"}]}}]}"
        AIMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, raw.data(using: .utf8)!)
        }
        do {
            _ = try await client.complete(prompt: "sys", chunk: "chunk-body")
            XCTFail("should throw")
        } catch {
            XCTAssertTrue("\(error)".lowercased().contains("noresponse"))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertFalse(entries.isEmpty)
        let failure = try XCTUnwrap(entries.first { $0.errorDomain == "AIClientError.noResponse" })
        XCTAssertEqual(failure.hasToolCalls, true)
        XCTAssertEqual(failure.contentKind, "null")
        for entry in entries {
            let values = (entry.headersRedacted ?? [:]).values.joined(separator: " ")
            let combined = "\(entry.debugSummary) \(entry.detail ?? "") \(entry.snippet ?? "") \(values)"
            XCTAssertFalse(combined.contains(secret))
            XCTAssertFalse(combined.contains(raw))
        }
    }
}

// swiftlint:enable trailing_comma
