import SwiftUI

extension View {
    func a11yHitTarget() -> some View {
        frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}

enum A11yHelpers {
    static func cleanedTitle(_ raw: String) -> String {
        var text = raw
        // Strip HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities (mirrors HtmlParser.decodeEntities)
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        // Numeric decimal entities
        text = decodeNumericEntities(text)
        // Collapse whitespace and trim
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeNumericEntities(_ input: String) -> String {
        var result = input
        // Handle &#123; and &#x1A; patterns (basic)
        let pattern = "&#(x?[0-9a-fA-F]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        // Process in reverse to keep indices valid
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let codeRange = Range(match.range(at: 1), in: result)
            else { continue }
            let code = String(result[codeRange])
            var scalarValue: UInt32?
            if code.lowercased().hasPrefix("x") {
                scalarValue = UInt32(code.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(code, radix: 10)
            }
            if let value = scalarValue, let scalar = UnicodeScalar(value) {
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }
        return result
    }
}
