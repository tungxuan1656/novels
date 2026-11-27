import SwiftUI

struct PrimaryToolbarItem<Control: View>: ToolbarContent {
    @ViewBuilder let control: () -> Control

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            control()
            #if os(iOS)
                .a11yHitTarget()
            #endif
        }
        #if os(macOS)
        .sharedBackgroundVisibility(.hidden)
        #endif
    }
}

#if os(macOS)
struct MacBackToolbarItem: ToolbarContent {
    var isEnabled = true
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Quay lại", systemImage: "chevron.left", action: action)
                .keyboardShortcut("[")
                .labelStyle(.iconOnly)
                .help("Quay lại")
                .disabled(!isEnabled)
        }
    }
}
#endif
