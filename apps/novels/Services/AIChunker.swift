import Foundation

enum AIChunker {
    static func chunk(text: String, size: Int) -> [String] {
        let budget = max(1, size)
        let paragraphs = splitParagraphs(text)
        var result: [String] = []
        var pending: [String] = []
        for paragraph in paragraphs {
            if paragraph.count <= budget {
                pending.append(paragraph)
                continue
            }
            result += pack(units: pending, separator: "\n\n", budget: budget)
            pending = []
            result += chunkParagraph(paragraph, budget: budget)
        }
        result += pack(units: pending, separator: "\n\n", budget: budget)
        return result
    }

    private static func splitParagraphs(_ text: String) -> [String] {
        guard !text.isEmpty else {
            return []
        }
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func chunkParagraph(_ paragraph: String, budget: Int) -> [String] {
        var units: [String] = []
        for sentence in splitSentences(paragraph) {
            if sentence.count <= budget {
                units.append(sentence)
            } else {
                units += splitLongSentence(sentence, budget: budget)
            }
        }
        if units.isEmpty {
            units = splitLongSentence(paragraph, budget: budget)
        }
        return pack(units: units, separator: " ", budget: budget)
    }

    private static func splitSentences(_ paragraph: String) -> [String] {
        let closers: Set<Character> = ["”", "’", "\"", "'", ")", "]"]
        var sentences: [String] = []
        var start = paragraph.startIndex
        var cursor = paragraph.startIndex
        while cursor < paragraph.endIndex {
            if isSentenceTerminal(at: cursor, in: paragraph) {
                var end = paragraph.index(after: cursor)
                while end < paragraph.endIndex, closers.contains(paragraph[end]) {
                    end = paragraph.index(after: end)
                }
                if end == paragraph.endIndex || paragraph[end].isWhitespace {
                    appendSlice(paragraph[start ..< end], to: &sentences)
                    start = end
                    cursor = end
                    continue
                }
            }
            cursor = paragraph.index(after: cursor)
        }
        appendSlice(paragraph[start ..< paragraph.endIndex], to: &sentences)
        return sentences
    }

    private static func isSentenceTerminal(at index: String.Index, in text: String) -> Bool {
        let terminals: Set<Character> = [".", "!", "?", "…"]
        guard terminals.contains(text[index]) else {
            return false
        }
        return !isDecimalDot(at: index, in: text) && !isAbbreviationDot(at: index, in: text)
    }

    private static func isDecimalDot(at index: String.Index, in text: String) -> Bool {
        guard text[index] == ".",
              index > text.startIndex,
              text.index(after: index) < text.endIndex
        else {
            return false
        }
        return text[text.index(before: index)].isNumber && text[text.index(after: index)].isNumber
    }

    private static func isAbbreviationDot(at index: String.Index, in text: String) -> Bool {
        guard text[index] == "." else {
            return false
        }
        let next = text.index(after: index)
        if next < text.endIndex, !text[next].isWhitespace {
            return false
        }
        var start = index
        while start > text.startIndex, text[text.index(before: start)].isLetter {
            start = text.index(before: start)
        }
        let word = text[start ..< index]
        guard (1 ... 2).contains(word.count), let first = word.first, first.isUppercase else {
            return false
        }
        return true
    }

    private static func appendSlice(_ slice: Substring, to sentences: inout [String]) {
        let trimmed = slice.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            sentences.append(trimmed)
        }
    }

    private static func splitLongSentence(_ sentence: String, budget: Int) -> [String] {
        var pieces: [String] = []
        var rest = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        while !rest.isEmpty {
            if rest.count <= budget {
                pieces.append(rest)
                break
            }
            let cut = rest.index(rest.startIndex, offsetBy: budget)
            if let space = rest[..<cut].lastIndex(where: { $0.isWhitespace }) {
                let piece = String(rest[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty {
                    pieces.append(piece)
                }
                rest = String(rest[rest.index(after: space)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                pieces.append(String(rest[..<cut]))
                rest = String(rest[cut...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return pieces
    }

    private static func pack(units: [String], separator: String, budget: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for unit in units {
            if current.isEmpty {
                current = unit
            } else if current.count + separator.count + unit.count <= budget {
                current += separator + unit
            } else {
                chunks.append(current)
                current = unit
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}
