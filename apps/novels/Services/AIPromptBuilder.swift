import Foundation

enum AIPromptBuilder {
    static func prompt(for mode: AIMode, actionsJSON: String) -> String {
        if mode == .none {
            return ""
        }
        if let data = actionsJSON.data(using: .utf8),
           let actions = try? JSONDecoder().decode([AIAction].self, from: data),
           let found = actions.first(where: { $0.key == mode.rawValue })
        { // swiftlint:disable:this opening_brace
            return found.prompt
        }
        return defaultPrompt(for: mode)
    }

    static func defaultPrompt(for mode: AIMode) -> String {
        // swiftlint:disable switch_case_alignment
        switch mode {
            case .translate:
                return SettingsDefaults.defaultActions.first(where: { $0.key == "translate" })?.prompt
                    ?? "Translate faithfully keep honorifics ta ngươi huynh đệ, natural Vietnamese 100%"
            case .summary:
                return SettingsDefaults.defaultActions.first(where: { $0.key == "summary" })?.prompt
                    ?? "Summarize 50-60% keep plot order key events twists key dialogue, no hallucination"
            case .none:
                return ""
        }
        // swiftlint:enable switch_case_alignment
    }
}
