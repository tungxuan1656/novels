import SwiftUI

/// Used by feat-004 Reading sheet, reserved — keep as primitive for future sheets.
struct BottomSheetView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DesignTokens.border)
                .frame(width: 40, height: 5)
                .padding(.top, DesignTokens.spacing8)
                .padding(.bottom, DesignTokens.spacing12)
            content
                .padding(.horizontal, DesignTokens.spacing16)
                .padding(.bottom, DesignTokens.spacing16)
        }
        .background(DesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusSheet, style: .continuous))
    }
}

extension View {
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            BottomSheetView(content: content)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
    }
}
