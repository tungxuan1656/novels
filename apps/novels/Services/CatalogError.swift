import Foundation

enum CatalogError: Error, Equatable {
    case serverMessage(String)
    case network(URLError)
    case decoding(Error)

    static func == (lhs: CatalogError, rhs: CatalogError) -> Bool {
        switch (lhs, rhs) {
            // swiftlint:disable:next switch_case_alignment
            case let (.serverMessage(lhsMessage), .serverMessage(rhsMessage)):
                return lhsMessage == rhsMessage
            // swiftlint:disable:next switch_case_alignment
            case let (.network(lhsError), .network(rhsError)):
                return lhsError.code == rhsError.code
            // swiftlint:disable:next switch_case_alignment
            case let (.decoding(lhsError), .decoding(rhsError)):
                return String(describing: lhsError) == String(describing: rhsError)
            // swiftlint:disable:next switch_case_alignment
            default:
                return false
        }
    }
}
