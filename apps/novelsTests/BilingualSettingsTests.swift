import Foundation
@testable import novels
import XCTest

@MainActor
final class BilingualSettingsTests: XCTestCase {
    // MARK: - AIMode

    func testAIModeCasesAndTitles() {
        XCTAssertEqual(AIMode.allCases, [.none, .rewrite, .bilingual])
        XCTAssertEqual(AIMode.none.rawValue, "none")
        XCTAssertEqual(AIMode.rewrite.rawValue, "rewrite")
        XCTAssertEqual(AIMode.bilingual.rawValue, "bilingual")

        XCTAssertEqual(AIMode.none.title, "Bản gốc")
        XCTAssertEqual(AIMode.rewrite.title, "Dịch")
        XCTAssertEqual(AIMode.bilingual.title, "Song ngữ")
    }

    func testAIModeCodableRoundTrip() throws {
        for mode in AIMode.allCases {
            let encoded = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AIMode.self, from: encoded)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - DefaultsKeys & SettingsDefaults

    func testDefaultsKeysIncludesBilingualPrompt() {
        XCTAssertEqual(DefaultsKeys.aiBilingualPrompt, "AI_BILINGUAL_PROMPT")
        XCTAssertTrue(DefaultsKeys.allCurrent.contains(DefaultsKeys.aiBilingualPrompt))
    }

    func testDefaultBilingualPromptContent() {
        let prompt = SettingsDefaults.defaultBilingualPrompt
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("tiếng Việt"))
        XCTAssertTrue(prompt.contains("tiếng Anh"))
        XCTAssertNotEqual(SettingsDefaults.defaultPrompt, SettingsDefaults.defaultBilingualPrompt)
    }

    // MARK: - SettingsStore Persistence & Independence

    func testStoreInitializesWithDefaults() {
        withDefaults { defaults in
            let store = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(store.aiPrompt, SettingsDefaults.defaultPrompt)
            XCTAssertEqual(store.aiBilingualPrompt, SettingsDefaults.defaultBilingualPrompt)
            XCTAssertEqual(store.aiMode, .none)
        }
    }

    func testEnglishPrimaryPreferencePersistsWithoutChangingModeOrTypography() {
        withDefaults { defaults in
            let store = SettingsStore(userDefaults: defaults)
            XCTAssertFalse(store.bilingualEnglishPrimary)
            XCTAssertTrue(DefaultsKeys.allCurrent.contains(DefaultsKeys.bilingualEnglishPrimary))
            let typography = store.typography
            store.aiMode = .bilingual
            store.bilingualEnglishPrimary.toggle()
            store.save()

            let restored = SettingsStore(userDefaults: defaults)
            XCTAssertTrue(restored.bilingualEnglishPrimary)
            XCTAssertEqual(restored.aiMode, .bilingual)
            XCTAssertEqual(restored.typography.font, typography.font)
            XCTAssertEqual(restored.typography.fontSize, typography.fontSize)
            XCTAssertEqual(restored.typography.lineHeight, typography.lineHeight)

            restored.aiMode = .none
            restored.save()
            let originalMode = SettingsStore(userDefaults: defaults)
            XCTAssertTrue(originalMode.bilingualEnglishPrimary)
            originalMode.bilingualEnglishPrimary.toggle()
            originalMode.save()
            XCTAssertFalse(SettingsStore(userDefaults: defaults).bilingualEnglishPrimary)
        }
    }

    func testPromptsPersistAndRemainIndependent() {
        withDefaults { defaults in
            let store = SettingsStore(userDefaults: defaults)
            store.setValue("Custom rewrite prompt", forKey: "AI_PROMPT")
            store.setValue("Custom bilingual prompt", forKey: "AI_BILINGUAL_PROMPT")
            store.save()

            XCTAssertEqual(store.value(forKey: "AI_PROMPT"), "Custom rewrite prompt")
            XCTAssertEqual(store.value(forKey: "AI_BILINGUAL_PROMPT"), "Custom bilingual prompt")

            let restored = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(restored.aiPrompt, "Custom rewrite prompt")
            XCTAssertEqual(restored.aiBilingualPrompt, "Custom bilingual prompt")

            // Mutating one does not affect the other
            restored.aiPrompt = "Updated rewrite only"
            XCTAssertEqual(restored.aiBilingualPrompt, "Custom bilingual prompt")
            restored.save()

            let reload2 = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(reload2.aiPrompt, "Updated rewrite only")
            XCTAssertEqual(reload2.aiBilingualPrompt, "Custom bilingual prompt")
        }
    }

    func testEmptyPromptsSanitizeToRespectiveDefaultsOnly() {
        withDefaults { defaults in
            let store = SettingsStore(userDefaults: defaults)
            store.aiPrompt = "Custom rewrite"
            store.aiBilingualPrompt = "   \n\t  "
            store.save()

            // aiBilingualPrompt falls back to its own default without affecting aiPrompt
            XCTAssertEqual(store.aiBilingualPrompt, SettingsDefaults.defaultBilingualPrompt)
            XCTAssertEqual(store.aiPrompt, "Custom rewrite")

            store.aiPrompt = "  "
            store.aiBilingualPrompt = "Custom bilingual"
            store.save()

            // aiPrompt falls back to its own default without affecting aiBilingualPrompt
            XCTAssertEqual(store.aiPrompt, SettingsDefaults.defaultPrompt)
            XCTAssertEqual(store.aiBilingualPrompt, "Custom bilingual")
        }
    }

    func testLegacySettingsCompatibilityAndModeRestoration() {
        withDefaults { defaults in
            // Simulate legacy storage containing only older keys
            defaults.set("Legacy rewrite prompt", forKey: DefaultsKeys.aiPrompt)
            defaults.set("rewrite", forKey: DefaultsKeys.aiMode)

            let store = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(store.aiPrompt, "Legacy rewrite prompt")
            XCTAssertEqual(store.aiMode, .rewrite)
            // Bilingual prompt cleanly defaults without breaking legacy values
            XCTAssertEqual(store.aiBilingualPrompt, SettingsDefaults.defaultBilingualPrompt)

            // Test bilingual mode restoration
            store.aiMode = .bilingual
            store.save()

            let restored = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(restored.aiMode, .bilingual)

            // Unknown rawValue coerces to .none
            defaults.set("unknown_mode", forKey: DefaultsKeys.aiMode)
            let coerced = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(coerced.aiMode, .none)
        }
    }

    // MARK: - AIPromptBuilder

    func testDefaultPromptForAllModes() {
        XCTAssertEqual(AIPromptBuilder.defaultPrompt(for: .none), "")
        XCTAssertEqual(AIPromptBuilder.defaultPrompt(for: .rewrite), SettingsDefaults.defaultPrompt)
        XCTAssertEqual(AIPromptBuilder.defaultPrompt(for: .bilingual), SettingsDefaults.defaultBilingualPrompt)
    }

    func testPromptBuilderForNoneAndRewrite() {
        XCTAssertEqual(AIPromptBuilder.prompt(for: .none, customPrompt: "xyz"), "")
        XCTAssertEqual(AIPromptBuilder.prompt(for: .none, customPrompt: "xyz", bilingualPrompt: "abc"), "")

        // Old caller signature preserving custom prompt
        XCTAssertEqual(AIPromptBuilder.prompt(for: .rewrite, customPrompt: "Custom rewrite"), "Custom rewrite")
        // Whitespace fallback to defaultPrompt
        XCTAssertEqual(AIPromptBuilder.prompt(for: .rewrite, customPrompt: "   "), SettingsDefaults.defaultPrompt)
        // Ignores bilingualPrompt when in rewrite mode
        XCTAssertEqual(
            AIPromptBuilder.prompt(for: .rewrite, customPrompt: "Custom", bilingualPrompt: "BiPrompt"),
            "Custom"
        )
    }

    func testPromptBuilderForBilingualAppendsProtocol() {
        let result = AIPromptBuilder.prompt(
            for: .bilingual,
            customPrompt: "RewritePrompt",
            bilingualPrompt: "CustomBilingual"
        )

        XCTAssertTrue(result.hasPrefix("CustomBilingual\n\n"))
        XCTAssertFalse(result.contains("RewritePrompt"))
        XCTAssertTrue(result.contains(AIPromptBuilder.bilingualProtocol))

        // Noneditable protocol contains required instructions
        let proto = AIPromptBuilder.bilingualProtocol
        XCTAssertTrue(proto.contains("JSON"))
        XCTAssertTrue(proto.contains("id"))
        XCTAssertTrue(proto.contains("vi"))
        XCTAssertTrue(proto.contains("en"))

        // Whitespace fallback to defaultBilingualPrompt
        let fallbackResult = AIPromptBuilder.prompt(
            for: .bilingual,
            customPrompt: "RewritePrompt",
            bilingualPrompt: "   "
        )
        XCTAssertTrue(fallbackResult.hasPrefix("\(SettingsDefaults.defaultBilingualPrompt)\n\n"))
    }

    // MARK: - SettingsViewModel & Descriptor Metadata

    func testBilingualPromptDescriptorAndValidation() {
        let desc = SettingsViewModel.descriptor(for: DefaultsKeys.aiBilingualPrompt)
        XCTAssertEqual(desc.key, DefaultsKeys.aiBilingualPrompt)
        XCTAssertEqual(desc.label, "Hướng dẫn dịch song ngữ (Prompt)")
        XCTAssertEqual(desc.defaultValue, SettingsDefaults.defaultBilingualPrompt)
        XCTAssertFalse(desc.allowsVerbatimSave)

        // Validation warns on empty string
        XCTAssertNotNil(desc.validate(""))
        XCTAssertNotNil(desc.validate("   \n\t"))
        XCTAssertNil(desc.validate("Valid custom bilingual prompt"))
    }

    func testBilingualPromptPlaceholderMatchesResponseContract() throws {
        let descriptor = SettingsViewModel.descriptor(for: DefaultsKeys.aiBilingualPrompt)
        let example = try XCTUnwrap(descriptor.placeholder.split(separator: "\n").first { $0.hasPrefix("{") })
        let paragraphs = try BilingualChapter.decodeResponse(String(example), expectedIDs: ["p001"])
        XCTAssertEqual(paragraphs.count, 1)
        XCTAssertFalse(paragraphs[0].vi.isEmpty)
        XCTAssertFalse(paragraphs[0].en.isEmpty)
        XCTAssertTrue(descriptor.placeholder.contains("Không trả về các đoạn văn Việt - Anh xen kẽ ngoài JSON"))
        XCTAssertTrue(descriptor.description.contains("App tự động thêm quy tắc JSON"))
    }

    // MARK: - Helpers

    private func withDefaults(_ check: (UserDefaults) -> Void) {
        let name = "BilingualSettingsTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            return XCTFail("Cannot create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: name) }
        check(defaults)
    }
}
