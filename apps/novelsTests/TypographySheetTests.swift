@testable import novels
import XCTest

@MainActor
final class TypographySheetTests: XCTestCase {
    func testTypographyStepperPersists() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.typography.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.fontSize = 20
        store.save()
        let reloaded = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.typography.fontSize, 20)
        store.typography.fontSize = 99
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.fontSize, 16)
        store.typography.lineHeight = 1.8
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.lineHeight, 1.8)
        store.typography.lineHeight = 99
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.lineHeight, 1.5)
        store.typography.letterSpacing = 0.5
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.letterSpacing, 0.5)
        store.typography.letterSpacing = 99
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.letterSpacing, 0)
    }

    func testTypographyFontPersists() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.typography.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.font = "Serif"
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.font, "Serif")
        store.typography.font = "Mono"
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.font, "Mono")
    }

    func testClampBoundsSanitize() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.typography.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        store.typography.fontSize = 12
        store.typography.lineHeight = 1.2
        store.typography.letterSpacing = 0
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.fontSize, 12)
        store.typography.fontSize = 24
        store.typography.lineHeight = 2.0
        store.typography.letterSpacing = 1.0
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.fontSize, 24)
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.lineHeight, 2.0)
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.letterSpacing, 1.0)
        store.typography.fontSize = 11
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.fontSize, 16)
        store.typography.lineHeight = 1.1
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.lineHeight, 1.5)
        store.typography.letterSpacing = -0.1
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).typography.letterSpacing, 0)
    }
}
