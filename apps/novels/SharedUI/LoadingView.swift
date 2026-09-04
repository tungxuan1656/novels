import SwiftUI

struct LoadingView: View {
    var message: String = "Đang tải..."
    var isBlocking: Bool = false

    var body: some View {
        ZStack {
            if isBlocking {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
            }
            VStack(spacing: DesignTokens.spacing12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(DesignTokens.accent)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.muted)
            }
            .padding(DesignTokens.spacing24)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge))
            .shadow(color: .black.opacity(0.1), radius: 12)
        }
        .accessibilityLabel(message)
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Đang tải...") -> some View {
        overlay {
            if isLoading {
                LoadingView(message: message, isBlocking: true)
            }
        }
    }
}
