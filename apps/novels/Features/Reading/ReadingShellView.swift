import SwiftUI

struct ReadingShellView: View {
    let bookId: String
    @Bindable var router: Router
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacing16) {
                Text("Đang đọc: \(bookId)")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.text)
                Text("Nội dung sẽ hiển thị ở feat-004 (HTML → SwiftUI.Text)")
                    .font(.body)
                    .foregroundStyle(DesignTokens.muted)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Tài liệu tham khảo") {
                    router.push(.references)
                }
                .buttonStyle(.bordered)
                .tint(DesignTokens.accent)
                Spacer(minLength: 200)
            }
            .padding(DesignTokens.spacing16)
        }
        .background(DesignTokens.backgroundPaper)
        .navigationTitle("Đọc sách")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    router.didPopFromReading()
                    router.pop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Thư viện")
                    }
                }
                .accessibilityLabel("Quay lại Thư viện")
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear {
            settings.session?.onScreen = true
            settings.save()
        }
    }
}
