import Foundation

enum HtmlParser {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parse(html: String) -> [TextBlock] {
        var blocks: [TextBlock] = []
        var currentSpans: [TextSpan] = []
        var isHeadingBlock = false
        // swiftlint:disable:next implicit_optional_initialization
        var headingLevel: Int? = nil
        var boldDepth = 0
        var italicDepth = 0
        var currentText = ""
        var insideBlock = false

        func currentKind() -> TextSpan.Kind {
            if let level = headingLevel {
                return .heading(level: level)
            }
            if boldDepth > 0, italicDepth > 0 {
                return .boldItalic
            }
            if boldDepth > 0 {
                return .bold
            }
            if italicDepth > 0 {
                return .italic
            }
            return .body
        }

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
            if currentSpans.isEmpty, textToEmit.hasPrefix(" ") {
                textToEmit.removeFirst()
                if textToEmit.isEmpty {
                    return
                }
            }
            if textToEmit.isEmpty {
                return
            }
            let span = TextSpan(text: textToEmit, kind: currentKind(), isLineBreak: false)
            currentSpans.append(span)
        }

        func emitBlock() {
            if currentSpans.isEmpty {
                return
            }
            if let last = currentSpans.last, last.text.hasSuffix(" ") {
                var trimmed = last.text
                while trimmed.hasSuffix(" ") {
                    trimmed.removeLast()
                }
                if trimmed.isEmpty {
                    currentSpans.removeLast()
                } else {
                    currentSpans[currentSpans.count - 1].text = trimmed
                }
            }
            let nonEmpty = currentSpans.filter { !$0.text.isEmpty }
            if nonEmpty.isEmpty {
                currentSpans = []
                return
            }
            let block = TextBlock(spans: nonEmpty, isHeading: isHeadingBlock, headingLevel: headingLevel)
            blocks.append(block)
            currentSpans = []
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
                // Remove trailing "/" for cases like "br/"
                if tagName.hasSuffix("/") {
                    tagName = String(tagName.dropLast())
                }

                if tagName == "br" {
                    flush()
                } else if tagName == "b" || tagName == "strong" {
                    flush()
                    if isClosing {
                        boldDepth = max(0, boldDepth - 1)
                    } else {
                        boldDepth += 1
                    }
                } else if tagName == "i" || tagName == "em" {
                    flush()
                    if isClosing {
                        italicDepth = max(0, italicDepth - 1)
                    } else {
                        italicDepth += 1
                    }
                } else if tagName == "p" || tagName == "div" {
                    if isClosing {
                        flush()
                        emitBlock()
                        isHeadingBlock = false
                        headingLevel = nil
                        insideBlock = false
                    } else {
                        if insideBlock, !currentSpans.isEmpty {
                            flush()
                            emitBlock()
                            isHeadingBlock = false
                            headingLevel = nil
                            insideBlock = false
                        }
                        insideBlock = true
                        isHeadingBlock = false
                        headingLevel = nil
                    }
                } else if tagName.count == 2, tagName.hasPrefix("h"), let levelChar = tagName.last,
                          let level = Int(String(levelChar)), (1 ... 6).contains(level)
                { // swiftlint:disable:this opening_brace
                    if isClosing {
                        flush()
                        emitBlock()
                        isHeadingBlock = false
                        headingLevel = nil
                        insideBlock = false
                    } else {
                        if insideBlock, !currentSpans.isEmpty {
                            flush()
                            emitBlock()
                        }
                        insideBlock = true
                        isHeadingBlock = true
                        headingLevel = level
                    }
                } else if tagName == "span" {
                    // passthrough, no style change
                } else {
                    // unknown tag, ignore
                }

                index = html.index(after: closeIndex)
            } else {
                let nextTag = html[index...].firstIndex(of: "<") ?? html.endIndex
                currentText += String(html[index ..< nextTag])
                index = nextTag
            }
        }

        flush()
        if !currentSpans.isEmpty {
            if let last = currentSpans.last, last.text.hasSuffix(" ") {
                var trimmed = last.text
                while trimmed.hasSuffix(" ") {
                    trimmed.removeLast()
                }
                if trimmed.isEmpty {
                    currentSpans.removeLast()
                } else {
                    currentSpans[currentSpans.count - 1].text = trimmed
                }
            }
            let nonEmpty = currentSpans.filter { !$0.text.isEmpty }
            if !nonEmpty.isEmpty {
                let block = TextBlock(spans: nonEmpty, isHeading: isHeadingBlock, headingLevel: headingLevel)
                blocks.append(block)
            }
        }

        // Filter empty blocks
        return blocks.filter { !$0.spans.isEmpty }
    }
}
