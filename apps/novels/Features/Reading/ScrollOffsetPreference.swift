import Foundation
import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Pure helper for bottom overscroll detection — testable without UI
enum ReaderOverscrollLogic {
    static func isNearBottom(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        threshold: CGFloat = 40
    ) -> Bool {
        guard contentHeight > 0, viewportHeight > 0 else { return false }
        guard contentHeight > viewportHeight else { return false }
        return offsetY < -(contentHeight - viewportHeight - threshold)
    }

    static func isOverscrolledBeyondBottom(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        threshold: CGFloat = 40
    ) -> Bool {
        guard contentHeight > 0, viewportHeight > 0 else { return false }
        guard contentHeight > viewportHeight else { return false }
        return offsetY < -(contentHeight - viewportHeight + threshold)
    }
}

/// Helper for font design mapping — testable
enum ReaderFontDesign {
    static func design(for name: String) -> Font.Design {
        // swiftlint:disable switch_case_alignment
        switch name {
            case "Serif": return .serif
            case "Mono": return .monospaced
            default: return .default
        }
        // swiftlint:enable switch_case_alignment
    }
}

/// Helper for custom font mapping to PostScript names
enum ReaderFontMapper {
    // swiftlint:disable trailing_comma
    static let fonts = [
        "System",
        "Serif",
        "Mono",
        "Arial",
        "Be Vietnam Pro",
        "Georgia",
        "Google Sans",
        "Inter",
        "Lato",
        "Lora",
        "Merriweather",
        "Montserrat",
        "Montserrat Alternates",
        "Noto Sans",
        "Noto Serif",
        "Open Sans",
        "PT Sans",
        "PT Serif",
        "Raleway",
        "Roboto",
        "Space Mono",
        "Times New Roman",
        "Verdana",
        "Work Sans",
    ]
    // swiftlint:enable trailing_comma

    /// Normalize a stored/raw font value to its canonical display name.
    /// Trims whitespace, resolves spaceless aliases (e.g. "GoogleSans" -> "Google Sans")
    /// via case- and whitespace-insensitive match, falls back to "System" if invalid.
    static func normalizedFontName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if fonts.contains(trimmed) {
            return trimmed
        }
        let compacted = trimmed.lowercased().filter { !$0.isWhitespace }
        guard !compacted.isEmpty else { return "System" }
        for canonical in fonts {
            let canonicalCompacted = canonical.lowercased().filter { !$0.isWhitespace }
            if canonicalCompacted == compacted {
                return canonical
            }
        }
        return "System"
    }

    // swiftlint:disable switch_case_alignment
    static func font(name: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch name {
            case "Serif":
                return .system(size: size, weight: weight, design: .serif)
            case "Mono":
                return .system(size: size, weight: weight, design: .monospaced)
            case "System":
                return .system(size: size, weight: weight, design: .default)
            default:
                let psName = postScriptName(for: name)
                return .custom(psName, size: size)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private static func postScriptName(for displayName: String) -> String {
        switch displayName {
            case "Arial": return "ArialMT"
            case "Be Vietnam Pro", "BeVietnamPro": return "BeVietnamPro-Regular"
            case "Georgia": return "Georgia"
            case "Google Sans", "GoogleSans": return "GoogleSans-Regular"
            case "Inter": return "Inter-Regular"
            case "Lato": return "Lato-Regular"
            case "Lora": return "Lora-Regular"
            case "Merriweather": return "Merriweather24pt-Regular"
            case "Montserrat": return "Montserrat-Regular"
            case "Montserrat Alternates", "MontserratAlternates": return "MontserratAlternates-Regular"
            case "Noto Sans", "NotoSans": return "NotoSans-Regular"
            case "Noto Serif", "NotoSerif": return "NotoSerif-Regular"
            case "Open Sans", "OpenSans": return "OpenSans-Regular"
            case "PT Sans", "PTSans": return "PTSans-Regular"
            case "PT Serif", "PTSerif": return "PTSerif-Regular"
            case "Raleway": return "Raleway-Regular"
            case "Roboto": return "Roboto-Regular"
            case "Space Mono", "SpaceMono": return "SpaceMono-Regular"
            case "Times New Roman", "TimesNewRoman": return "TimesNewRomanPSMT"
            case "Verdana": return "Verdana"
            case "Work Sans", "WorkSans": return "WorkSans-Regular"
            default: return displayName
        }
    }
    // swiftlint:enable cyclomatic_complexity switch_case_alignment
}

/// Helper for offset restore decision — testable without importing domain types
enum ReaderOffsetRestore {
    static func offsetToRestore(
        sessionBookId: String?,
        sessionOffset: Double?,
        currentBookId: String
    ) -> Double? {
        guard let sessionBookId, let sessionOffset, sessionBookId == currentBookId, sessionOffset > 0 else {
            return nil
        }
        return sessionOffset
    }
}
