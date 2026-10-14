import SwiftUI

struct BilingualReaderBody: View {
    let paragraphs: [BilingualParagraph]
    let typography: TypographySetting
    let theme: ReadingTheme
    let englishPrimary: Bool
    var hideOption: BilingualHideOption = .none
    let onSelect: (BilingualParagraph) -> Void

    private var primaryFont: Font {
        ReaderFontMapper.font(name: typography.font, size: typography.fontSize)
    }

    private var secondaryFont: Font {
        .system(size: EnglishLearning.fontSize(primary: typography.fontSize))
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: typography.fontSize + typography.lineHeight) {
            ForEach(paragraphs) { paragraph in
                VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
                    if hideOption != .vietnamese {
                        if hideOption == .english {
                            Button {
                                onSelect(paragraph)
                            } label: {
                                Text(verbatim: paragraph.vi)
                                    .font(englishPrimary ? secondaryFont : primaryFont)
                                    .foregroundStyle(englishPrimary ? theme.textMuted : theme.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Mở các câu tiếng Anh để nghe hoặc tra cứu Google")
                            .accessibilityIdentifier("vietnamese-\(paragraph.id)")
                        } else {
                            Text(verbatim: paragraph.vi)
                                .font(englishPrimary ? secondaryFont : primaryFont)
                                .foregroundStyle(englishPrimary ? theme.textMuted : theme.textPrimary)
                        }
                    }
                    if hideOption != .english {
                        Button {
                            onSelect(paragraph)
                        } label: {
                            Text(verbatim: paragraph.en)
                                .font(englishPrimary ? primaryFont : secondaryFont)
                                .foregroundStyle(englishPrimary ? theme.textPrimary : theme.textMuted)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Mở các câu tiếng Anh để nghe hoặc tra cứu Google")
                        .accessibilityIdentifier("english-\(paragraph.id)")
                    }
                }
                .lineSpacing(typography.lineHeight)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("bilingualContent")
    }
}
