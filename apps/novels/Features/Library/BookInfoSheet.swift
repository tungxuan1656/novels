import SwiftUI

struct BookInfoSheet: View {
    let book: Book
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing16) {
                    infoCard
                    chaptersCard
                }
                .padding(DesignTokens.spacing16)
            }
            .background(DesignTokens.backgroundGrouped)
            .navigationTitle("Thông tin sách")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .accessibilityLabel("Đóng")
                }
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
            Text(book.name)
                .font(.title3)
                .bold()
                .foregroundStyle(DesignTokens.text)
                .lineLimit(2)
            if let author = book.author {
                Label(author, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.muted)
            }
            Label("\(book.count) chương", systemImage: "list.number")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.muted)
        }
        .padding(DesignTokens.spacing16)
        .background(DesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }

    private var chaptersCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
            Text("Danh mục chương")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.text)
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0 ..< book.references.count, id: \.self) { index in
                    let title = book.references[index]
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(index + 1)")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.muted)
                                .frame(width: 28, alignment: .leading)
                            Text(title)
                                .font(.body)
                                .foregroundStyle(DesignTokens.text)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        if index < book.references.count - 1 {
                            Divider()
                                .background(DesignTokens.border)
                        }
                    }
                }
            }
        }
        .padding(DesignTokens.spacing16)
        .background(DesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }
}
