@testable import novels
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

    func testDefaultIsVangGiay() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(store.readingTheme, .vangGiay)
        XCTAssertEqual(store.readingTheme.title, "Vàng giấy")
        XCTAssertEqual(ReadingTheme.trang.title, "Trắng")
        XCTAssertEqual(ReadingTheme.den.title, "Đen")
    }

    func testRoundTripPersists() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: userDefaults)
        store.readingTheme = .den
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .den)
        store.readingTheme = .trang
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .trang)
        store.readingTheme = .vangGiay
        store.save()
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .vangGiay)
    }

    func testUnknownFallbackToVangGiay() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.readingTheme.\(UUID().uuidString)"))
        userDefaults.set("sepia-weird", forKey: "readingTheme")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .vangGiay)
        userDefaults.set(123, forKey: "readingTheme")
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).readingTheme, .vangGiay)
    }

    func testSchemeAndDisabledOpacityContract() {
        XCTAssertEqual(ReadingTheme.vangGiay.preferredColorScheme, .light)
        XCTAssertEqual(ReadingTheme.trang.preferredColorScheme, .light)
        XCTAssertEqual(ReadingTheme.den.preferredColorScheme, .dark)
        XCTAssertFalse(ReadingTheme.vangGiay.isDark)
        XCTAssertFalse(ReadingTheme.trang.isDark)
        XCTAssertTrue(ReadingTheme.den.isDark)
        XCTAssertEqual(ReadingTheme.vangGiay.disabledIconOpacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(ReadingTheme.trang.disabledIconOpacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(ReadingTheme.den.disabledIconOpacity, 0.42, accuracy: 0.001)
    }

    func testApprovedHexPreserved() throws {
        let src = try source("apps/novels/Resources/DesignTokens.swift")
        let code = stripped(src)
        XCTAssertTrue(code.contains("0xF5F1E5"))
        // Light chips darkened for contrast (round 1: EFEFF1→E0E1E6; round 2: E0E1E6→D3D4D9, E8DDC0→D9CBA6).
        // Default theme is vangGiay, so its chip must change too or light users see nothing.
        XCTAssertTrue(code.contains("0xD9CBA6"))
        XCTAssertFalse(code.contains("0xE8DDC0"))
        XCTAssertTrue(code.contains("0xDCD2B6"))
        XCTAssertTrue(code.contains("0xD3D4D9"))
        XCTAssertFalse(code.contains("0xEFEFF1"))
        XCTAssertFalse(code.contains("0xE0E1E6"))
        XCTAssertTrue(code.contains("0xE5E7EB"))
        XCTAssertTrue(code.contains("0x171512"))
        XCTAssertTrue(code.contains("0xECE7DF"))
        XCTAssertTrue(code.contains("0xA8A29E"))
        XCTAssertTrue(code.contains("0x2A2724"))
        XCTAssertTrue(code.contains("0x3B3732"))
        XCTAssertTrue(code.contains("0x60A5FA"))
        XCTAssertTrue(code.contains("0x2563EB"))
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
        let themeSrc = try stripped(source("apps/novels/Domain/ReadingTheme.swift"))
        XCTAssertTrue(themeSrc.contains("Vàng giấy"))
        XCTAssertTrue(themeSrc.contains("Trắng"))
        XCTAssertTrue(themeSrc.contains("\"Đen\"") || themeSrc.contains("return \"Đen\""))
    }

    func testLightChipDiffersFromWhiteBackground() throws {
        let src = try stripped(source("apps/novels/Resources/DesignTokens.swift"))
        // Chip trang must not equal white background FFFFFF (wash-out regression)
        XCTAssertTrue(src.contains("0xD3D4D9"))
        XCTAssertFalse(src.contains("0xEFEFF1"))
        XCTAssertFalse(src.contains("0xE0E1E6"))
        // Default theme is vangGiay: its chip must also stand off paper F5F1E5
        XCTAssertTrue(src.contains("0xD9CBA6"))
        XCTAssertFalse(src.contains("0xE8DDC0"))
        // Dark chip stays untouched
        XCTAssertTrue(src.contains("0x2A2724"))
    }

    func testStepperValueWidthFitsDynamicType() throws {
        let sheet = try stripped(source("apps/novels/Features/Reading/ReaderBottomSheet.swift"))
        XCTAssertFalse(sheet.contains("frame(width: 32"))
        XCTAssertTrue(sheet.contains("minWidth: 48"))
        XCTAssertTrue(sheet.contains("fixedSize(horizontal: true"))
        XCTAssertTrue(sheet.contains("lineLimit(1)"))
    }

    func testCachePillsHaveReadableFill() throws {
        let src = try stripped(source("apps/novels/Features/Settings/CacheManagerView.swift"))
        XCTAssertTrue(src.contains("muted.opacity(0.2)"))
        XCTAssertFalse(src.contains("muted.opacity(0.12)"))
        // Xóa pill: fill >= 0.2 + stroke 0.5 so edge survives on white surface
        XCTAssertTrue(src.contains("error.opacity(0.2)"))
        XCTAssertTrue(src.contains("error.opacity(0.5)"))
        // Exact-match with closing paren: 0.12 icon tint at line 114 stays
        XCTAssertFalse(src.contains("error.opacity(0.1)"))
        XCTAssertFalse(src.contains("error.opacity(0.15)"))
        XCTAssertFalse(src.contains("error.opacity(0.25)"))
        XCTAssertFalse(src.contains("error.opacity(0.35)"))
    }

    func testReaderChipsUseSolidFill() throws {
        let reader = try stripped(source("apps/novels/Features/Reading/ReaderView.swift"))
        XCTAssertFalse(reader.contains("chipBackground.opacity(0.7)"))
        XCTAssertTrue(reader.contains("theme.chipBackground"))
    }

    func testSettingsRowSeparatesFromBackground() throws {
        let src = try stripped(source("apps/novels/Resources/DesignTokens.swift"))
        // Settings rows (surface, white) must stand off the screen bg (backgroundWhite, grouped gray)
        XCTAssertTrue(src.contains("backgroundWhite = Color(uiColor: .adapted(lightHex: 0xF5F5F5"))
        XCTAssertTrue(src.contains("surface = Color(uiColor: .adapted(lightHex: 0xFFFFFF"))
        XCTAssertTrue(src.contains("backgroundWhite = Color(hex: 0xF5F5F5)"))
        XCTAssertTrue(src.contains("surface = Color(hex: 0xFFFFFF)"))
        // Dark stays differentiated
        XCTAssertTrue(src.contains("0x0F1419"))
        XCTAssertTrue(src.contains("0x171D23"))
    }
}
