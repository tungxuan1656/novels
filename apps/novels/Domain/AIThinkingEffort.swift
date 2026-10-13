import Foundation

nonisolated enum AIThinkingEffort: String, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .none:
                return "Tắt"
            case .low:
                return "Thấp"
            case .medium:
                return "Vừa"
            case .high:
                return "Cao"
        }
        // swiftlint:enable switch_case_alignment
    }

    static func normalized(_ raw: String) -> AIThinkingEffort? {
        AIThinkingEffort(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
