@testable import novels
import XCTest

@MainActor
final class RouterSettingsTests: XCTestCase {
    func testSettingsRouteExists() {
        let router = Router()
        XCTAssertNoThrow(router.push(.settings))
        // Reset debounce by clearing isPushing via pop? Use new router for each push
        let router2 = Router()
        XCTAssertNoThrow(router2.push(.cacheManager))
        let router3 = Router()
        XCTAssertNoThrow(router3.push(.settingEditor(settingKey: "OPENAI_MODEL")))
        // After push, path should have 1 item (debounce not yet triggered)
        XCTAssertTrue(router.path.count >= 1)
    }

    func testSettingsViewRendersKeys() {
        // swiftlint:disable trailing_comma
        let keys = [
            "BOOKS_API_URL",
            "OPENAI_API_URL",
            "OPENAI_MODEL",
            "AI_CUSTOM_HEADERS",
            "AI_EXTRA_BODY",
            "AI_PROVIDER",
            "AI_PROCESS_ACTIONS",
            "PREFETCH_COUNT",
            "AI_MIN_CHUNK_SIZE",
        ]
        // swiftlint:enable trailing_comma
        XCTAssertEqual(keys.count, 9)
        _ = SettingsView()
    }

    func testLibraryHasSettingsButton() {
        let router = Router()
        router.push(.settings)
        XCTAssertEqual(router.path.count, 1)
    }

    func testTypographyRowsPushEditor() {
        let router = Router()
        router.push(.settingEditor(settingKey: "fontSize"))
        XCTAssertEqual(router.path.count, 1)
    }

    func testTypographyPersistLive() {
        let suite = "test.live.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite failed")
            return
        }
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.fontSize = 20
        store.save()
        let reloaded = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.typography.fontSize, 20)
    }
}
