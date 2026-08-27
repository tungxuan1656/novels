import Foundation

struct AIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
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
