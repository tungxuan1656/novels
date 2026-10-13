import Foundation

nonisolated struct BilingualSourceParagraph: Codable, Sendable, Equatable {
    let id: String
    let text: String
}

nonisolated struct BilingualSourceChunk: Sendable {
    let paragraphs: [BilingualSourceParagraph]

    func encoded() throws -> String {
        let data = try JSONEncoder().encode(Input(paragraphs: paragraphs))
        guard let text = String(bytes: data, encoding: .utf8) else { throw AIClientError.invalidStructuredOutput }
        return text
    }

    private struct Input: Encodable {
        let paragraphs: [BilingualSourceParagraph]
    }
}

enum BilingualSourceChunker {
    static func chunks(text: String, size: Int) -> [BilingualSourceChunk] {
        let budget = max(1, size)
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let units = paragraphs.flatMap { paragraph in
            paragraph.count <= budget ? [paragraph] : AIChunker.chunk(text: paragraph, size: budget)
        }
        var chunks: [BilingualSourceChunk] = []
        var pending: [BilingualSourceParagraph] = []
        var count = 0
        for (index, text) in units.enumerated() {
            if !pending.isEmpty, count + 2 + text.count > budget {
                chunks.append(BilingualSourceChunk(paragraphs: pending))
                pending = []
                count = 0
            }
            count += (pending.isEmpty ? 0 : 2) + text.count
            pending.append(BilingualSourceParagraph(id: String(format: "p%03d", index + 1), text: text))
        }
        if !pending.isEmpty {
            chunks.append(BilingualSourceChunk(paragraphs: pending))
        }
        return chunks
    }
}
