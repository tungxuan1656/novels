import Foundation

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
