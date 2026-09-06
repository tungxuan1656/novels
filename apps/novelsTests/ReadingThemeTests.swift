@testable import novels
import SwiftUI
import XCTest

@MainActor
final class ReadingThemeTests: XCTestCase {
    private func repoRoot() -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        var current = fileURL.deletingLastPathComponent()
        for _ in 0 ..< 6 {
            let candidate = current.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return fileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        let root = repoRoot()
        let candidate = root.appendingPathComponent(relative)
        let path = FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : relative
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    private func stripped(_ text: String) -> String {
        var result = text
        if let regex = try? NSRegularExpression(
            pattern: "/\\*.*?\\*/",
            options: [.dotMatchesLineSeparators]
        ) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        let lines = result.components(separatedBy: "\n")
        let withoutLineComments = lines.map { line -> String in
            if let range = line.range(of: "//") {
                return String(line[..<range.lowerBound])
            }
            return line
        }
        return withoutLineComments.joined(separator: "\n")
    }

    func testDefaultIsSach() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(store.readingTheme, .sach)
        XCTAssertEqual(store.readingTheme.title, "Sách")
        XCTAssertEqual(ReadingTheme.xanhDiu.title, "Xanh dịu")
        XCTAssertEqual(ReadingTheme.xanhLam.title, "Xanh lam")
        XCTAssertEqual(ReadingTheme.dem.title, "Đêm")
        XCTAssertEqual(ReadingTheme.amoled.title, "AMOLED")
        XCTAssertEqual(ReadingTheme.allCases.count, 5)
    }

    func testRoundTripPersists() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        for theme: ReadingTheme in [.sach, .xanhDiu, .xanhLam, .dem, .amoled] {
            store.readingTheme = theme
            store.save()
            XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, theme)
        }
    }

    func testUnknownFallbackToSach() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
        userDefaults.set("sepia-weird", forKey: "readingTheme")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .sach)
        userDefaults.set(123, forKey: "readingTheme")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .sach)
    }

    func testLegacyTrioFallbackToSach() throws {
        for legacy in ["vangGiay", "trang", "den"] {
            let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
            userDefaults.set(legacy, forKey: "readingTheme")
            XCTAssertEqual(
                SettingsStore(userDefaults: userDefaults).readingTheme,
                .sach,
                "legacy \(legacy) must coerce to sach"
            )
        }
    }

    func testSchemeAndDisabledOpacityContract() {
        XCTAssertEqual(ReadingTheme.sach.preferredColorScheme, .light)
        XCTAssertEqual(ReadingTheme.xanhDiu.preferredColorScheme, .light)
        XCTAssertEqual(ReadingTheme.xanhLam.preferredColorScheme, .light)
        XCTAssertEqual(ReadingTheme.dem.preferredColorScheme, .dark)
        XCTAssertEqual(ReadingTheme.amoled.preferredColorScheme, .dark)
        XCTAssertFalse(ReadingTheme.sach.isDark)
        XCTAssertFalse(ReadingTheme.xanhDiu.isDark)
        XCTAssertFalse(ReadingTheme.xanhLam.isDark)
        XCTAssertTrue(ReadingTheme.dem.isDark)
        XCTAssertTrue(ReadingTheme.amoled.isDark)
        XCTAssertEqual(ReadingTheme.sach.disabledIconOpacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(ReadingTheme.xanhDiu.disabledIconOpacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(ReadingTheme.xanhLam.disabledIconOpacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(ReadingTheme.dem.disabledIconOpacity, 0.42, accuracy: 0.001)
        XCTAssertEqual(ReadingTheme.amoled.disabledIconOpacity, 0.42, accuracy: 0.001)
    }

    func testApprovedHexPreserved() throws {
        let src = try source("apps/novels/Resources/DesignTokens.swift")
        let code = stripped(src)
        // Approved bg/text pairs (exact, feat-026).
        XCTAssertTrue(code.contains("0xF7F1E3"))
        XCTAssertTrue(code.contains("0x38342E"))
        XCTAssertTrue(code.contains("0xEEF3F0"))
        XCTAssertTrue(code.contains("0x29332F"))
        XCTAssertTrue(code.contains("0xEEF4F8"))
        XCTAssertTrue(code.contains("0x29343B"))
        XCTAssertTrue(code.contains("0x1C1C1E"))
        XCTAssertTrue(code.contains("0xD2D2D2"))
        XCTAssertTrue(code.contains("0x000000"))
        XCTAssertTrue(code.contains("0xC8C8C8"))
        // Derived AA palette.
        XCTAssertTrue(code.contains("0x655C4E"))
        XCTAssertTrue(code.contains("0x55645D"))
        XCTAssertTrue(code.contains("0x55636E"))
        XCTAssertTrue(code.contains("0xA8A8A8"))
        XCTAssertTrue(code.contains("0xA0A0A0"))
        XCTAssertTrue(code.contains("0xE7DEC7"))
        XCTAssertTrue(code.contains("0xDCE5DF"))
        XCTAssertTrue(code.contains("0xDCE6EE"))
        XCTAssertTrue(code.contains("0x2C2C2E"))
        XCTAssertTrue(code.contains("0xD8CCAC"))
        XCTAssertTrue(code.contains("0xC2CFC8"))
        XCTAssertTrue(code.contains("0xBFD0DC"))
        XCTAssertTrue(code.contains("0x3A3A3C"))
        XCTAssertTrue(code.contains("0x2E2E30"))
        XCTAssertTrue(code.contains("0x7AB8FF"))
        XCTAssertTrue(code.contains("0x2563EB"))
        // Retired trio reading hex must stay out of the reading palette.
        // Note: 0xF5F1E5 still lives in non-reading backgroundPaper (untouched), so no global assert on it.
        XCTAssertFalse(code.contains("0x171512"))
        XCTAssertFalse(code.contains("0xECE7DF"))
        XCTAssertFalse(code.contains("0xA8A29E"))
        XCTAssertFalse(code.contains("0x2A2724"))
        XCTAssertFalse(code.contains("0x3B3732"))
        XCTAssertFalse(code.contains("0x60A5FA"))
        XCTAssertFalse(code.contains("0xD3D4D9"))
        XCTAssertFalse(code.contains("0xE8DDC0"))
        XCTAssertFalse(code.contains("0xDCD2B6"))
        XCTAssertFalse(code.contains("0xEFEFF1"))
    }

    func testReaderUsesThemeTokens() throws {
        let reader = try stripped(source("apps/novels/Features/Reading/ReaderView.swift"))
        XCTAssertTrue(reader.contains("theme.background"))
        XCTAssertTrue(reader.contains("theme.headerBackground"))
        XCTAssertTrue(reader.contains("theme.textPrimary"))
        XCTAssertTrue(reader.contains("theme.iconTint"))
        XCTAssertTrue(reader.contains("theme.chipBackground"))
        XCTAssertTrue(reader.contains("theme.disabledIconOpacity"))
        XCTAssertTrue(reader.contains("preferredColorScheme(theme.preferredColorScheme)"))
        XCTAssertFalse(reader.contains("DesignTokens.backgroundPaper"))
        XCTAssertFalse(reader.contains("systemGray5"))
        let sheet = try stripped(source("apps/novels/Features/Reading/ReaderBottomSheet.swift"))
        XCTAssertTrue(sheet.contains("Màu nền"))
        XCTAssertTrue(sheet.contains("themePicker"))
        XCTAssertTrue(sheet.contains("theme-"))
        XCTAssertTrue(sheet.contains("option.title"))
        XCTAssertTrue(sheet.contains("option.rawValue"))
        XCTAssertTrue(sheet.contains("theme.borderColor"))
        XCTAssertTrue(sheet.contains("Chọn màu nền"))
        let themeSrc = try stripped(source("apps/novels/Domain/ReadingTheme.swift"))
        XCTAssertTrue(themeSrc.contains("Sách"))
        XCTAssertTrue(themeSrc.contains("Xanh dịu"))
        XCTAssertTrue(themeSrc.contains("Xanh lam"))
        XCTAssertTrue(themeSrc.contains("Đêm"))
        XCTAssertTrue(themeSrc.contains("AMOLED"))
        XCTAssertFalse(themeSrc.contains("vangGiay"))
        XCTAssertFalse(themeSrc.contains("Vàng giấy"))
    }
}
