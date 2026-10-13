import SwiftUI

struct BilingualReaderBody: View {
    let paragraphs: [BilingualParagraph]
    let typography: TypographySetting
    let theme: ReadingTheme
    let onSelect: (BilingualParagraph) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: typography.fontSize + typography.lineHeight) {
            ForEach(paragraphs) { paragraph in
                VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
                    Text(verbatim: paragraph.vi)
                        .font(ReaderFontMapper.font(name: typography.font, size: typography.fontSize))
                        .foregroundStyle(theme.textPrimary)
                    Button {
                        onSelect(paragraph)
                    } label: {
                        Text(verbatim: paragraph.en)
                            .font(.system(size: EnglishLearning.fontSize(vietnamese: typography.fontSize)))
                            .foregroundStyle(theme.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Mở các câu tiếng Anh để nghe hoặc tra cứu Google")
                    .accessibilityIdentifier("english-\(paragraph.id)")
                }
                .lineSpacing(typography.lineHeight)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("bilingualContent")
    }
}
