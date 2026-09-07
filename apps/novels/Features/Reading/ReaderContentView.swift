import SwiftUI

/// Renders one TextBlock to Text. Shared by raw mode and AI mode so a
/// heading looks identical in both. Pure view of its inputs: no store access.
struct ReaderContentView: View {
    let block: TextBlock
    let fontName: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let textPrimary: Color

    var body: some View {
        combined
            .lineSpacing(lineHeight)
            .multilineTextAlignment(.leading)
    }

    private var combined: Text {
        block.spans.reduce(Text("")) { accumulator, span in
            if span.isLineBreak {
                return accumulator + Text(span.text)
            }
            var piece = Text(span.text)
                .font(fontFor(block: block, span: span))
                .foregroundStyle(textPrimary)
            if span.kind == .bold || span.kind == .boldItalic {
                piece = piece.bold()
            }
            if span.kind == .italic || span.kind == .boldItalic {
                piece = piece.italic()
            }
            return accumulator + piece
        }
    }

    private func fontFor(block: TextBlock, span: TextSpan) -> Font {
        if block.isHeading {
            let level = CGFloat(block.headingLevel ?? 3)
            let size = fontSize + CGFloat(7 - level) * 2
            return ReaderFontMapper.font(name: fontName, size: size, weight: .bold)
        }
        return ReaderFontMapper.font(name: fontName, size: fontSize)
    }
}
