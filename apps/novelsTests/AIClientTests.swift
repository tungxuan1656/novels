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

    func testRetries3TimesThenThrows() async {
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
            XCTAssertEqual(count, 3)
        }
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
}
