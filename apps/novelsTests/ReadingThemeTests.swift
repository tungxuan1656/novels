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
        XCTAssertTrue(code.contains("0xE8DDC0"))
        XCTAssertTrue(code.contains("0xDCD2B6"))
        XCTAssertTrue(code.contains("0xEFEFF1"))
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
}
