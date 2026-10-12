import SwiftUI

struct ReaderTextBody: View {
    let text: String
    let typography: TypographySetting
    let theme: ReadingTheme

    var body: some View {
        let font = ReaderFontMapper.font(name: typography.font, size: typography.fontSize)
        let chunks = ReaderBodySplitter.split(text)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { entry in
                Text(verbatim: entry.element)
                    .font(font)
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(typography.lineHeight)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, typography.fontSize + typography.lineHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pure helper for scroll-restore decision — testable without UI.
enum ReaderRestoreDecision {
    /// Top-of-chapter (or missing) offsets need no scroll work.
    static func needsScrollRestore(offset: Double?) -> Bool {
        (offset ?? 0) > 0
    }
}
