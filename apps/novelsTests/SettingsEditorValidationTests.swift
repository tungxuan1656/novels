@testable import novels
import XCTest

@MainActor
final class SettingsEditorValidationTests: XCTestCase {
    func testPrefetchCountCoercion() {
        let suite = "test.prefetch.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite nil")
            return
        }
        let store = SettingsStore(userDefaults: userDefaults)
        store.prefetchCount = 0
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 0)
        store.prefetchCount = 99
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 99)
        store.prefetchCount = 1001
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 3)
        store.prefetchCount = -1
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 3)
        store.prefetchCount = 5
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 5)
        // Stored value should be readable as int via store; check via object
        let stored = userDefaults.object(forKey: "PREFETCH_COUNT")
        if let intVal = stored as? Int {
            XCTAssertEqual(intVal, 5)
        } else if let strVal = stored as? String {
            XCTAssertEqual(strVal, "5")
        } else {
            XCTFail("stored prefetch not found")
        }
    }

    func testProviderDefaultsToOpenAI() {
        let suite = "test.provider.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite nil")
            return
        }
        let store = SettingsStore(userDefaults: userDefaults)
        store.aiProvider = "unknown"
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiProvider.lowercased(), "openai")
        store.aiProvider = "OpenAI"
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiProvider.lowercased(), "openai")
    }

    func testInvalidHeadersStoredVerbatimEffectiveEmpty() {
        let suite = "test.headers.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite nil")
            return
        }
        let store = SettingsStore(userDefaults: userDefaults)
        store.aiCustomHeadersJSON = "{bad json"
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiCustomHeadersJSON, "{bad json")
        XCTAssertEqual(store.effectiveHeaders().isEmpty, true)
        store.aiCustomHeadersJSON = "{\"Authorization\":\"Bearer x\"}"
        store.save()
        XCTAssertEqual(store.effectiveHeaders()["Authorization"], "Bearer x")
    }

    func testTypographyClamp() {
        let suite = "test.typo.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite nil")
            return
        }
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.fontSize = 99
        store.typography.lineHeight = 99
        store.typography.letterSpacing = 5
        store.save()
        let reloaded = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.typography.fontSize, 16)
        XCTAssertEqual(reloaded.typography.lineHeight, 5)
        XCTAssertEqual(reloaded.typography.letterSpacing, 0)
    }

    func testSurvivesRelaunch() throws {
        let suite = "test.relaunch.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite nil")
            return
        }
        var store = SettingsStore(userDefaults: userDefaults)
        store.openaiModel = "gpt-4.1"
        store.booksAPIURL = "https://example.com/a"
        store.save()
        store = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(store.openaiModel, "gpt-4.1")
        XCTAssertEqual(store.booksAPIURL, "https://example.com/a")
    }

    func testDescriptorValidationBlocksEmptyURL() {
        let desc = SettingsViewModel.descriptor(for: "BOOKS_API_URL")
        XCTAssertNotNil(desc.validate(""))
        XCTAssertNil(desc.validate("https://example.com"))
    }

    func testDescriptorAllowsVerbatimBadHeaders() {
        let desc = SettingsViewModel.descriptor(for: "AI_CUSTOM_HEADERS")
        XCTAssertNotNil(desc.validate("{bad}"))
        XCTAssertEqual(desc.allowsVerbatimSave, true)
    }

    /// feat-023 Phase 3: one shared trim rule — validate agrees with setValue/intValue.
    /// Double-path intent pinned (round 1): "20.9"→20, "1e3"→1000, "+20"→20; nan/inf blocked.
    func testPrefetchTrimRuleUnified() {
        let desc = SettingsViewModel.descriptor(for: "PREFETCH_COUNT")
        XCTAssertNil(desc.validate("20"))
        XCTAssertNil(desc.validate(" 20"))
        XCTAssertNil(desc.validate("20 "))
        XCTAssertNil(desc.validate("20.0"))
        XCTAssertNil(desc.validate("20.9"))
        XCTAssertNil(desc.validate("1e3"))
        XCTAssertNil(desc.validate("+20"))
        XCTAssertNotNil(desc.validate("nan"))
        XCTAssertNotNil(desc.validate("inf"))
    }

    /// feat-023 Phase 3: editor blocks (keeps old value); copy must say so, not promise fallback-to-3.
    /// Round 1 (C3): the visible description tells the same truth as the error message.
    func testPrefetchCopyStatesBlockKeepsOld() {
        let desc = SettingsViewModel.descriptor(for: "PREFETCH_COUNT")
        let blocked = desc.validate("1001")
        XCTAssertNotNil(blocked)
        XCTAssertTrue(blocked?.contains("giữ giá trị cũ") ?? false)
        XCTAssertFalse(blocked?.contains("về 3") ?? true)
        XCTAssertNotNil(desc.validate("abc"))
        XCTAssertNotNil(desc.validate("-1"))
        XCTAssertFalse(desc.allowsVerbatimSave)
        XCTAssertTrue(desc.description.contains("giữ giá trị cũ"))
        XCTAssertFalse(desc.description.contains("về 3"))
    }

    /// feat-023 Phase 3: Settings row exposes the effective N the manager consumes.
    func testPrefetchRowExposesEffectiveN() {
        let suite = "test.prefetchrow.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite nil")
            return
        }
        let store = SettingsStore(userDefaults: userDefaults)
        store.prefetchCount = 20
        XCTAssertEqual(SettingsViewModel.prefetchCountRowValue(store), "20")
        // Stored out-of-range but unsaved: row still shows the effective value.
        store.prefetchCount = 1001
        XCTAssertEqual(store.prefetchCount, 1001)
        XCTAssertEqual(SettingsViewModel.prefetchCountRowValue(store), "3")
    }
}
