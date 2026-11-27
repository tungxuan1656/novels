import SwiftUI

struct ReaderHeader: View {
    let viewModel: ReaderViewModel
    let theme: ReadingTheme
    let isReaderReady: Bool
    let isActive: Bool
    let onBack: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onContents: () -> Void

    private var topChapterTitleText: String {
        let num = viewModel.chapterNumber
        if let title = viewModel.chapterTitle, !title.isEmpty {
            return "【\(num)】 \(title)"
        }
        if let bookName = viewModel.book?.name, !bookName.isEmpty {
            return "【\(num)】 Chương \(num): \(bookName)"
        }
        return "【\(num)】 Chương \(num)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(topChapterTitleText)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("chapterText")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background(theme.headerBackground)

            HStack {
                ReaderIconButton(symbol: "chevron.left", theme: theme, iconSize: 13, action: onBack)
                    .keyboardShortcut(isActive ? KeyboardShortcut("[") : nil)
                    .accessibilityIdentifier("backButton")
                    .accessibilityLabel("Quay lại Thư viện")

                Spacer()

                HStack(spacing: 4) {
                    if viewModel.isAIProcessing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 22, height: 28)
                            Text("Đang xử lý")
                                .font(.caption)
                                .foregroundStyle(theme.textMuted)
                                .lineLimit(1)
                        }
                        .frame(height: 28)
                        .accessibilityIdentifier("aiProgressHeader")
                        .accessibilityLabel("Đang xử lý")
                    }
                    HStack(spacing: 2) {
                        Button(action: onPrevious) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    viewModel.canGoPrev
                                        ? theme.iconTint
                                        : theme.iconTint.opacity(theme.disabledIconOpacity)
                                )
                                .frame(width: 22, height: 28)
                                .contentShape(Rectangle())
                        }
                        .disabled(!isReaderReady || !viewModel.canGoPrev)
                        .accessibilityIdentifier("prevButton")
                        .accessibilityLabel("Chương trước")

                        Button(action: onNext) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    viewModel.canGoNext
                                        ? theme.iconTint
                                        : theme.iconTint.opacity(theme.disabledIconOpacity)
                                )
                                .frame(width: 22, height: 28)
                                .contentShape(Rectangle())
                        }
                        .disabled(!isReaderReady || !viewModel.canGoNext)
                        .accessibilityIdentifier("nextButton")
                        .accessibilityLabel("Chương sau")
                    }
                    .padding(.horizontal, 2)
                    .frame(height: 28)
                    .background(theme.chipBackground)
                    .clipShape(Capsule())

                    ReaderIconButton(symbol: "list.bullet", theme: theme, action: onContents)
                        .disabled(!isReaderReady)
                        .accessibilityIdentifier("tocButton")
                        .accessibilityLabel("Mục lục")
                }
            }
            .padding(.horizontal, 8)
        }
        .accessibilityIdentifier("header")
    }
}

struct ReaderIconButton: View {
    let symbol: String
    let theme: ReadingTheme
    var size: CGFloat = 28
    var iconSize: CGFloat = 12
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(theme.iconTint)
                .frame(width: size, height: size)
                .background(theme.chipBackground, in: Circle())
                .contentShape(Circle())
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #else
        .a11yHitTarget()
        #endif
    }
}
