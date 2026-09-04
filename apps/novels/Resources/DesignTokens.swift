import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(hex: Int, opacity: Double = 1) {
        self.init(hex: UInt32(hex), opacity: opacity)
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1
        )
    }

    static func adapted(lightHex: UInt32, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : UIColor(hex: lightHex)
        }
    }
}
#endif

enum DesignTokens {
    #if canImport(UIKit)
    static let backgroundPaper = Color(uiColor: .adapted(lightHex: 0xF5F1E5, dark: UIColor(hex: 0x0F1419)))
    static let backgroundWhite = Color(uiColor: .adapted(lightHex: 0xFFFFFF, dark: UIColor(hex: 0x0F1419)))
    static let backgroundGrouped = Color(uiColor: .adapted(lightHex: 0xF5F5F5, dark: UIColor(hex: 0x171D23)))
    static let surface = Color(uiColor: .adapted(lightHex: 0xFFFFFF, dark: UIColor(hex: 0x171D23)))
    static let text = Color(uiColor: .adapted(lightHex: 0x111111, dark: .label))
    static let muted = Color(uiColor: .adapted(lightHex: 0x6B7280, dark: .secondaryLabel))
    static let accent = Color(hex: 0x2563EB)
    static let success = Color(hex: 0x16A34A)
    static let warning = Color(hex: 0xEA580C)
    static let error = Color(hex: 0xDC2626)
    static let border = Color(uiColor: .adapted(lightHex: 0xE5E7EB, dark: UIColor(hex: 0x232B33)))
    #else
    static let backgroundPaper = Color(hex: 0xF5F1E5)
    static let backgroundWhite = Color(hex: 0xFFFFFF)
    static let backgroundGrouped = Color(hex: 0xF5F5F5)
    static let surface = Color(hex: 0xFFFFFF)
    static let text = Color(hex: 0x111111)
    static let muted = Color(hex: 0x6B7280)
    static let accent = Color(hex: 0x2563EB)
    static let success = Color(hex: 0x16A34A)
    static let warning = Color(hex: 0xEA580C)
    static let error = Color(hex: 0xDC2626)
    static let border = Color(hex: 0xE5E7EB)
    #endif

    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusSheet: CGFloat = 24

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    static let rowMinHeight: CGFloat = 56
    static let sidePadding: CGFloat = 16
}

// MARK: - Reading themes (feat-021, approved trio, exact hex)

extension ReadingTheme {
    var background: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return Color(hex: 0xF5F1E5)
            case .trang:
                return Color(hex: 0xFFFFFF)
            case .den:
                return Color(hex: 0x171512)
        }
        // swiftlint:enable switch_case_alignment
    }

    var headerBackground: Color {
        background
    }

    var textPrimary: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return Color(hex: 0x111111)
            case .trang:
                return Color(hex: 0x111111)
            case .den:
                return Color(hex: 0xECE7DF)
        }
        // swiftlint:enable switch_case_alignment
    }

    var textMuted: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return Color(hex: 0x6B7280)
            case .trang:
                return Color(hex: 0x6B7280)
            case .den:
                return Color(hex: 0xA8A29E)
        }
        // swiftlint:enable switch_case_alignment
    }

    var iconTint: Color {
        textMuted
    }

    var chipBackground: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return Color(hex: 0xE8DDC0)
            case .trang:
                return Color(hex: 0xEFEFF1)
            case .den:
                return Color(hex: 0x2A2724)
        }
        // swiftlint:enable switch_case_alignment
    }

    var borderColor: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return Color(hex: 0xDCD2B6)
            case .trang:
                return Color(hex: 0xE5E7EB)
            case .den:
                return Color(hex: 0x3B3732)
        }
        // swiftlint:enable switch_case_alignment
    }

    var accentColor: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return Color(hex: 0x2563EB)
            case .trang:
                return Color(hex: 0x2563EB)
            case .den:
                return Color(hex: 0x60A5FA)
        }
        // swiftlint:enable switch_case_alignment
    }

    var preferredColorScheme: ColorScheme {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay, .trang:
                return .light
            case .den:
                return .dark
        }
        // swiftlint:enable switch_case_alignment
    }

    var isDark: Bool {
        self == .den
    }

    var disabledIconOpacity: Double {
        isDark ? 0.42 : 0.35
    }
}
