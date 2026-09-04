import Foundation

enum AIMode: String, Codable, CaseIterable, Equatable, Identifiable {
    case none
    case rewrite

    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .none:
                return "Không"
            case .rewrite:
                return "Rewrite"
        }
        // swiftlint:enable switch_case_alignment
    }
}
