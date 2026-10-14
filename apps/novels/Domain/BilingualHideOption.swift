import Foundation

nonisolated enum BilingualHideOption: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case none
    case vietnamese
    case english

    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .none:
                return "Không"
            case .vietnamese:
                return "Tiếng Việt"
            case .english:
                return "Tiếng Anh"
        }
        // swiftlint:enable switch_case_alignment
    }
}
