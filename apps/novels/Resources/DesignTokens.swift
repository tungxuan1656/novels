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
    static let backgroundWhite = Color(uiColor: .adapted(lightHex: 0xF5F5F5, dark: UIColor(hex: 0x0F1419)))
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
    static let backgroundWhite = Color(hex: 0xF5F5F5)
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

    static let rowMinHeight: CGFloat = 48
    static let sidePadding: CGFloat = 16
}

// MARK: - Reading themes (feat-026, approved Full 5, exact bg/text hex)

extension ReadingTheme {
    var background: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach:
                return Color(hex: 0xF7F1E3)
            case .xanhDiu:
                return Color(hex: 0xEEF3F0)
            case .xanhLam:
                return Color(hex: 0xEEF4F8)
            case .dem:
                return Color(hex: 0x1C1C1E)
            case .amoled:
                return Color(hex: 0x000000)
        }
        // swiftlint:enable switch_case_alignment
    }

    var headerBackground: Color {
        background
    }

    var textPrimary: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach:
                return Color(hex: 0x38342E)
            case .xanhDiu:
                return Color(hex: 0x29332F)
            case .xanhLam:
                return Color(hex: 0x29343B)
            case .dem:
                return Color(hex: 0xD2D2D2)
            case .amoled:
                return Color(hex: 0xC8C8C8)
        }
        // swiftlint:enable switch_case_alignment
    }

    var textMuted: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach:
                return Color(hex: 0x655C4E)
            case .xanhDiu:
                return Color(hex: 0x55645D)
            case .xanhLam:
                return Color(hex: 0x55636E)
            case .dem:
                return Color(hex: 0xA8A8A8)
            case .amoled:
                return Color(hex: 0xA0A0A0)
        }
        // swiftlint:enable switch_case_alignment
    }

    var iconTint: Color {
        textMuted
    }

    var chipBackground: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach:
                return Color(hex: 0xE7DEC7)
            case .xanhDiu:
                return Color(hex: 0xDCE5DF)
            case .xanhLam:
                return Color(hex: 0xDCE6EE)
            case .dem:
                return Color(hex: 0x2C2C2E)
            case .amoled:
                return Color(hex: 0x1C1C1E)
        }
        // swiftlint:enable switch_case_alignment
    }

    var borderColor: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach:
                return Color(hex: 0xD8CCAC)
            case .xanhDiu:
                return Color(hex: 0xC2CFC8)
            case .xanhLam:
                return Color(hex: 0xBFD0DC)
            case .dem:
                return Color(hex: 0x3A3A3C)
            case .amoled:
                return Color(hex: 0x2E2E30)
        }
        // swiftlint:enable switch_case_alignment
    }

    var accentColor: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach, .xanhDiu, .xanhLam:
                return Color(hex: 0x2563EB)
            case .dem, .amoled:
                return Color(hex: 0x7AB8FF)
        }
        // swiftlint:enable switch_case_alignment
    }

    var preferredColorScheme: ColorScheme {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach, .xanhDiu, .xanhLam:
                return .light
            case .dem, .amoled:
                return .dark
        }
        // swiftlint:enable switch_case_alignment
    }

    var isDark: Bool {
        self == .dem || self == .amoled
    }

    var disabledIconOpacity: Double {
        isDark ? 0.42 : 0.35
    }
}
