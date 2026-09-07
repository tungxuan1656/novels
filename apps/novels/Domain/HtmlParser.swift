import Foundation

/// Plain-text chapter parser: one optional title + one body string.
/// The first h1-h6 block wins the title (trimmed, nil when empty);
/// every text run — including mid-chapter headings and b/i content as
/// plain text — appends to the body (no text loss per BR-04).
enum HtmlParser {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parseChapter(html: String) -> (title: String?, body: String) {
        var blocks: [String] = []
        var currentPieces: [Piece] = []
        var isHeadingBlock = false
        // swiftlint:disable:next implicit_optional_initialization
        var title: String? = nil
        var currentText = ""
        var insideBlock = false
        // swiftlint:disable:next implicit_optional_initialization
        var skipTag: String? = nil

        func collapseWhitespace(_ input: String) -> String {
            var result = ""
            result.reserveCapacity(input.count)
            var previousWasSpace = false
            for character in input {
                if character.isWhitespace {
                    if !previousWasSpace {
                        result.append(" ")
                        previousWasSpace = true
                    }
                } else {
                    result.append(character)
                    previousWasSpace = false
                }
            }
            return result
        }

        func decodeEntities(_ input: String) -> String {
            var result = input
            result = result.replacingOccurrences(of: "&amp;", with: "&")
            result = result.replacingOccurrences(of: "&lt;", with: "<")
            result = result.replacingOccurrences(of: "&gt;", with: ">")
            result = result.replacingOccurrences(of: "&quot;", with: "\"")
            result = result.replacingOccurrences(of: "&apos;", with: "'")
            result = result.replacingOccurrences(of: "&nbsp;", with: " ")
            return result
        }

        func flush() {
            if currentText.isEmpty {
                return
            }
            let collapsed = collapseWhitespace(currentText)
            currentText = ""
            if collapsed.trimmingCharacters(in: .whitespaces).isEmpty {
                return
            }
            var textToEmit = collapsed
            if currentPieces.isEmpty, textToEmit.hasPrefix(" ") {
                textToEmit.removeFirst()
                if textToEmit.isEmpty {
                    return
                }
            }
            if textToEmit.isEmpty {
                return
            }
            currentPieces.append(Piece(text: textToEmit, isLineBreak: false))
        }

        func emitBlock() {
            while let first = currentPieces.first, first.isLineBreak {
                currentPieces.removeFirst()
            }
            while let last = currentPieces.last, last.isLineBreak {
                currentPieces.removeLast()
            }
            if currentPieces.isEmpty {
                return
            }
            if let last = currentPieces.last, last.text.hasSuffix(" ") {
                var trimmed = last.text
                while trimmed.hasSuffix(" ") {
                    trimmed.removeLast()
                }
                if trimmed.isEmpty {
                    currentPieces.removeLast()
                } else {
                    currentPieces[currentPieces.count - 1].text = trimmed
                }
            }
            let nonEmpty = currentPieces.filter { !$0.text.isEmpty }
            if nonEmpty.isEmpty {
                currentPieces = []
                return
            }
            let blockText = nonEmpty.map { $0.text }.joined()
            var capturedTitle = false
            if isHeadingBlock, title == nil {
                let candidate = blockText
                    .replacingOccurrences(of: "\n", with: " ")
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
                if !candidate.isEmpty {
                    title = candidate
                    capturedTitle = true
                }
            }
            if !capturedTitle {
                blocks.append(blockText)
            }
            currentPieces = []
        }

        var index = html.startIndex
        while index < html.endIndex {
            if html[index] == "<" {
                guard let closeIndex = html[index...].firstIndex(of: ">") else {
                    currentText += String(html[index...])
                    break
                }
                let rawInside = String(html[html.index(after: index) ..< closeIndex])
                let trimmedInside = rawInside.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerInside = trimmedInside.lowercased()

                var isClosing = false
                var content = lowerInside
                if content.hasPrefix("/") {
                    isClosing = true
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                let firstToken = content.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
                var tagName = firstToken
                if tagName.hasSuffix("/") {
                    tagName = String(tagName.dropLast())
                }

                if let active = skipTag {
                    if isClosing, tagName == active {
                        skipTag = nil
                    }
                    index = html.index(after: closeIndex)
                    continue
                }
                if !isClosing && (tagName == "script" || tagName == "style") {
                    skipTag = tagName
                    index = html.index(after: closeIndex)
                    continue
                }

                if tagName == "br" {
                    flush()
                    if currentPieces.last?.isLineBreak != true {
                        currentPieces.append(Piece(text: "\n\n", isLineBreak: true))
                    }
                } else if tagName == "b" || tagName == "strong" || tagName == "i" || tagName == "em" {
                    // Inline styling is dropped: content stays as plain text.
                    flush()
                } else if tagName == "p" || tagName == "div" {
                    if isClosing {
                        flush()
                        emitBlock()
                        isHeadingBlock = false
                        insideBlock = false
                    } else {
                        if insideBlock, !currentPieces.isEmpty {
                            flush()
                            emitBlock()
                            isHeadingBlock = false
                            insideBlock = false
                        }
                        insideBlock = true
                        isHeadingBlock = false
                    }
                } else if tagName.count == 2, tagName.hasPrefix("h"),
                          let digit = tagName.last?.wholeNumberValue, (1 ... 6).contains(digit)
                { // swiftlint:disable:this opening_brace
                    if isClosing {
                        flush()
                        emitBlock()
                        isHeadingBlock = false
                        insideBlock = false
                    } else {
                        if insideBlock, !currentPieces.isEmpty {
                            flush()
                            emitBlock()
                        }
                        insideBlock = true
                        isHeadingBlock = true
                    }
                } else if tagName == "span" {
                    // passthrough, no style change
                } else {
                    // unknown tag, ignore
                }

                index = html.index(after: closeIndex)
            } else {
                let nextTag = html[index...].firstIndex(of: "<") ?? html.endIndex
                if skipTag == nil {
                    let raw = String(html[index ..< nextTag])
                    currentText += decodeEntities(raw)
                }
                index = nextTag
            }
        }

        flush()
        emitBlock()

        let joined = blocks.joined(separator: "\n\n")
        var normalized = joined.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        let body = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return (title: title, body: body)
    }
}

private struct Piece: Equatable {
    var text: String
    var isLineBreak: Bool = false
}
