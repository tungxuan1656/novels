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
