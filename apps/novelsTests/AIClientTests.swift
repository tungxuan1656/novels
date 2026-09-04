@testable import novels
import XCTest

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
}
