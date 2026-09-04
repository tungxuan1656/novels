import SwiftUI

struct ReferencesView: View {
    let book: Book
    let current: Int
    var onSelect: (Int) -> Void
    @Bindable var router: Router

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0 ..< book.references.count, id: \.self) { idx in
                        let chapter = idx + 1
                        let title = book.references[idx]
                        Button {
                            onSelect(chapter)
                            router.pop()
                        } label: {
                            VStack(spacing: 0) {
                                HStack(spacing: 8) {
                                    Text("\(chapter)")
                                        .font(.footnote)
                                        .foregroundStyle(DesignTokens.muted)
                                        .frame(width: 36, alignment: .leading)
                                    Text(title)
                                        .font(.body)
                                        .foregroundStyle(DesignTokens.text)
                                        .lineLimit(1)
                                    Spacer()
                                    if chapter == current {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(DesignTokens.accent)
                                    }
                                }
                                .padding(.horizontal, DesignTokens.spacing16)
                                .padding(.vertical, 12)

                                Divider()
                                    .padding(.leading, 56)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(chapter)
                        .accessibilityIdentifier("ref-\(chapter)")
                        .accessibilityLabel("Chương \(chapter): \(A11yHelpers.cleanedTitle(title))")
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(current, anchor: .center)
            }
        }
        .background(DesignTokens.backgroundWhite)
        .navigationTitle("Mục lục")
        .navigationBarTitleDisplayMode(.inline)
    }
}
