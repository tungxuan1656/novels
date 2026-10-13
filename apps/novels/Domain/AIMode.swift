import Foundation

nonisolated enum AIMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case none
    case rewrite
    case bilingual

    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .none:
                return "Bản gốc"
            case .rewrite:
                return "Dịch"
            case .bilingual:
                return "Song ngữ"
        }
        // swiftlint:enable switch_case_alignment
    }
}
