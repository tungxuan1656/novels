import Foundation
import NaturalLanguage

nonisolated struct EnglishSentence: Identifiable, Equatable {
    let id: Int
    let text: String
}

nonisolated enum EnglishLearning {
    static func fontSize(vietnamese: Double) -> Double {
        max(12, vietnamese - 2)
    }

    static func sentences(in paragraph: String) -> [EnglishSentence] {
        let text = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.setLanguage(.english)
        tokenizer.string = text
        var parts: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex ..< text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                parts.append(sentence)
            }
            return true
        }
        if parts.isEmpty {
            parts = [text]
        }
        return parts.enumerated().map { EnglishSentence(id: $0.offset, text: $0.element) }
    }

    static func googleURL(for sentence: String) -> URL? {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        // swiftlint:disable trailing_comma
        components.queryItems = [
            URLQueryItem(name: "hl", value: "vi"),
            URLQueryItem(
                name: "q",
                value: "Giải thích bằng tiếng Việt nghĩa, từ vựng và ngữ pháp của câu tiếng Anh: \(text)"
            ),
        ]
        // swiftlint:enable trailing_comma
        // Search treats literal plus signs as spaces unless they are percent-encoded.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
}
