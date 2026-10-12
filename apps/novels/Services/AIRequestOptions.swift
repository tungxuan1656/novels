import Foundation

// swiftlint:disable switch_case_alignment trailing_comma
nonisolated struct AIRequestOptions: Sendable {
    var provider: AIProvider = .auto
    var thinking: AIThinkingEffort?
    var outputSchema: AIOutputSchema?

    func thinkingFields(family: AIEndpointFamily, extra: [String: Any]) throws -> [String: Any] {
        guard let thinking, !Self.hasCustomThinking(extra) else { return [:] }
        switch family {
            case .responses:
                guard provider != .mimo else { throw unsupported("MiMo thinking on Responses") }
                return ["reasoning": ["effort": thinking.rawValue]]
            case .anthropic:
                guard provider == .anthropic || provider == .minimax else {
                    throw unsupported("Thinking on Messages for this provider")
                }
                return thinking == .none ? ["thinking": ["type": "disabled"]] : [
                    "thinking": ["type": "adaptive"], "output_config": ["effort": thinking.rawValue],
                ]
            case .chatCompletions:
                return try chatThinking(thinking)
        }
    }

    private func chatThinking(_ effort: AIThinkingEffort) throws -> [String: Any] {
        switch provider {
            case .auto, .openai, .muse, .gemini:
                return ["reasoning_effort": effort.rawValue]
            case .anthropic:
                throw unsupported("Anthropic thinking on Chat Completions")
            case .mimo:
                guard effort == .none else {
                    throw unsupported(
                        "MiMo has binary thinking, not low/medium/high depth; use default or custom thinking"
                    )
                }
                return ["thinking": ["type": "disabled"]]
            case .deepseek, .glm, .minimax, .kimi:
                if effort == .none {
                    return ["thinking": ["type": "disabled"]]
                }
                if provider == .kimi {
                    return ["reasoning_effort": effort.rawValue]
                }
                return [
                    "thinking": ["type": provider == .minimax ? "adaptive" : "enabled"],
                    "reasoning_effort": effort.rawValue,
                ]
        }
    }

    func addingSchema(to body: [String: Any], family: AIEndpointFamily) throws -> [String: Any] {
        guard let outputSchema else { return body }
        let strict = family == .responses
            || (family == .chatCompletions && ![AIProvider.deepseek, .glm, .mimo, .minimax].contains(provider))
        let schema = try outputSchema.object(strict: strict)
        var result = body
        let format: [String: Any] = [
            "type": "json_schema", "name": outputSchema.name, "schema": schema, "strict": true,
        ]
        switch family {
            case .chatCompletions:
                guard body["response_format"] == nil
                else { throw unsupported("Custom response_format conflicts with schema") }
                if provider == .minimax {
                    return result
                }
                if [.deepseek, .glm, .mimo].contains(provider) {
                    result["response_format"] = ["type": "json_object"]
                } else {
                    result["response_format"] = ["type": "json_schema", "json_schema": [
                        "name": outputSchema.name, "schema": schema, "strict": true,
                    ]]
                }
            case .responses:
                result["text"] = try Self.containerWithFormat(body["text"], format: format)
            case .anthropic:
                guard provider == .anthropic || provider == .minimax else {
                    throw unsupported("Output schema on Messages for this provider")
                }
                if provider == .minimax {
                    if let value = body["output_config"] {
                        guard let container = value as? [String: Any] else {
                            throw unsupported("Structured output needs an object output_config")
                        }
                        guard container["format"] == nil else {
                            throw unsupported("Custom output_config.format conflicts with schema")
                        }
                    }
                    return result
                }
                result["output_config"] = try Self.containerWithFormat(
                    body["output_config"], format: ["type": "json_schema", "schema": schema]
                )
        }
        return result
    }

    static func hasCustomThinking(_ extra: [String: Any]) -> Bool {
        let keys = ["thinking", "reasoning_effort", "reasoning", "thinking_config", "thinking_budget", "thinking_level"]
        if keys.contains(where: { extra[$0] != nil }) {
            return true
        }
        if (extra["output_config"] as? [String: Any])?["effort"] != nil {
            return true
        }
        let sdkExtra = extra["extra_body"] as? [String: Any]
        let google = (sdkExtra?["google"] ?? extra["google"]) as? [String: Any]
        return google?["thinking_config"] != nil || google?["thinkingConfig"] != nil
    }

    private static func containerWithFormat(_ value: Any?, format: [String: Any]) throws -> [String: Any] {
        if let value, !(value is [String: Any]) {
            throw AIClientError.invalidConfiguration("Structured output needs an object format container.")
        }
        var container = value as? [String: Any] ?? [:]
        guard container["format"] == nil else {
            throw AIClientError.invalidConfiguration("Custom format conflicts with output schema.")
        }
        container["format"] = format
        return container
    }

    private func unsupported(_ detail: String) -> AIClientError {
        .invalidConfiguration(detail + ". Configure the endpoint/provider or custom body explicitly.")
    }
}

// swiftlint:enable switch_case_alignment trailing_comma
