import SwiftUI

struct ReferencesView: View {
    let book: Book
    let current: Int
    var onSelect: (Int) -> Void
    @Bindable var router: Router

    var body: some View {
        List {
            ForEach(Array(book.references.enumerated()), id: \.offset) { idx, title in
                let chapter = idx + 1
                Button {
                    onSelect(chapter)
                    router.pop()
                } label: {
                    HStack {
                        Text("Chương \(chapter): \(title)")
                            .foregroundStyle(DesignTokens.text)
                        Spacer()
                        if chapter == current {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DesignTokens.accent)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .listRowBackground(chapter == current ? DesignTokens.accent.opacity(0.08) : Color.clear)
                .fontWeight(chapter == current ? .bold : .regular)
                .accessibilityIdentifier("ref-\(chapter)")
                .accessibilityLabel("Chương \(chapter): \(title)")
            }
        }
        .navigationTitle("Tài liệu tham khảo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    router.pop()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Đọc sách")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Quay lại Đọc sách")
            }
        }
    }
}
