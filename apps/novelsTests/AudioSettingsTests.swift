import Foundation
@testable import novels
import XCTest

@MainActor
final class AudioSettingsTests: XCTestCase {
    func testFreshDefaultsDoNotChangeExistingAIConfiguration() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("ai-secret", forKey: DefaultsKeys.aiAPIKey)
        defaults.set("ai-model", forKey: DefaultsKeys.openaiModel)
        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.audioSource, .apple)
        XCTAssertEqual(store.audioAPIKey, "")
        XCTAssertEqual(store.audioModel, AudioSource.defaultModel)
        XCTAssertEqual(store.aiAPIKey, "ai-secret")
        XCTAssertEqual(store.openaiModel, "ai-model")
        XCTAssertTrue(DefaultsKeys.allCurrent.contains(DefaultsKeys.audioSource))
        XCTAssertTrue(DefaultsKeys.allCurrent.contains(DefaultsKeys.audioAPIKey))
        XCTAssertTrue(DefaultsKeys.allCurrent.contains(DefaultsKeys.audioModel))
    }

    func testEditorValuesPersistAndAppleKeepsHiddenAPICredentials() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(userDefaults: defaults)
        store.setValue(" API ", forKey: "AUDIO_SOURCE")
        store.setValue("audio-secret", forKey: "AUDIO_API_KEY")
        store.setValue(" edge-tts/custom \n", forKey: "AUDIO_MODEL")
        store.save()
        let restored = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(restored.value(forKey: "AUDIO_SOURCE"), "api")
        XCTAssertEqual(restored.value(forKey: "AUDIO_API_KEY"), "audio-secret")
        XCTAssertEqual(restored.value(forKey: "AUDIO_MODEL"), "edge-tts/custom")
        restored.setValue("apple", forKey: "AUDIO_SOURCE")
        restored.save()
        let apple = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(apple.audioSource, .apple)
        XCTAssertEqual(apple.audioAPIKey, "audio-secret")
        XCTAssertEqual(apple.audioModel, "edge-tts/custom")
        XCTAssertEqual(apple.aiAPIKey, "")
    }

    func testInvalidSourceAndBlankModelRestoreTheirDefaults() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unknown", forKey: DefaultsKeys.audioSource)
        defaults.set(" \n ", forKey: DefaultsKeys.audioModel)
        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.audioSource, .apple)
        XCTAssertEqual(store.audioModel, AudioSource.defaultModel)
        defaults.set(" API \n", forKey: DefaultsKeys.audioSource)
        XCTAssertEqual(SettingsStore(userDefaults: defaults).audioSource, .api)
        store.audioModel = ""
        store.save()
        XCTAssertEqual(defaults.string(forKey: DefaultsKeys.audioModel), AudioSource.defaultModel)
    }

    func testDescriptorsValidateAndRowsNeverExposeAudioKey() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(userDefaults: defaults)
        let source = SettingsViewModel.descriptor(for: "AUDIO_SOURCE")
        XCTAssertNil(source.validate(" APPLE "))
        XCTAssertNil(source.validate("api"))
        XCTAssertNotNil(source.validate("unknown"))
        let model = SettingsViewModel.descriptor(for: "AUDIO_MODEL")
        XCTAssertEqual(model.defaultValue, AudioSource.defaultModel)
        XCTAssertNotNil(model.validate(" \n "))
        XCTAssertNil(model.validate("edge-tts/custom"))
        let key = SettingsViewModel.descriptor(for: "AUDIO_API_KEY")
        XCTAssertNil(key.validate(""))
        XCTAssertNil(key.validate(" key \n"))
        XCTAssertNotNil(key.validate("key\r\ninjected"))
        XCTAssertEqual(SettingsViewModel.apiKeyRowValue(store, key: "AUDIO_API_KEY"), "Chưa thiết lập")
        store.audioAPIKey = "audio-secret"
        XCTAssertEqual(SettingsViewModel.apiKeyRowValue(store, key: "AUDIO_API_KEY"), "Đã thiết lập")
        XCTAssertEqual(SettingsViewModel.apiKeyRowValue(store), "Chưa thiết lập")
        store.aiAPIKey = "ai-secret"
        XCTAssertEqual(SettingsViewModel.apiKeyRowValue(store), "Đã thiết lập")
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "AudioSettingsTests-\(UUID().uuidString)"
        return try (XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }
}
