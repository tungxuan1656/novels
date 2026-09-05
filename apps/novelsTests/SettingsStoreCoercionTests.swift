@testable import novels
import XCTest

@MainActor
final class SettingsStoreCoercionTests: XCTestCase {
    func testAiMinChunkSizeCoercionViaSaveAndReload() throws {
        let suite = "test.chunk.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.aiMinChunkSize = 0
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiMinChunkSize, 1300)
        store.aiMinChunkSize = 15000
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiMinChunkSize, 1300)
        store.aiMinChunkSize = 9999
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiMinChunkSize, 9999)
        store.aiMinChunkSize = 2000
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiMinChunkSize, 2000)
        let stored = userDefaults.object(forKey: "AI_MIN_CHUNK_SIZE")
        if let intVal = stored as? Int {
            XCTAssertEqual(intVal, 2000)
        } else if let strVal = stored as? String {
            XCTAssertEqual(strVal, "2000")
        } else {
            XCTFail("stored AI_MIN_CHUNK_SIZE not found")
        }
    }

    func testEffectiveExtraBodyEmptyAndValid() throws {
        let suite = "test.extraBody.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.aiExtraBodyJSON = "not json"
        store.save()
        XCTAssertTrue(store.effectiveExtraBody().isEmpty)
        // Stored verbatim but effective empty
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiExtraBodyJSON, "not json")
        XCTAssertTrue(SettingsStore(userDefaults: userDefaults).effectiveExtraBody().isEmpty)
        store.aiExtraBodyJSON = "{\"temperature\":0.7}"
        store.save()
        let body = store.effectiveExtraBody()
        if let doubleVal = body["temperature"] as? Double {
            XCTAssertEqual(doubleVal, 0.7, accuracy: 0.001)
        } else if let numVal = body["temperature"] as? NSNumber {
            XCTAssertEqual(numVal.doubleValue, 0.7, accuracy: 0.001)
        } else {
            XCTFail("temperature not parsed as Double")
        }
    }

    func testAIPromptSanitizeAndDescriptor() throws {
        let suite = "test.prompt.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let descriptor = SettingsViewModel.descriptor(for: "AI_PROMPT")
        XCTAssertNotNil(descriptor.validate(""))
        XCTAssertEqual(descriptor.validate(""), "Rỗng sẽ về mặc định, dùng Xóa để khôi phục")
        let store = SettingsStore(userDefaults: userDefaults)
        store.aiPrompt = "   "
        store.save()
        XCTAssertEqual(
            SettingsStore(userDefaults: userDefaults).aiPrompt,
            SettingsDefaults.defaultPrompt
        )
        let valid = "Custom prompt text"
        store.aiPrompt = valid
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiPrompt, valid)
    }

    func testUnknownLegacyKeyIgnored() throws {
        let suite = "test.unknown.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        userDefaults.set("secret", forKey: "COPILOT_API_KEY")
        userDefaults.set("legacy", forKey: "UNKNOWN_KEY")
        // Init must not crash and known keys remain defaults
        let store = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(store.openaiModel, "gpt-4o")
        XCTAssertEqual(store.prefetchCount, 3)
        XCTAssertEqual(store.aiMinChunkSize, 1300)
        // Unknown keys remain in UserDefaults but not reflected in store
        XCTAssertEqual(userDefaults.string(forKey: "COPILOT_API_KEY"), "secret")
        XCTAssertEqual(userDefaults.string(forKey: "UNKNOWN_KEY"), "legacy")
        XCTAssertEqual(userDefaults.string(forKey: "COPILOT_API_KEY"), "secret")
        // Ensure store value for unknown key is empty via value(forKey:)
        XCTAssertEqual(store.value(forKey: "UNKNOWN_KEY"), "")
        XCTAssertEqual(store.value(forKey: "COPILOT_API_KEY"), "")
    }

    func testSetValueKeepsPriorOnParseFailurePrefetch() throws {
        let suite = "test.setvalue.prefetch.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.prefetchCount = 5
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 5)
        // keep prior valid value on parse failure
        store.setValue("abc", forKey: "PREFETCH_COUNT")
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 5)
        XCTAssertEqual(store.prefetchCount, 5)
    }

    func testSetValueKeepsPriorOnParseFailureFontSize() throws {
        let suite = "test.setvalue.fontsize.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.fontSize = 18
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.fontSize, 18)
        // keep prior valid value on parse failure
        store.setValue("abc", forKey: "fontSize")
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.fontSize, 18)
    }

    func testFontEmptyStringBlockAndDisplayFormatting() throws {
        let descriptor = SettingsViewModel.descriptor(for: "font")
        XCTAssertNotNil(descriptor.validate(""))
        let suite = "test.font.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.font = ""
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.font, "System")
        store.typography.fontSize = 20.0
        XCTAssertEqual(store.value(forKey: "fontSize"), "20")
        XCTAssertNotEqual(store.value(forKey: "fontSize"), "20.0")
        store.typography.lineHeight = 5
        XCTAssertEqual(store.value(forKey: "lineHeight"), "5.0")
        store.typography.letterSpacing = 0
        XCTAssertEqual(store.value(forKey: "letterSpacing"), "0.0")
        store.typography.fontSize = 16
        XCTAssertEqual(store.value(forKey: "fontSize"), "16")
    }

    func testInvalidHeadersIgnoredInMerge() throws {
        let suite = "test.cacheheaders.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.aiCustomHeadersJSON = "not json"
        store.save()
        XCTAssertTrue(store.effectiveHeaders().isEmpty)
        // Stored verbatim but effective empty
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).aiCustomHeadersJSON, "not json")
        store.aiCustomHeadersJSON = "{\"Authorization\":\"Bearer x\"}"
        store.save()
        XCTAssertEqual(store.effectiveHeaders()["Authorization"], "Bearer x")
    }

    /// feat-023 Phase 3: setValue shares the trim rule with validate/intValue.
    /// Double-path intent pinned (round 1): "20.9"→20, "1e3"→1000, "+20"→20; nan/inf keep prior.
    func testSetValuePrefetchTrimsAndAcceptsDoubleForm() throws {
        let suite = "test.setvalue.trim.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = SettingsStore(userDefaults: userDefaults)
        store.prefetchCount = 3
        store.setValue(" 20", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
        store.setValue("20 ", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
        store.setValue("20.0", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
        store.setValue("20.9", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
        store.setValue("1e3", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 1000)
        store.setValue("+20", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
        store.setValue("nan", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
        store.setValue("inf", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(store.prefetchCount, 20)
    }

    /// feat-023 Phase 3: persisted string forms reload identically (intValue path).
    func testIntValuePrefetchLenientFormsReload() throws {
        let suite = "test.intvalue.trim.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        userDefaults.set(" 20", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 20)
        userDefaults.set("20.0", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 20)
        userDefaults.set("20 ", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 20)
        // Non-finite strings parse to nothing → default stands (round 1, I7).
        userDefaults.set("nan", forKey: "PREFETCH_COUNT")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).prefetchCount, 3)
    }
}
