import Foundation

/// Splits a full chapter body into small chunks for rendering.
///
/// A whole chapter in one SwiftUI `Text` creates a single huge CoreText layout
/// + backing layer. Past the raster height limit the ScrollView still reports
/// contentSize (scrollable) but tiles rasterize blank — custom fonts hit this
/// first because their vertical metrics are taller than SF at the same pt size.
/// One `Text` per chunk keeps every layer small so long chapters stay visible
/// at any size, for any font. Paragraph breaks from the source (`\n\n`) are
/// reported via `isParagraphEnd`, so the reader renders the paragraph gap
/// itself with explicit bottom padding instead of embedding newline characters.
enum ReaderBodySplitter {
    static let maxParagraphLength = 5000

    struct Chunk {
        let text: String
        let isParagraphEnd: Bool
    }

    static func split(_ text: String, maxLength: Int = maxParagraphLength) -> [Chunk] {
        // Split on blank lines only. Trimming is used solely to detect
        // whitespace-only paragraphs; the original string (including any
        // leading indent) is kept intact for rendering.
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !paragraphs.isEmpty else { return [] }
        var chunks: [Chunk] = []
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let isLastParagraph = paragraphIndex == paragraphs.count - 1
            // Short paragraphs stay whole, preserving inner single `\n`.
            guard paragraph.count > maxLength else {
                chunks.append(Chunk(text: paragraph, isParagraphEnd: !isLastParagraph))
                continue
            }
            let pieces = splitLong(paragraph, maxLength: maxLength)
            for (pieceIndex, piece) in pieces.enumerated() {
                let isLastPiece = pieceIndex == pieces.count - 1
                chunks.append(Chunk(
                    text: piece,
                    isParagraphEnd: isLastPiece && !isLastParagraph
                ))
            }
        }
        return chunks
    }

    private static func splitLong(_ paragraph: String, maxLength: Int) -> [String] {
        // Only reached for oversized paragraphs. Split on single line breaks,
        // keeping each original line (indent included) for rendering.
        // Trimming is used solely to skip whitespace-only lines.
        let lines = paragraph
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
