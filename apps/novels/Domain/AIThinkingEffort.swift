import Foundation

nonisolated enum AIThinkingEffort: String, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high

    static func normalized(_ raw: String) -> AIThinkingEffort? {
        AIThinkingEffort(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
