import Foundation

enum AIPromptBuilder {
    static func prompt(for mode: AIMode, customPrompt: String) -> String {
        if mode == .none {
            return ""
        }
        let trimmed = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return SettingsDefaults.defaultPrompt
        }
        return customPrompt
    }

    static func defaultPrompt(for mode: AIMode) -> String {
        // swiftlint:disable switch_case_alignment
        switch mode {
            case .none:
                return ""
            case .rewrite:
                return SettingsDefaults.defaultPrompt
        }
        // swiftlint:enable switch_case_alignment
    }
}
