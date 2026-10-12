import Foundation

// swiftlint:disable switch_case_alignment trailing_comma
nonisolated enum AIProvider: String, CaseIterable, Sendable {
    case auto
    case openai
    case anthropic
    case muse
    case deepseek
    case mimo
    case glm
    case minimax
    case kimi
    case gemini

    var label: String {
        switch self {
            case .auto: "Tự động"
            case .openai: "OpenAI"
            case .anthropic: "Anthropic"
            case .muse: "Muse Spark"
            case .deepseek: "DeepSeek"
            case .mimo: "MiMo"
            case .glm: "GLM / Z.ai"
            case .minimax: "MiniMax"
            case .kimi: "Kimi"
            case .gemini: "Gemini"
        }
    }

    static func normalized(_ raw: String) -> AIProvider? {
        AIProvider(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func resolved(model: String, urlString: String) -> AIProvider {
        guard self == .auto else { return self }
        let name = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .split(separator: "/").last.map(String.init) ?? ""
        let prefixes: [(String, AIProvider)] = [
            ("gpt-", .openai), ("claude", .anthropic), ("muse", .muse),
            ("deepseek", .deepseek), ("mimo", .mimo), ("glm", .glm),
            ("minimax", .minimax), ("kimi", .kimi), ("moonshot", .kimi), ("gemini", .gemini),
        ]
        if let match = prefixes.first(where: { name.hasPrefix($0.0) }) {
            return match.1
        }
        if name.range(of: "^o[0-9]+([.-]|$)", options: .regularExpression) != nil {
            return .openai
        }
        let host = URL(string: urlString)?.host?.lowercased() ?? ""
        let domains: [(String, AIProvider)] = [
            ("openai.com", .openai), ("anthropic.com", .anthropic), ("meta.ai", .muse),
            ("deepseek.com", .deepseek), ("xiaomimimo.com", .mimo), ("z.ai", .glm),
            ("bigmodel.cn", .glm), ("minimax.io", .minimax), ("minimaxi.com", .minimax),
            ("moonshot.ai", .kimi), ("moonshot.cn", .kimi), ("kimi.ai", .kimi),
            ("generativelanguage.googleapis.com", .gemini),
        ]
        return domains.first(where: { host == $0.0 || host.hasSuffix("." + $0.0) })?.1 ?? .openai
    }
}

// swiftlint:enable switch_case_alignment trailing_comma
