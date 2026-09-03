@testable import novels
import XCTest

final class AIIntegrationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    func testInvalidHeadersIgnoredAndStillSucceeds() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = try XCTUnwrap(UserDefaults(suiteName: "int.\(UUID().uuidString)"))
        let settings = await MainActor.run {
            let store = SettingsStore(userDefaults: suite)
            store.aiCustomHeadersJSON = "{bad json"
            store.aiExtraBodyJSON = "not object"
            store.save()
            return store
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
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
        let client = AIClient(settings: settings, session: URLSession(configuration: config))
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        let output = try await service.processedContent(
            bookId: "b",
            chapterNumber: 1,
            mode: .rewrite,
            rawText: "hello world this is a test"
        )
        XCTAssertEqual(output, "ok")
    }

    func testModeNoneNeverWritesCacheEvenWithLongText() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = try XCTUnwrap(UserDefaults(suiteName: "int2.\(UUID().uuidString)"))
        let settings = await MainActor.run {
            SettingsStore(userDefaults: suite)
        }
        let client = AIClient(settings: settings, session: URLSession(configuration: .ephemeral))
        let service = AIReadingService(cache: cache, client: client, settings: settings)
        let longText = String(repeating: "a", count: 3000)
        let output = try await service.processedContent(
            bookId: "b",
            chapterNumber: 5,
            mode: .none,
            rawText: longText
        )
        XCTAssertEqual(output, longText)
        XCTAssertEqual(try cache.countAll(), 0)
        XCTAssertNil(try cache.get(bookId: "b", chapterNumber: 5, mode: .none))
    }

    func testATSSchemeIsLocalhostOnly() {
        var plist: [String: Any]?
        if let dict = Bundle.main.infoDictionary?["NSAppTransportSecurity"] as? [String: Any] {
            plist = dict
        }
        func ats(fromPath path: String) -> [String: Any]? {
            guard let data = FileManager.default.contents(atPath: path) else { return nil }
            guard let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else {
                return nil
            }
            return obj["NSAppTransportSecurity"] as? [String: Any]
        }
        if plist == nil {
            let p1 = Bundle(for: Self.self).path(forResource: "Info", ofType: "plist")
            let p2 = Bundle.main.path(forResource: "Info", ofType: "plist")
            let candidates = [p1, p2].compactMap { $0 }
            for cand in candidates {
                if let found = ats(fromPath: cand) {
                    plist = found
                    break
                }
            }
        }
        if plist == nil {
            plist = ats(fromPath: "apps/novels/Info.plist")
        }
        if plist == nil {
            plist = ats(fromPath: "/Users/tungdoan/Projects/iOS/novels/apps/novels/Info.plist")
        }
        guard let ats = plist else {
            XCTFail("NSAppTransportSecurity not found in Info.plist")
            return
        }
        XCTAssertNil(ats["NSAllowsArbitraryLoads"], "ATS must not allow arbitrary loads")
        XCTAssertNil(ats["NSAllowsArbitraryLoadsInWebContent"])
        guard let domains = ats["NSExceptionDomains"] as? [String: Any] else {
            XCTFail("NSExceptionDomains missing")
            return
        }
        XCTAssertNotNil(domains["localhost"], "localhost must be whitelisted")
        XCTAssertNil(domains["example.com"], "only localhost should be whitelisted")
        if let localhost = domains["localhost"] as? [String: Any] {
            XCTAssertEqual(localhost["NSExceptionAllowsInsecureHTTPLoads"] as? Bool, true)
        }
    }
}
