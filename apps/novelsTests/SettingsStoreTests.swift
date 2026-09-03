@testable import novels
import XCTest

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultsAndInvalidJSONIgnored() throws {
        let suite = UUID().uuidString
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.load()
        XCTAssertEqual(store.openaiModel, "gpt-4o")
        XCTAssertEqual(store.prefetchCount, 3)
        store.aiCustomHeadersJSON = "{bad"
        store.aiExtraBodyJSON = "{bad"
        store.sanitize()
        XCTAssertEqual(store.aiCustomHeadersJSON, "{bad")
        XCTAssertEqual(store.aiExtraBodyJSON, "{bad")
        XCTAssertTrue(store.effectiveHeaders().isEmpty)
        XCTAssertTrue(store.effectiveExtraBody().isEmpty)
    }

    func testUnknownLegacyIgnored() throws {
        let suite = UUID().uuidString
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        userDefaults.set("foo", forKey: "COPILOT_API_KEY")
        userDefaults.set("123", forKey: "BOOKS_API_URL")
        let store = SettingsStore(userDefaults: userDefaults)
        store.load()
        store.sanitize()
        XCTAssertEqual(store.booksAPIURL, "123")
        XCTAssertEqual(userDefaults.string(forKey: "COPILOT_API_KEY"), "foo")
        XCTAssertEqual(store.prefetchCount, 3)
    }

    func testSanitizeClampsPrefetchAndChunkAndTypography() throws {
        let suite = UUID().uuidString
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.load()
        store.prefetchCount = 99
        store.aiMinChunkSize = 100
        store.typography.fontSize = 100
        store.typography.lineHeight = 10.0
        store.typography.letterSpacing = 5.0
        store.sanitize()
        XCTAssertEqual(store.prefetchCount, 3)
        XCTAssertEqual(store.aiMinChunkSize, 1300)
        XCTAssertEqual(store.typography.fontSize, 16)
        XCTAssertEqual(store.typography.lineHeight, 1.5)
        XCTAssertEqual(store.typography.letterSpacing, 0)

        store.prefetchCount = 0
        store.sanitize()
        XCTAssertEqual(store.prefetchCount, 3)
        store.prefetchCount = 5
        store.sanitize()
        XCTAssertEqual(store.prefetchCount, 5)

        store.aiMinChunkSize = 6000
        store.sanitize()
        XCTAssertEqual(store.aiMinChunkSize, 1300)
        store.aiMinChunkSize = 2000
        store.sanitize()
        XCTAssertEqual(store.aiMinChunkSize, 2000)
    }

    func testProviderFallbackAndPromptReset() throws {
        let suite = UUID().uuidString
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.load()
        store.aiProvider = "DEEPSEEK"
        store.aiPrompt = "   "
        store.sanitize()
        XCTAssertEqual(store.aiProvider, "openai")
        XCTAssertEqual(store.aiPrompt, SettingsDefaults.defaultPrompt)

        store.aiProvider = "OpenAI"
        store.sanitize()
        XCTAssertEqual(store.aiProvider, "openai")
    }

    func testValidHeadersAndBodyParsed() throws {
        let suite = UUID().uuidString
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.load()
        store.aiCustomHeadersJSON = #"{"Authorization":"Bearer token"}"#
        store.aiExtraBodyJSON = #"{"temperature":0.7}"#
        store.sanitize()
        XCTAssertEqual(store.effectiveHeaders(), ["Authorization": "Bearer token"])
        let body = store.effectiveExtraBody()
        XCTAssertEqual(body.count, 1)
        XCTAssertNotNil(body["temperature"])
    }

    func testSaveAndLoadRoundTrip() throws {
        let suite = UUID().uuidString
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.load()
        store.booksAPIURL = "https://example.com/books"
        store.openaiModel = "gpt-4o-mini"
        store.prefetchCount = 7
        store.typography.fontSize = 20
        store.session = ReadingSession(bookId: "slug", onScreen: true, offset: 42.5, chapterNumber: 3)
        store.save()

        let store2 = SettingsStore(userDefaults: userDefaults)
        store2.load()
        store2.sanitize()
        XCTAssertEqual(store2.booksAPIURL, "https://example.com/books")
        XCTAssertEqual(store2.openaiModel, "gpt-4o-mini")
        XCTAssertEqual(store2.prefetchCount, 7)
        XCTAssertEqual(store2.typography.fontSize, 20)
        XCTAssertEqual(store2.session?.bookId, "slug")
        XCTAssertEqual(store2.session?.chapterNumber, 3)
    }
}
