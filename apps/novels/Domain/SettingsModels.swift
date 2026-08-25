import Foundation

struct AIAction: Codable, Equatable, Hashable {
    let key: String
    let name: String
    let prompt: String
}

enum SettingsDefaults {
    // swiftlint:disable trailing_comma
    static let defaultActions: [AIAction] = [
        AIAction(
            key: "translate",
            name: "Dich",
            prompt: "Translate faithfully"
        ),
        AIAction(
            key: "summary",
            name: "Tom tat",
            prompt: "Summarize faithfully"
        ),
    ]
    // swiftlint:enable trailing_comma

    static var defaultActionsJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(defaultActions),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }
}
