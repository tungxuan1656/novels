@testable import novels
import XCTest

@MainActor
final class RouterSettingsTests: XCTestCase {
    func testRoutesExistByPushSeparateRouters() {
        let router1 = Router()
        router1.push(.settings)
        XCTAssertEqual(router1.path.count, 1)

        let router2 = Router()
        router2.push(.cacheManager)
        XCTAssertEqual(router2.path.count, 1)

        let router3 = Router()
        router3.push(.settingEditor(settingKey: "OPENAI_MODEL"))
        XCTAssertEqual(router3.path.count, 1)

        let router4 = Router()
        router4.push(.settingEditor(settingKey: "AI_MIN_CHUNK_SIZE"))
        XCTAssertEqual(router4.path.count, 1)
    }

    func testDebounceOnSingleRouterBlocksSecondPushWithin100ms() async throws {
        let router = Router()
        router.push(.settings)
        XCTAssertEqual(router.path.count, 1)
        // Immediate second push should be debounced
        router.push(.cacheManager)
        XCTAssertEqual(router.path.count, 1)
        XCTAssertEqual(router.toast.lastMessage, "Vui lòng chờ")
        // After debounce window, push should succeed
        try await Task.sleep(nanoseconds: 120_000_000)
        router.push(.cacheManager)
        XCTAssertEqual(router.path.count, 2)
    }

    func testSettingsViewDescriptorsContainExpectedLabels() {
        // swiftlint:disable trailing_comma
        let expectations: [String: String] = [
            "BOOKS_API_URL": "URL Danh mục",
            "OPENAI_API_URL": "URL OpenAI",
            "OPENAI_MODEL": "Mô hình",
            "AI_CUSTOM_HEADERS": "Headers tùy chỉnh (JSON)",
            "AI_EXTRA_BODY": "Body bổ sung (JSON)",
            "AI_PROVIDER": "Nhà cung cấp",
            "AI_PROCESS_ACTIONS": "Hành động AI (JSON)",
            "PREFETCH_COUNT": "Số chương tải trước",
            "AI_MIN_CHUNK_SIZE": "Kích thước chunk",
        ]
        // swiftlint:enable trailing_comma
        for (key, expectedLabel) in expectations {
            let descriptor = SettingsViewModel.descriptor(for: key)
            XCTAssertEqual(descriptor.label, expectedLabel, "label mismatch for \(key)")
            XCTAssertEqual(descriptor.key, key)
        }
        // Typography keys also resolve
        XCTAssertEqual(SettingsViewModel.descriptor(for: "font").label, "Phông chữ")
        XCTAssertEqual(SettingsViewModel.descriptor(for: "fontSize").label, "Cỡ chữ")
        XCTAssertEqual(SettingsViewModel.descriptor(for: "lineHeight").label, "Giãn dòng")
    }

    func testTypographyPersistLive() throws {
        let suite = "test.live.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.fontSize = 20
        store.save()
        let reloaded = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.typography.fontSize, 20)
    }

    func testRouterPopResetsDebounce() async throws {
        let router = Router()
        router.push(.settings)
        XCTAssertEqual(router.path.count, 1)
        router.pop()
        XCTAssertEqual(router.path.count, 0)
        // After pop, immediate push should succeed (pop resets isPushing)
        router.push(.cacheManager)
        XCTAssertEqual(router.path.count, 1)
        // Verify debounce still active immediately after
        router.push(.settings)
        XCTAssertEqual(router.path.count, 1)
        try await Task.sleep(nanoseconds: 120_000_000)
        router.push(.settings)
        XCTAssertEqual(router.path.count, 2)
    }
}
