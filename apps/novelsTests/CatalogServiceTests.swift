@testable import novels
import XCTest

final class MockState {
    var requestValidator: ((URLRequest) -> Void)?
    var response: CatalogResponse?
    var error: Error?
}

final class MockURLProtocol: URLProtocol {
    static var current: MockState?

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let validator = MockURLProtocol.current?.requestValidator {
            validator(request)
        }
        if let error = MockURLProtocol.current?.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response = MockURLProtocol.current?.response {
            do {
                let data = try JSONEncoder().encode(response)
                let httpResponse = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
private func makeService(url: String) -> (CatalogService, MockState) {
    let state = MockState()
    MockURLProtocol.current = state
    let suite = UserDefaults(suiteName: UUID().uuidString)!
    let store = SettingsStore(userDefaults: suite)
    store.booksAPIURL = url
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    let service = CatalogService(settingsStore: store, session: session)
    return (service, state)
}

@MainActor
final class CatalogServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.current = nil
    }

    func testCatalogResponseDecodeSuccess() throws {
        // swiftlint:disable line_length
        let jsonString = """
        {"success":true,"data":[{"id":1,"bookId":1,"exportUrl":"https://ex.com/a.zip","fileSize":12345,"exportFormat":"zip","exportedAt":"2024-12-03T00:00:00Z","updatedAt":"2024-12-03T00:00:00Z","book":{"id":1,"name":"Test Book","slug":"test-book","author":"Author","chapterCount":2,"status":"completed","synopsis":"syn","lastUpdated":"2024-12-03T00:00:00Z"}}],"message":null}
        """
        // swiftlint:enable line_length
        let json = try XCTUnwrap(jsonString.data(using: .utf8))
        let res = try JSONDecoder().decode(CatalogResponse.self, from: json)
        XCTAssertTrue(res.success)
        XCTAssertEqual(res.data.first?.book.slug, "test-book")
        XCTAssertEqual(res.data.first?.book.author, "Author")
    }

    func testCatalogResponseDecodeSuccessFalse() throws {
        let jsonString = #"{"success":false,"data":[],"message":"Quota exceeded"}"#
        let json = try XCTUnwrap(jsonString.data(using: .utf8))
        let res = try JSONDecoder().decode(CatalogResponse.self, from: json)
        XCTAssertFalse(res.success)
        XCTAssertEqual(res.message, "Quota exceeded")
    }

    func testFetchSendsEmptyBodyWithJSONContentType() async throws {
        let (service, proto) = makeService(url: "https://example.com/catalog")
        proto.requestValidator = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(req.httpBody?.count ?? 0, 0)
            XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
        }
        proto.response = CatalogResponse(success: true, data: [], message: nil)
        _ = try await service.fetchCatalog()
    }

    func testSuccessFalseThrowsServerMessage() async throws {
        let (service, proto) = makeService(url: "https://example.com/catalog")
        proto.response = CatalogResponse(success: false, data: [], message: "Quota exceeded")
        do {
            _ = try await service.fetchCatalog()
            XCTFail("expected serverMessage")
        } catch let CatalogError.serverMessage(message) {
            XCTAssertEqual(message, "Quota exceeded")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testEmptyList() async throws {
        let (service, proto) = makeService(url: "https://example.com/catalog")
        proto.response = CatalogResponse(success: true, data: [], message: nil)
        let result = try await service.fetchCatalog()
        XCTAssertEqual(result.count, 0)
    }

    func testNetworkErrorPropagates() async throws {
        let (service, proto) = makeService(url: "https://example.com/catalog")
        proto.error = URLError(.notConnectedToInternet)
        do {
            _ = try await service.fetchCatalog()
            XCTFail("expected error")
        } catch {
            // Any error is acceptable; ideally CatalogError.network
            XCTAssertTrue(error is CatalogError || error is URLError)
        }
    }
}
