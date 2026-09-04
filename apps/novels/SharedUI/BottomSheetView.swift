import SwiftUI

/// Used by feat-004 Reading sheet, reserved — keep as primitive for future sheets.
struct BottomSheetView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, DesignTokens.spacing16)
            .padding(.bottom, DesignTokens.spacing16)
            .padding(.top, DesignTokens.spacing24)
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
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
}
