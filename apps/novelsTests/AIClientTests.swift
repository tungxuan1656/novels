@testable import novels
import XCTest

// swiftlint:disable file_length

final class AIMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// swiftlint:disable:next type_body_length
final class AIClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    @MainActor
    private func makeClient(
        headersJSON: String = "",
        extraBodyJSON: String = "",
        url: String = "http://localhost:8317/v1/chat/completions"
    ) -> (AIClient, SettingsStore) {
        let suite = UserDefaults(suiteName: "test.ai.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.openaiAPIURL = url
        settings.aiCustomHeadersJSON = headersJSON
        settings.aiExtraBodyJSON = extraBodyJSON
        settings.openaiModel = "gpt-4o"
        settings.save()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = AIClient(settings: settings, session: session)
        return (client, settings)
    }

    func testMergesValidHeadersAndBody() async throws {
        let (client, _) = await MainActor.run {
            makeClient(headersJSON: "{\"Authorization\":\"Bearer tok\"}", extraBodyJSON: "{\"temperature\":0.7}")
        }
        var captured: URLRequest?
        var capturedBodyData: Data?
        AIMockURLProtocol.handler = { request in
            captured = request
            capturedBodyData = request.httpBody ?? {
                if let stream = request.httpBodyStream {
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
                    return data
                }
                return nil
            }()
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "sys", chunk: "hi")
        XCTAssertEqual(output, "ok")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        let body = try XCTUnwrap(capturedBodyData ?? captured?.httpBody)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(dict["model"] as? String, "gpt-4o")
        // temperature may be NSNumber
        if let temp = dict["temperature"] as? Double {
            XCTAssertEqual(temp, 0.7, accuracy: 0.0001)
        } else if let num = dict["temperature"] as? NSNumber {
            XCTAssertEqual(num.doubleValue, 0.7, accuracy: 0.0001)
        } else {
            XCTFail("temperature missing or wrong type: \(String(describing: dict["temperature"]))")
        }
    }

    func testIgnoresInvalidHeadersJSON() async throws {
        let (client, _) = await MainActor.run {
            makeClient(headersJSON: "{bad", extraBodyJSON: "not json")
        }
        AIMockURLProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let json = "{\"choices\":[{\"message\":{\"content\":\"hi\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "p", chunk: "c")
        XCTAssertEqual(output, "hi")
    }

    func testTimeoutRetriesOnceThenThrows() async {
        let (client, _) = await MainActor.run {
            makeClient()
        }
        var count = 0
        AIMockURLProtocol.handler = { _ in
            count += 1
            throw URLError(.timedOut)
        }
        do {
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(count, 2)
        }
    }

    func testHttp500RetriesOnceThenThrows() async {
        let (client, _) = await MainActor.run {
            makeClient()
        }
        var count = 0
        AIMockURLProtocol.handler = { request in
            count += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"error\":\"server\"}".utf8))
        }
        do {
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(count, 2)
            if case let AIClientError.httpError(code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("expected httpError 500, got \(error)")
            }
        }
    }

    func testFailedChunkRetriesOnceWithStableRequestId() async throws {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        var count = 0
        AIMockURLProtocol.handler = { request in
            count += 1
            if count == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("{\"error\":\"server\"}".utf8))
            }
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let ctx = AIDiagnosticsContext(
            bookId: "b",
            chapterNumber: 1,
            mode: "rewrite",
            chunkIndex: 0,
            chunkTotal: 1
        )
        let output = try await client.complete(prompt: "p", chunk: "hello", context: ctx)
        XCTAssertEqual(output, "ok")
        XCTAssertEqual(count, 2)
        let entries = await DiagnosticsLog.shared.snapshot()
        let related = entries.filter { $0.requestId == ctx.requestId }
        XCTAssertFalse(related.isEmpty)
        let attempts = related.compactMap { $0.attempt }.sorted()
        XCTAssertTrue(attempts.contains(1) && attempts.contains(2), "attempts \(attempts)")
    }

    func testCancelledTaskThrowsImmediatelyWithoutRetry() async {
        let (client, _) = await MainActor.run {
            makeClient()
        }
        var count = 0
        AIMockURLProtocol.handler = { request in
            count += 1
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let task = Task<String, Error> {
            try await client.complete(prompt: "p", chunk: "c")
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("should throw CancellationError")
        } catch {
            XCTAssertTrue(error is CancellationError, "expected CancellationError, got \(error)")
            XCTAssertLessThanOrEqual(count, 1, "cancelled chunk must never retry, got \(count)")
        }
    }

    func testHttp200SingleAttemptSuccess() async throws {
        let (client, _) = await MainActor.run {
            makeClient()
        }
        var count = 0
        AIMockURLProtocol.handler = { request in
            count += 1
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "p", chunk: "c")
        XCTAssertEqual(output, "ok")
        XCTAssertEqual(count, 1)
    }

    func testEmptyChoicesThrows() async {
        let (client, _) = await MainActor.run {
            makeClient()
        }
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        do {
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            let description = error.localizedDescription.lowercased()
            let string = "\(error)".lowercased()
            XCTAssertTrue(description.contains("no response") || string.contains("noresponse"))
        }
    }

    func testNullContentWithReasoningSucceeds() async throws {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":null,\"reasoning_content\":\"suy luan\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "p", chunk: "c")
        XCTAssertEqual(output, "suy luan")
    }

    func testToolCallsOnlyThrowsNoResponseWithShape() async {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        let raw = "{\"choices\":[{\"message\":{\"content\":null," +
            "\"tool_calls\":[{\"id\":\"x\",\"type\":\"function\"}]}}]}"
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
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            XCTAssertTrue("\(error)".lowercased().contains("noresponse"))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let failures = entries.filter { $0.errorDomain == "AIClientError.noResponse" }
        XCTAssertFalse(failures.isEmpty)
        let shape = try? XCTUnwrap(failures.last)
        XCTAssertEqual(shape?.choicesCount, 1)
        XCTAssertEqual(shape?.contentKind, "null")
        XCTAssertEqual(shape?.hasToolCalls, true)
        XCTAssertEqual(shape?.hasReasoningContent, false)
        XCTAssertTrue(shape?.responseJsonKeys?.contains("choices") ?? false)
        for entry in entries {
            let combined = "\(entry.debugSummary) \(entry.detail ?? "") \(entry.snippet ?? "")"
            XCTAssertFalse(combined.contains(raw))
        }
    }

    func testEnvelopeDataThrowsNoResponseWithShape() async {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        AIMockURLProtocol.handler = { request in
            let json = "{\"data\":{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        do {
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            XCTAssertTrue("\(error)".lowercased().contains("noresponse"))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let failures = entries.filter {
            $0.errorDomain == "DecodingError" || $0.errorDomain == "AIClientError.noResponse"
        }
        XCTAssertFalse(failures.isEmpty)
        let shape = try? XCTUnwrap(failures.last)
        XCTAssertEqual(shape?.responseJsonKeys, ["data"])
        XCTAssertNil(shape?.choicesCount)
        XCTAssertEqual(shape?.contentKind, "missing")
    }

    func testEmptyStringContentThrowsWithShape() async {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"   \"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        do {
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            XCTAssertTrue("\(error)".lowercased().contains("noresponse"))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let failures = entries.filter { $0.errorDomain == "AIClientError.noResponse" }
        XCTAssertEqual(failures.last?.contentKind, "empty-string")
        XCTAssertEqual(failures.last?.choicesCount, 1)
    }

    func testApiEntriesCarryFullBodiesAndFullURLOnSuccess() async throws {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        let run = UUID()
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let ctx = AIDiagnosticsContext(
            bookId: "b",
            chapterNumber: 20,
            mode: "rewrite",
            chunkIndex: 0,
            chunkTotal: 1,
            runId: run
        )
        let output = try await client.complete(prompt: "sys", chunk: "hello", context: ctx)
        XCTAssertEqual(output, "ok")
        let entries = await DiagnosticsLog.shared.snapshot()
        let api = entries.filter { $0.kind == .api && $0.requestId == ctx.requestId }
        XCTAssertEqual(api.count, 2, "request + success entries")
        for entry in api {
            XCTAssertEqual(entry.runId, run)
            XCTAssertEqual(entry.host, "http://localhost:8317/v1/chat/completions")
            XCTAssertTrue(
                entry.requestBody?.contains("\"messages\"") ?? false,
                "requestBody \(entry.requestBody ?? "")"
            )
        }
        let success = try XCTUnwrap(api.first { $0.statusCode == 200 })
        XCTAssertTrue(
            success.responseBody?.contains("\"choices\"") ?? false,
            "responseBody \(success.responseBody ?? "")"
        )
        XCTAssertTrue(success.responseBody?.contains("ok") ?? false)
    }

    func testFailEntriesCarryBodiesAndFullURL() async {
        await DiagnosticsLog.shared.clear()
        let (client, _) = await MainActor.run {
            makeClient()
        }
        AIMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"error\":\"server\"}".utf8))
        }
        let ctx = AIDiagnosticsContext(bookId: "b", chapterNumber: 20, mode: "rewrite")
        do {
            _ = try await client.complete(prompt: "p", chunk: "c", context: ctx)
            XCTFail("should throw")
        } catch {
            XCTAssertTrue("\(error)".lowercased().contains("httperror"))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let failures = entries.filter {
            $0.requestId == ctx.requestId && $0.errorDomain == "AIClientError.httpError"
        }
        XCTAssertEqual(failures.count, 2, "attempt 1 + attempt 2 fail entries")
        for entry in failures {
            XCTAssertEqual(entry.host, "http://localhost:8317/v1/chat/completions")
            XCTAssertTrue(entry.requestBody?.contains("\"messages\"") ?? false)
            XCTAssertTrue(entry.responseBody?.contains("server") ?? false, "responseBody \(entry.responseBody ?? "")")
        }
    }

    private func capturedBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
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
        return data
    }

    func testExtraBodyStripsReservedKeysAndMergesAllowedKeys() async throws {
        let extra = "{\"model\":\"user-model\"," +
            "\"messages\":[{\"role\":\"user\",\"content\":\"injected\"}]," +
            "\"stream\":true,\"temperature\":0.7,\"top_p\":0.9}"
        let (client, _) = await MainActor.run {
            makeClient(extraBodyJSON: extra)
        }
        var captured: Data?
        AIMockURLProtocol.handler = { request in
            captured = self.capturedBodyData(from: request)
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "system-prompt", chunk: "user-chunk")
        XCTAssertEqual(output, "ok")
        let body = try XCTUnwrap(captured)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        // System-owned keys win: user-supplied model/messages are stripped; stream is always false.
        XCTAssertEqual(dict["model"] as? String, "gpt-4o")
        XCTAssertEqual(dict["stream"] as? Bool, false)
        let messages = try XCTUnwrap(dict["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "system-prompt")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[1]["content"] as? String, "user-chunk")
        XCTAssertFalse(messages.contains { "\($0)".contains("injected") })
        // Allowed keys merge through.
        if let temp = dict["temperature"] as? Double {
            XCTAssertEqual(temp, 0.7, accuracy: 0.0001)
        } else if let num = dict["temperature"] as? NSNumber {
            XCTAssertEqual(num.doubleValue, 0.7, accuracy: 0.0001)
        } else {
            XCTFail("temperature missing or wrong type: \(String(describing: dict["temperature"]))")
        }
        XCTAssertNotNil(dict["top_p"])
    }

    func testWhitespacePaddedURLFallsBackToTrimmed() async throws {
        await DiagnosticsLog.shared.clear()
        let padded = "  http://localhost:8317/v1/chat/completions  "
        let (client, _) = await MainActor.run {
            makeClient(url: padded)
        }
        var count = 0
        AIMockURLProtocol.handler = { request in
            count += 1
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:8317/v1/chat/completions")
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        var output: String?
        var thrown: Error?
        do {
            output = try await client.complete(prompt: "p", chunk: "c")
        } catch {
            thrown = error
        }
        // Padded openaiAPIURL is trimmed before URL(string:) (untrimmed fails to parse).
        XCTAssertNil(thrown, "padded URL should be trimmed, threw \(String(describing: thrown))")
        XCTAssertEqual(output, "ok")
        XCTAssertEqual(count, 1)
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertTrue(entries.allSatisfy { $0.host == "http://localhost:8317/v1/chat/completions" })
    }

    func testEndpointFamilyDetection() {
        XCTAssertEqual(
            AIEndpointFamily.detect(urlString: "http://localhost:8317/v1/chat/completions"),
            .chatCompletions
        )
        XCTAssertEqual(AIEndpointFamily.detect(urlString: "https://api.openai.com/v1/responses"), .responses)
        XCTAssertEqual(AIEndpointFamily.detect(urlString: "https://API.OPENAI.COM/V1/RESPONSES"), .responses)
        XCTAssertEqual(AIEndpointFamily.detect(urlString: "https://api.anthropic.com/v1/messages"), .anthropic)
        XCTAssertEqual(
            AIEndpointFamily.detect(urlString: "http://localhost:8317/v1/chat/completions"),
            .chatCompletions
        )
    }

    func testChatBuilderIncludesStreamFalse() throws {
        let data = try AIClient.makeRequestBodyData(
            model: "gpt-4o",
            prompt: "sys",
            chunk: "hi",
            extra: [:],
            urlString: "http://localhost:8317/v1/chat/completions"
        )
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["stream"] as? Bool, false)
        let messages = try XCTUnwrap(dict["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["content"] as? String, "sys")
        XCTAssertEqual(messages[1]["content"] as? String, "hi")
    }

    func testResponsesBuilderUsesInstructionsInputAndStripsReserved() throws {
        var extra: [String: Any] = [:]
        extra["model"] = "injected"
        extra["input"] = "injected"
        extra["instructions"] = "injected"
        extra["stream"] = true
        extra["temperature"] = 0.5
        extra["reasoning"] = ["effort": "medium"]
        let data = try AIClient.makeRequestBodyData(
            model: "gpt-4o",
            prompt: "sys",
            chunk: "chk",
            extra: extra,
            urlString: "https://api.openai.com/v1/responses"
        )
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["model"] as? String, "gpt-4o")
        XCTAssertEqual(dict["instructions"] as? String, "sys")
        XCTAssertEqual(dict["input"] as? String, "chk")
        XCTAssertEqual(dict["stream"] as? Bool, false)
        XCTAssertNil(dict["messages"])
        XCTAssertNotNil(dict["temperature"])
        XCTAssertNotNil(dict["reasoning"])
    }

    func testAnthropicBuilderDefaultsAndStripsReserved() throws {
        let data = try AIClient.makeRequestBodyData(
            model: "claude-x",
            prompt: "sys",
            chunk: "chk",
            extra: ["model": "injected", "system": "injected", "stream": true],
            urlString: "https://api.anthropic.com/v1/messages"
        )
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["model"] as? String, "claude-x")
        XCTAssertEqual(dict["system"] as? String, "sys")
        XCTAssertEqual(dict["stream"] as? Bool, false)
        let messages = try XCTUnwrap(dict["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        XCTAssertEqual(messages[0]["content"] as? String, "chk")
        if let tokens = dict["max_tokens"] as? Int {
            XCTAssertEqual(tokens, 1024)
        } else if let num = dict["max_tokens"] as? NSNumber {
            XCTAssertEqual(num.intValue, 1024)
        } else {
            XCTFail("max_tokens missing")
        }
    }

    func testAnthropicBuilderRespectsMaxTokensOverride() throws {
        let data = try AIClient.makeRequestBodyData(
            model: "claude-x",
            prompt: "sys",
            chunk: "chk",
            extra: ["max_tokens": 512],
            urlString: "https://api.anthropic.com/v1/messages"
        )
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        if let tokens = dict["max_tokens"] as? Int {
            XCTAssertEqual(tokens, 512)
        } else if let num = dict["max_tokens"] as? NSNumber {
            XCTAssertEqual(num.intValue, 512)
        } else {
            XCTFail("max_tokens missing")
        }
    }

    func testAnthropicVersionHeaderInjected() async throws {
        let (client, _) = await MainActor.run {
            makeClient(url: "https://api.anthropic.com/v1/messages")
        }
        var captured: URLRequest?
        AIMockURLProtocol.handler = { request in
            captured = request
            let json = "{\"content\":[{\"type\":\"text\",\"text\":\"ok\"}],\"stop_reason\":\"end_turn\"}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "sys", chunk: "hi")
        XCTAssertEqual(output, "ok")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let capturedRequest = try XCTUnwrap(captured)
        let body = try XCTUnwrap(capturedBodyData(from: capturedRequest))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(dict["stream"] as? Bool, false)
        XCTAssertEqual(dict["system"] as? String, "sys")
    }

    func testAnthropicVersionHeaderPreservedWhenPresent() async throws {
        let (client, _) = await MainActor.run {
            makeClient(
                headersJSON: "{\"anthropic-version\":\"2024-01-01\"}",
                url: "https://api.anthropic.com/v1/messages"
            )
        }
        var captured: URLRequest?
        AIMockURLProtocol.handler = { request in
            captured = request
            let json = "{\"content\":[{\"type\":\"text\",\"text\":\"ok\"}],\"stop_reason\":\"end_turn\"}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "sys", chunk: "hi")
        XCTAssertEqual(output, "ok")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "anthropic-version"), "2024-01-01")
    }

    func testResponsesParserPrefersOutputText() throws {
        let json = "{\"output_text\":\"hello\",\"output\":[{\"type\":\"message\"," +
            "\"content\":[{\"type\":\"output_text\",\"text\":\"other\"}]}],\"status\":\"completed\"}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(AIResponsesResponse.self, from: data)
        XCTAssertEqual(decoded.resolvedText, "hello")
        XCTAssertEqual(AIUnifiedResponse.resolve(data: data, family: .responses), "hello")
    }

    func testResponsesParserFallbackWalksOutput() throws {
        let json = "{\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\"," +
            "\"text\":\"hel\"},{\"type\":\"output_text\",\"text\":\"lo\"}]}],\"status\":\"completed\"}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertEqual(AIUnifiedResponse.resolve(data: data, family: .responses), "hello")
    }

    func testResponsesParserRefusalOnlyIsNil() throws {
        let json = "{\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"refusal\",\"refusal\":\"no\"}]}]}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertNil(AIUnifiedResponse.resolve(data: data, family: .responses))
    }

    func testAnthropicParserJoinsTextIgnoresThinking() throws {
        let json = "{\"content\":[{\"type\":\"thinking\",\"thinking\":\"hmm\"}," +
            "{\"type\":\"text\",\"text\":\"he\"},{\"type\":\"text\",\"text\":\"llo\"}," +
            "{\"type\":\"tool_use\",\"text\":\"ignored?\"}],\"stop_reason\":\"end_turn\"}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        // tool_use block has type tool_use so its text must be ignored even if present.
        XCTAssertEqual(AIUnifiedResponse.resolve(data: data, family: .anthropic), "hello")
    }

    func testResponsesEndToEndViaComplete() async throws {
        let (client, _) = await MainActor.run {
            makeClient(url: "https://api.openai.com/v1/responses")
        }
        var captured: URLRequest?
        AIMockURLProtocol.handler = { request in
            captured = request
            let json = "{\"output_text\":\"done\",\"status\":\"completed\"}"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
        let output = try await client.complete(prompt: "sys", chunk: "hi")
        XCTAssertEqual(output, "done")
        let capturedRequest = try XCTUnwrap(captured)
        let body = try XCTUnwrap(capturedBodyData(from: capturedRequest))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(dict["input"] as? String, "hi")
        XCTAssertEqual(dict["instructions"] as? String, "sys")
        XCTAssertEqual(dict["stream"] as? Bool, false)
    }

    func testResponsesShapeLogging() throws {
        let json = "{\"output_text\":\"hi\",\"output\":[{\"type\":\"reasoning\"}," +
            "{\"type\":\"function_call\"}],\"status\":\"completed\"}"
        let shape = try AIResponseShape.parse(XCTUnwrap(json.data(using: .utf8)))
        XCTAssertEqual(shape.choicesCount, 2)
        XCTAssertEqual(shape.contentKind, "ok")
        XCTAssertEqual(shape.hasReasoningContent, true)
        XCTAssertEqual(shape.hasToolCalls, true)
    }

    func testAnthropicShapeLogging() throws {
        let json = "{\"content\":[{\"type\":\"thinking\"}," +
            "{\"type\":\"text\",\"text\":\"hi\"}],\"stop_reason\":\"end_turn\"}"
        let shape = try AIResponseShape.parse(XCTUnwrap(json.data(using: .utf8)))
        XCTAssertEqual(shape.choicesCount, 2)
        XCTAssertEqual(shape.contentKind, "ok")
        XCTAssertEqual(shape.hasReasoningContent, true)
        XCTAssertEqual(shape.hasToolCalls, false)
    }
}
