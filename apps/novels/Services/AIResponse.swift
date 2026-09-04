import Foundation

/// Endpoint family branched by URL path substring.
enum AIEndpointFamily: Sendable, Equatable {
    case chatCompletions
    case responses
    case anthropic

    static func detect(urlString: String) -> AIEndpointFamily {
        let lower = urlString.lowercased()
        if lower.contains("/responses") {
            return .responses
        }
        if lower.contains("/messages") {
            return .anthropic
        }
        return .chatCompletions
    }
}

struct AIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = (try? container.decodeIfPresent(Message.self, forKey: .message)).flatMap { $0 }
        }
    }

    struct Message: Decodable {
        let content: String?
        let reasoningContent: String?
        let toolCalls: [ToolCall]?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
            case toolCalls = "tool_calls"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = (try? container.decodeIfPresent(String.self, forKey: .content)).flatMap { $0 }
            reasoningContent = (try? container.decodeIfPresent(String.self, forKey: .reasoningContent)).flatMap { $0 }
            toolCalls = (try? container.decodeIfPresent([ToolCall].self, forKey: .toolCalls)).flatMap { $0 }
        }
    }

    struct ToolCall: Decodable {
        let id: String?
        let type: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case id
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? container.decodeIfPresent(String.self, forKey: .id)).flatMap { $0 }
            type = (try? container.decodeIfPresent(String.self, forKey: .type)).flatMap { $0 }
        }
    }

    /// Tolerant fallback: content trim non-empty → dùng, else reasoning trim non-empty → dùng, else nil.
    var resolvedText: String? {
        let trimmedContent = choices.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedContent, !trimmedContent.isEmpty {
            return trimmedContent
        }
        let trimmedReasoning = choices.first?.message?.reasoningContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedReasoning, !trimmedReasoning.isEmpty {
            return trimmedReasoning
        }
        return nil
    }
}

/// Responses-family response (`/responses`): prefer `output_text`, else walk `output[]`.
struct AIResponsesResponse: Decodable {
    let outputText: String?
    let output: [OutputItem]?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
        case status
    }

    struct OutputItem: Decodable {
        let type: String?
        let content: [ContentBlock]?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = (try? container.decodeIfPresent(String.self, forKey: .type)).flatMap { $0 }
            content = (try? container.decodeIfPresent([ContentBlock].self, forKey: .content)).flatMap { $0 }
        }
    }

    struct ContentBlock: Decodable {
        let type: String?
        let text: String?
        let refusal: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case text
            case refusal
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = (try? container.decodeIfPresent(String.self, forKey: .type)).flatMap { $0 }
            text = (try? container.decodeIfPresent(String.self, forKey: .text)).flatMap { $0 }
            refusal = (try? container.decodeIfPresent(String.self, forKey: .refusal)).flatMap { $0 }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputText = (try? container.decodeIfPresent(String.self, forKey: .outputText)).flatMap { $0 }
        output = (try? container.decodeIfPresent([OutputItem].self, forKey: .output)).flatMap { $0 }
        status = (try? container.decodeIfPresent(String.self, forKey: .status)).flatMap { $0 }
    }

    /// Prefer `output_text` trim non-empty, else concatenate message `output_text` blocks with "" then trim.
    var resolvedText: String? {
        let trimmed = outputText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        guard let output else { return nil }
        var combined = ""
        for item in output where item.type == "message" {
            for block in item.content ?? [] where block.type == "output_text" {
                guard let text = block.text,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                combined += text
            }
        }
        let result = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

/// Anthropic-family response (`/messages`): join `type == "text"` blocks, ignore thinking/tool_use.
struct AIAnthropicResponse: Decodable {
    let content: [ContentBlock]?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }

    struct ContentBlock: Decodable {
        let type: String?
        let text: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case text
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = (try? container.decodeIfPresent(String.self, forKey: .type)).flatMap { $0 }
            text = (try? container.decodeIfPresent(String.self, forKey: .text)).flatMap { $0 }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = (try? container.decodeIfPresent([ContentBlock].self, forKey: .content)).flatMap { $0 }
        stopReason = (try? container.decodeIfPresent(String.self, forKey: .stopReason)).flatMap { $0 }
    }

    var resolvedText: String? {
        guard let content else { return nil }
        var combined = ""
        for block in content where block.type == "text" {
            guard let text = block.text,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            combined += text
        }
        let result = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

/// Unified resolver: decode the struct matching `family` and return its `resolvedText`.
enum AIUnifiedResponse {
    static func resolve(data: Data, family: AIEndpointFamily) -> String? {
        let decoder = JSONDecoder()
        // swiftlint:disable switch_case_alignment
        switch family {
            case .chatCompletions:
                guard let decoded = try? decoder.decode(AIChatResponse.self, from: data) else { return nil }
                return decoded.resolvedText
            case .responses:
                guard let decoded = try? decoder.decode(AIResponsesResponse.self, from: data) else { return nil }
                return decoded.resolvedText
            case .anthropic:
                guard let decoded = try? decoder.decode(AIAnthropicResponse.self, from: data) else { return nil }
                return decoded.resolvedText
        }
        // swiftlint:enable switch_case_alignment
    }
}

enum AIClientError: Error, LocalizedError {
    case noResponse
    case httpError(Int, String)

    var errorDescription: String? {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .noResponse:
                return "no response from AI service."
            case let .httpError(code, message):
                return "AI processing failed. (\(code) \(message))"
        }
        // swiftlint:enable switch_case_alignment
    }
}
