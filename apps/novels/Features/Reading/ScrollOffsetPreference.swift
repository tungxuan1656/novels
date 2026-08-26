import Foundation
import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Pure helper for bottom overscroll detection — testable without UI
enum ReaderOverscrollLogic {
    static func isNearBottom(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        threshold: CGFloat = 40
    ) -> Bool {
        guard contentHeight > 0, viewportHeight > 0 else { return false }
        guard contentHeight > viewportHeight else { return false }
        return offsetY < -(contentHeight - viewportHeight - threshold)
    }

    static func isOverscrolledBeyondBottom(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        threshold: CGFloat = 40
    ) -> Bool {
        guard contentHeight > 0, viewportHeight > 0 else { return false }
        guard contentHeight > viewportHeight else { return false }
        return offsetY < -(contentHeight - viewportHeight + threshold)
    }
}

/// Helper for font design mapping — testable
enum ReaderFontDesign {
    static func design(for name: String) -> Font.Design {
        // swiftlint:disable switch_case_alignment
        switch name {
            case "Serif": return .serif
            case "Mono": return .monospaced
            default: return .default
        }
        // swiftlint:enable switch_case_alignment
    }
}

/// Helper for offset restore decision — testable without importing domain types
enum ReaderOffsetRestore {
    static func offsetToRestore(
        sessionBookId: String?,
        sessionOffset: Double?,
        currentBookId: String
    ) -> Double? {
        guard let sessionBookId, let sessionOffset, sessionBookId == currentBookId, sessionOffset > 0 else {
            return nil
        }
        return sessionOffset
    }
}
