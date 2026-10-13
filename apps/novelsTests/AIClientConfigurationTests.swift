import Foundation
@testable import novels
import XCTest

@MainActor
final class AIClientConfigurationTests: XCTestCase {
    func testActualBearerOverrideAndStructuredResponsesBody() async throws {
        let name = "AIClientConfigurationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(userDefaults: defaults)
        store.openaiAPIURL = "https://ai-fixture.test/v1/responses"
        store.openaiModel = "muse-spark-fixture"
        store.aiProvider = "auto"
        store.aiThinkingEffort = "low"
        store.aiAPIKey = " fixture-generated-key "
        store.aiExtraBodyJSON = #"{"text":{"verbosity":"low"}}"#
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = AIClient(settings: store, session: session)
        let schema = AIOutputSchema(
            name: "result",
            json: #"{"type":"object","properties":{},"required":[],"additionalProperties":false}"#
        )
        for custom in ["", #"{"aUtHoRiZaTiOn":"Bearer fixture-custom-key"}"#] {
            store.aiCustomHeadersJSON = custom
            AIConfigurationURLProtocol.configure(status: 200, response: #"{"status":"completed","output_text":"{}"}"#)
            let output = try await client.complete(
                prompt: "fixture prompt",
                chunk: "fixture chunk",
                outputSchema: schema
            )
            XCTAssertEqual(output, "{}")
            let request = try XCTUnwrap(AIConfigurationURLProtocol.requests().first)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                           custom.isEmpty ? "Bearer fixture-generated-key" : "Bearer fixture-custom-key")
            let body = try requestObject(request)
            XCTAssertEqual(body["model"] as? String, "muse-spark-fixture")
            XCTAssertEqual((body["reasoning"] as? [String: String])?["effort"], "low")
            XCTAssertEqual((body["text"] as? [String: Any])?["verbosity"] as? String, "low")
            XCTAssertNotNil((body["text"] as? [String: Any])?["format"])
            XCTAssertTrue((body["instructions"] as? String)?.contains(schema.json) == true)
            let entries = await DiagnosticsLog.shared.snapshot()
            let logged = try XCTUnwrap(entries.last(where: { $0.kind == .api && $0.headersRedacted != nil }))
            XCTAssertTrue(logged.headersRedacted?.values.contains("<redacted>") == true)
            XCTAssertFalse(logged.debugSummary.contains("fixture-generated-key"))
            XCTAssertFalse(logged.debugSummary.contains("fixture-custom-key"))
        }
    }

    func testRejectedProviderKeepsIdenticalRequestOnBoundedRetry() async throws {
        let name = "AIClientConfigurationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(userDefaults: defaults)
        store.openaiAPIURL = "https://ai-fixture.test/v1/chat/completions"
        store.aiProvider = "muse"
        store.aiThinkingEffort = "none"
        AIConfigurationURLProtocol.configure(status: 400, response: #"{"error":{"message":"unsupported effort"}}"#)
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = AIClient(settings: store, session: session)
        do {
            _ = try await client.complete(prompt: "prompt", chunk: "chunk")
            XCTFail("Provider rejection must not downgrade")
        } catch let error as AIClientError {
            guard case .httpError(400, _) = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let requests = AIConfigurationURLProtocol.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(try requestObject(requests[0]) as NSDictionary, try requestObject(requests[1]) as NSDictionary)
        XCTAssertEqual(try requestObject(requests[0])["reasoning_effort"] as? String, "none")
    }

    func testInvalidConfigurationFailsBeforeNetworkAndCancellationStaysSilent() async throws {
        let name = "AIClientConfigurationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(userDefaults: defaults)
        store.openaiAPIURL = "https://ai-fixture.test/v1/chat/completions"
        store.aiProvider = "mimo"
        store.aiThinkingEffort = "medium"
        AIConfigurationURLProtocol.configure(status: 200, response: "{}")
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = AIClient(settings: store, session: session)
        do {
            _ = try await client.complete(prompt: "prompt", chunk: "chunk")
            XCTFail("MiMo depth is undocumented")
        } catch let error as AIClientError {
            guard case .invalidConfiguration = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(AIConfigurationURLProtocol.requests().isEmpty)
        let task = Task { try await client.complete(prompt: "prompt", chunk: "chunk") }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(AIConfigurationURLProtocol.requests().isEmpty)
        }
    }

    func testCancelledTransportIsLoggedOnceWithoutRetry() async throws {
        let name = "AIClientCancellationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(userDefaults: defaults)
        store.openaiAPIURL = "https://ai-fixture.test/v1/chat/completions"
        AIConfigurationURLProtocol.configure(status: 200, response: "", error: .cancelled)
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = AIClient(settings: store, session: session)
        let context = AIDiagnosticsContext(requestId: UUID())
        do {
            _ = try await client.complete(prompt: "prompt", chunk: "chunk", context: context)
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(AIConfigurationURLProtocol.requests().count, 1)
        let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
        XCTAssertEqual(entries.filter { $0.errorCode == URLError.cancelled.rawValue }.count, 1)
        XCTAssertFalse(entries.contains(where: LogEntry.isError))
    }

    func testInvalidStrictSchemaFailsBeforeNetworkForChatAndResponses() async throws {
        let name = "AIClientConfigurationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(userDefaults: defaults)
        store.aiProvider = "openai"
        AIConfigurationURLProtocol.configure(status: 200, response: "{}")
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = AIClient(settings: store, session: session)
        let schema = AIOutputSchema(
            name: "result", json: #"{"type":"object","properties":{"text":{"type":"string"}}}"#
        )
        for path in ["chat/completions", "responses"] {
            store.openaiAPIURL = "https://ai-fixture.test/v1/\(path)"
            do {
                _ = try await client.complete(prompt: "prompt", chunk: "chunk", outputSchema: schema)
                XCTFail("Strict schema must fail locally")
            } catch let error as AIClientError {
                guard case .invalidConfiguration = error else { return XCTFail("Unexpected error: \(error)") }
            }
        }
        XCTAssertTrue(AIConfigurationURLProtocol.requests().isEmpty)
    }

    func testBearerDefaultsRespectCustomAnthropicHeaders() {
        let headers = AIClient.effectiveRequestHeaders(
            ["AUTHORIZATION": "custom", "Anthropic-Version": "fixture-version", "x-api-key": "fixture-native"],
            family: .anthropic, apiKey: "fixture-generated"
        )
        XCTAssertEqual(headers["AUTHORIZATION"], "custom")
        XCTAssertNil(headers["Authorization"])
        XCTAssertEqual(headers["Anthropic-Version"], "fixture-version")
        XCTAssertEqual(headers["x-api-key"], "fixture-native")
        let empty = AIClient.effectiveRequestHeaders([:], family: .anthropic, apiKey: " \n ")
        XCTAssertNil(empty["Authorization"])
        XCTAssertEqual(empty["anthropic-version"], "2023-06-01")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIConfigurationURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func requestObject(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final nonisolated class AIConfigurationURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var status = 200
    private nonisolated(unsafe) static var response = "{}"
    private nonisolated(unsafe) static var captured: [URLRequest] = []
    private nonisolated(unsafe) static var error: URLError.Code?

    static func configure(status: Int, response: String, error: URLError.Code? = nil) {
        lock.withLock {
            self.status = status
            self.response = response
            self.error = error
            captured = []
        }
    }

    static func requests() -> [URLRequest] {
        lock.withLock { captured }
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "ai-fixture.test"
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var copy = request
        if copy.httpBody == nil, let stream = copy.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            var count = stream.read(&buffer, maxLength: buffer.count)
            while count > 0 {
                data.append(buffer, count: count)
                count = stream.read(&buffer, maxLength: buffer.count)
            }
            copy.httpBody = data
        }
        let fixture = Self.lock.withLock {
            Self.captured.append(copy)
            return (Self.status, Self.response, Self.error)
        }
        if let error = fixture.2 {
            client?.urlProtocol(self, didFailWithError: URLError(error))
            return
        }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: fixture.0, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"])
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(fixture.1.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
