import Foundation
@testable import novels
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class AIProviderSettingsTests: XCTestCase {
    func testAutoRecognizesProvidersThroughProxyModelNames() {
        let fixtures: [(String, AIProvider)] = [
            ("gpt-4o", .openai), ("o3-mini", .openai), ("claude-new", .anthropic),
            ("opencode-go/muse-spark-1.3", .muse), ("deepseek-v4.1-flash", .deepseek),
            ("mimo-v2.6-flash", .mimo), ("glm-5.3-flash", .glm), ("MiniMax-M3", .minimax),
            ("kimi-k3", .kimi), ("moonshot-v1", .kimi), ("gemini/gemini-3.8-flash", .gemini),
        ]
        for (model, expected) in fixtures {
            XCTAssertEqual(
                AIProvider.auto.resolved(model: model, urlString: "http://localhost:8317/v1/chat/completions"),
                expected,
                model
            )
        }
    }

    func testManualSelectionAndModelIdentityPrecedeHost() {
        XCTAssertEqual(
            AIProvider.kimi.resolved(model: "gpt-4o", urlString: "https://api.anthropic.com/v1/messages"),
            .kimi
        )
        XCTAssertEqual(
            AIProvider.auto.resolved(model: "muse-spark", urlString: "https://api.openai.com/v1/responses"),
            .muse
        )
    }

    func testAutoUsesProviderHostForUnknownAliasesAndRejectsLookalikes() {
        let fixtures: [(String, AIProvider)] = [
            ("api.anthropic.com", .anthropic), ("api.meta.ai", .muse), ("api.deepseek.com", .deepseek),
            ("api.xiaomimimo.com", .mimo), ("api.z.ai", .glm), ("open.bigmodel.cn", .glm),
            ("api.minimax.io", .minimax), ("api.minimaxi.com", .minimax), ("api.moonshot.ai", .kimi),
            ("api.moonshot.cn", .kimi), ("api.kimi.ai", .kimi), ("generativelanguage.googleapis.com", .gemini),
        ]
        for (host, provider) in fixtures {
            XCTAssertEqual(
                AIProvider.auto.resolved(model: "alias", urlString: "https://\(host)/v1/chat/completions"),
                provider
            )
        }
        for host in ["anthropic.com.invalid", "notanthropic.com", "localhost", "opencode.ai"] {
            XCTAssertEqual(AIProvider.auto.resolved(model: "alias", urlString: "https://\(host)/v1/messages"), .openai)
        }
    }

    func testExistingSettingsSurviveAndNewControlsStayUnset() {
        withDefaults { defaults in
            defaults.set("openai", forKey: DefaultsKeys.aiProvider)
            defaults.set("http://localhost:8317/v1/responses", forKey: DefaultsKeys.openaiAPIURL)
            defaults.set("proxy-alias", forKey: DefaultsKeys.openaiModel)
            defaults.set("{\"Authorization\":\"Bearer fixture\"}", forKey: DefaultsKeys.aiCustomHeadersJSON)
            defaults.set("{\"reasoning\":{\"effort\":\"high\"}}", forKey: DefaultsKeys.aiExtraBodyJSON)
            let store = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(store.aiProvider, "openai")
            XCTAssertEqual(store.openaiAPIURL, "http://localhost:8317/v1/responses")
            XCTAssertEqual(store.openaiModel, "proxy-alias")
            XCTAssertEqual(store.aiCustomHeadersJSON, defaults.string(forKey: DefaultsKeys.aiCustomHeadersJSON))
            XCTAssertEqual(store.aiExtraBodyJSON, defaults.string(forKey: DefaultsKeys.aiExtraBodyJSON))
            XCTAssertEqual(store.aiAPIKey, "")
            XCTAssertEqual(store.aiThinkingEffort, "")
        }
    }

    func testNewSettingsRoundTripSanitizeAndMaskCredential() {
        withDefaults { defaults in
            let store = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(store.aiProvider, "auto")
            store.setValue(" GEMINI ", forKey: "AI_PROVIDER")
            store.setValue(" NONE ", forKey: "AI_THINKING_EFFORT")
            store.setValue("fixture-private-key", forKey: "AI_API_KEY")
            store.save()
            let restored = SettingsStore(userDefaults: defaults)
            XCTAssertEqual(restored.value(forKey: "AI_PROVIDER"), "gemini")
            XCTAssertEqual(restored.value(forKey: "AI_THINKING_EFFORT"), "none")
            XCTAssertEqual(restored.value(forKey: "AI_API_KEY"), "fixture-private-key")
            XCTAssertEqual(SettingsViewModel.apiKeyRowValue(restored), "Đã thiết lập")
            XCTAssertFalse(SettingsViewModel.apiKeyRowValue(restored).contains("fixture-private-key"))
            restored.aiProvider = "unknown"
            restored.aiThinkingEffort = "xhigh"
            restored.save()
            XCTAssertEqual(restored.aiProvider, "auto")
            XCTAssertEqual(restored.aiThinkingEffort, "")
            restored.aiProvider = "auto"
            restored.openaiModel = "muse-spark"
            XCTAssertEqual(SettingsViewModel.providerRowValue(restored), "Tự động: Muse Spark")
        }
    }

    func testEditorAcceptsOnlyKnownSelectionsAndAllowsEmptyKey() {
        XCTAssertNil(SettingsViewModel.descriptor(for: "AI_API_KEY").validate(""))
        XCTAssertNil(SettingsViewModel.descriptor(for: "AI_PROVIDER").validate(" MIMO "))
        XCTAssertNotNil(SettingsViewModel.descriptor(for: "AI_PROVIDER").validate("unknown"))
        let thinking = SettingsViewModel.descriptor(for: "AI_THINKING_EFFORT")
        for value in ["", "none", "low", "medium", "high"] {
            XCTAssertNil(thinking.validate(value))
        }
        XCTAssertNotNil(thinking.validate("max"))
        XCTAssertEqual(SettingsViewModel.descriptor(for: "OPENAI_API_URL").label, "URL AI")
    }

    private func withDefaults(_ check: (UserDefaults) -> Void) {
        let name = "AIProviderSettingsTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else { return XCTFail("Cannot create isolated defaults") }
        defer { defaults.removePersistentDomain(forName: name) }
        check(defaults)
    }
}

// swiftlint:enable trailing_comma
