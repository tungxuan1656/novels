import Foundation

struct TypographySetting: Codable, Equatable {
    var font: String
    var fontSize: Double
    var lineHeight: Double
    var letterSpacing: Double

    static let `default` = TypographySetting(
        font: "System",
        fontSize: 16,
        lineHeight: 1.5,
        letterSpacing: 0
    )
}
