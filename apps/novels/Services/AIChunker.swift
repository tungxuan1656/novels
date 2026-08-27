import Foundation

enum AIChunker {
    static func chunk(text: String, size: Int) -> [String] {
        guard !text.isEmpty else {
            return []
        }
        let chunkSize = max(1, size)
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[start ..< end]))
            start = end
        }
        return result
    }
}
