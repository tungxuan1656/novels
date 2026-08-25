import SwiftUI

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

enum DesignTokens {
    static let backgroundPaper = Color(hex: 0xFDFCF8)
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
