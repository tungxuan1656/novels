import Foundation
import SwiftUI

/// Pure helper for edge-swipe chapter navigation — testable without UI.
///
/// Convention: swipe right starting within the left 4/5 goes to previous
/// chapter, swipe left starting within the right 4/5 goes to next chapter.
/// The middle 3/5 overlaps and is disambiguated by direction. The far 1/5
/// on the opposite edge acts as a guard against wrong-direction swipes.
/// Anything else (vertical, diagonal, short, wrong direction) is ignored.
enum EdgeSwipeDirection: Equatable {
    case prev
    case next
}

enum EdgeSwipeDecision {
    static let minimumDistance: CGFloat = 60
    static let directionRatio: CGFloat = 2
    static let throttleInterval: TimeInterval = 0.6

    /// Decide navigation from a horizontal drag.
    /// - Parameters:
    ///   - startX: drag start x in content coordinates.
    ///   - width: content width defining the left/right 4/5 zones.
    ///   - dx: horizontal translation (positive = swipe right).
    ///   - dy: vertical translation.
    /// - Returns: `.prev` / `.next` when the gesture matches an edge swipe, else nil.
    static func decision(startX: CGFloat, width: CGFloat, dx: CGFloat, dy: CGFloat) -> EdgeSwipeDirection? {
        guard width > 0 else { return nil }
        guard abs(dx) >= minimumDistance, abs(dx) > directionRatio * abs(dy) else { return nil }
        if startX <= width * 4 / 5, dx > 0 {
            return .prev
        }
        if startX >= width / 5, dx < 0 {
            return .next
        }
        return nil
    }

    /// Throttle: at most one chapter switch per interval.
    static func isThrottleOk(
        now: Date,
        lastSwitch: Date,
        interval: TimeInterval = throttleInterval
    ) -> Bool {
        now.timeIntervalSince(lastSwitch) >= interval
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
        // Offset 0 (top of chapter) is a valid restore position: same book is enough.
        guard let sessionBookId, let sessionOffset, sessionBookId == currentBookId, sessionOffset >= 0 else {
            return nil
        }
        return sessionOffset
    }
}

/// Splits a full chapter body into small chunks for rendering.
///
/// A whole chapter in one SwiftUI `Text` creates a single huge CoreText layout
/// + backing layer. Past the raster height limit the ScrollView still reports
/// contentSize (scrollable) but tiles rasterize blank — custom fonts hit this
/// first because their vertical metrics are taller than SF at the same pt size.
/// One `Text` per chunk keeps every layer small so long chapters stay visible
/// at any size, for any font. Paragraph breaks from the source (`\n\n`) are
/// preserved via `endsParagraph`, so the reader restores the trailing blank
/// line itself instead of approximating it with stack spacing.
enum ReaderBodySplitter {
    static let maxChunkLength = 1200

    struct Chunk {
        let text: String
        let endsParagraph: Bool
    }

    static func split(_ text: String, maxLength: Int = maxChunkLength) -> [Chunk] {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let source = paragraphs.isEmpty && !text.isEmpty ? [text] : paragraphs
        var chunks: [Chunk] = []
        for (paragraphIndex, paragraph) in source.enumerated() {
            let pieces = splitLong(paragraph, maxLength: maxLength)
            for (pieceIndex, piece) in pieces.enumerated() {
                let isLastPiece = pieceIndex == pieces.count - 1
                let isLastParagraph = paragraphIndex == source.count - 1
                chunks.append(Chunk(text: piece, endsParagraph: isLastPiece && !isLastParagraph))
            }
        }
        return chunks
    }

    private static func splitLong(_ paragraph: String, maxLength: Int) -> [String] {
        guard paragraph.count > maxLength else { return [paragraph] }
        let lines = paragraph
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let source = lines.isEmpty ? [paragraph] : lines
        return source.flatMap { hardSplit($0, maxLength: maxLength) }
    }

    private static func hardSplit(_ line: String, maxLength: Int) -> [String] {
        guard line.count > maxLength else { return [line] }
        var chunks: [String] = []
        var rest = line
        while rest.count > maxLength {
            let cutIndex = rest.index(rest.startIndex, offsetBy: maxLength)
            let window = rest[..<cutIndex]
            if let spaceIndex = window.lastIndex(of: " ") {
                chunks.append(String(rest[..<spaceIndex]))
                rest = String(rest[rest.index(after: spaceIndex)...])
            } else {
                chunks.append(String(window))
                rest = String(rest[cutIndex...])
            }
        }
        if !rest.isEmpty {
            chunks.append(rest)
        }
        return chunks
    }
}
