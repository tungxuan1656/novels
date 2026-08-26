import Foundation

struct TextSpan: Equatable {
    enum Kind: Equatable {
        case body
        case heading(level: Int)
        case bold
        case italic
        case boldItalic
    }

    var text: String
    var kind: Kind
    var isLineBreak: Bool = false
}

struct TextBlock: Equatable {
    var spans: [TextSpan]
    var isHeading: Bool = false
    // swiftlint:disable:next implicit_optional_initialization
    var headingLevel: Int? = nil
}
