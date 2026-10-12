import Foundation

nonisolated struct BilingualParagraph: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let vi: String
    let en: String
}

nonisolated struct BilingualChapter: Codable, Sendable, Equatable {
    let version: Int
    let paragraphs: [BilingualParagraph]

    init(paragraphs: [BilingualParagraph]) throws {
        version = 1
        self.paragraphs = paragraphs
        try validate()
    }

    static func decode(_ text: String) throws -> Self {
        let chapter = try JSONDecoder().decode(Self.self, from: Data(text.utf8))
        try chapter.validate()
        return chapter
    }

    func encoded() throws -> String {
        try validate()
        let data = try JSONEncoder().encode(self)
        guard let text = String(bytes: data, encoding: .utf8) else { throw AIClientError.invalidStructuredOutput }
        return text
    }

    static func decodeResponse(_ text: String, expectedIDs: [String]) throws -> [BilingualParagraph] {
        let response = try JSONDecoder().decode(Response.self, from: Data(text.utf8))
        let chapter = try Self(paragraphs: response.paragraphs)
        guard chapter.paragraphs.count == expectedIDs.count,
              Set(chapter.paragraphs.map(\.id)) == Set(expectedIDs)
        else {
            throw AIClientError.invalidStructuredOutput
        }
        let byID = Dictionary(uniqueKeysWithValues: chapter.paragraphs.map { ($0.id, $0) })
        return try expectedIDs.map { id in
            guard let paragraph = byID[id] else { throw AIClientError.invalidStructuredOutput }
            return paragraph
        }
    }

    private func validate() throws {
        guard version == 1, !paragraphs.isEmpty,
              Set(paragraphs.map(\.id)).count == paragraphs.count,
              paragraphs.allSatisfy({
                  !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && !$0.vi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && !$0.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              })
        else {
            throw AIClientError.invalidStructuredOutput
        }
    }

    private struct Response: Decodable {
        let paragraphs: [BilingualParagraph]
    }

    static let outputSchema = AIOutputSchema(
        name: "bilingual_paragraphs",
        json: """
        {"type":"object","properties":{"paragraphs":{"type":"array","items":{
        "type":"object","properties":{"id":{"type":"string"},"vi":{"type":"string"},"en":{"type":"string"}},
        "required":["id","vi","en"],"additionalProperties":false}}},
        "required":["paragraphs"],"additionalProperties":false}
        """
    )
}
