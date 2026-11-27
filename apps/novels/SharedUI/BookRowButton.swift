import SwiftUI

struct BookRowButton<Label: View>: View {
    enum Accessory {
        case open
        case download
    }

    let accessory: Accessory
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(minHeight: DesignTokens.rowMinHeight, alignment: .leading)
            #if os(macOS)
                .padding(.vertical, accessory == .download ? DesignTokens.spacing8 : 0)
                .padding(.trailing, DesignTokens.spacing24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    Image(systemName: accessory == .download ? "arrow.down.circle" : "chevron.right")
                        .font(accessory == .download ? .title3 : .caption.weight(.semibold))
                        .foregroundStyle(accessory == .download ? DesignTokens.accent : DesignTokens.muted)
                        .accessibilityHidden(true)
                }
            #endif
                .contentShape(Rectangle())
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
        .listRowBackground(DesignTokens.surface)
        .listRowSeparatorTint(DesignTokens.border)
    }
}
