@testable import novels
import XCTest

final class AIChunkerTests: XCTestCase {
    func testSingleChunkShortText() {
        XCTAssertEqual(AIChunker.chunk(text: "hello", size: 1300).count, 1)
        XCTAssertEqual(AIChunker.chunk(text: "hello", size: 1300).first, "hello")
    }

    func testSplitsAtBoundary() {
        let text = String(repeating: "a", count: 2600)
        let chunks = AIChunker.chunk(text: text, size: 1300)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].count, 1300)
        XCTAssertEqual(chunks[1].count, 1300)
        XCTAssertEqual(chunks.joined(), text)
    }

    func testEmptyReturnsOneEmptyOrZero() {
        XCTAssertTrue(AIChunker.chunk(text: "", size: 1300).isEmpty || AIChunker.chunk(text: "", size: 1300) == [""])
    }

    func testPreservesOrder() {
        let text = "abcdefghijklmnopqrstuvwxyz"
        let chunks = AIChunker.chunk(text: text, size: 5)
        XCTAssertEqual(chunks, ["abcde", "fghij", "klmno", "pqrst", "uvwxy", "z"])
    }

    func testPacksShortParagraphsIntoOneChunk() {
        let text = "Para one.\n\nPara two.\n\nPara three."
        let chunks = AIChunker.chunk(text: text, size: 1300)
        XCTAssertEqual(chunks, [text])
    }

    func testLoneNewlineIsBoundary() {
        XCTAssertEqual(AIChunker.chunk(text: "hello\nworld", size: 1300), ["hello\n\nworld"])
    }

    func testParagraphThatFitsIsNeverSplit() {
        let first = "Alpha beta gamma. Delta epsilon."
        let second = "Zeta eta theta. Iota kappa."
        let size = first.count + second.count + 1
        let chunks = AIChunker.chunk(text: first + "\n\n" + second, size: size)
        XCTAssertEqual(chunks, [first, second])
    }

    func testOversizeParagraphSplitsOnlyAtSentenceBoundaries() {
        let first = "First sentence is here."
        let second = "Second sentence follows."
        let third = "Third sentence ends it."
        let budget = "\(first) \(second)".count
        let chunks = AIChunker.chunk(text: "\(first) \(second) \(third)", size: budget)
        XCTAssertEqual(chunks, ["\(first) \(second)", third])
        for sentence in [first, second, third] {
            XCTAssertEqual(chunks.filter { $0.contains(sentence) }.count, 1, sentence)
        }
    }

    func testOversizeSentenceSplitsOnlyAtSpaces() {
        let words = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"]
        let sentence = words.joined(separator: " ")
        let chunks = AIChunker.chunk(text: sentence, size: 12)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 12)
            for word in chunk.split(separator: " ") {
                XCTAssertTrue(words.contains(String(word)), String(word))
            }
        }
        XCTAssertEqual(chunks.joined(separator: " "), sentence)
    }

    func testJoinedChunksReconstructNormalizedText() {
        let first = "First paragraph here."
        let second = "Second paragraph here."
        let third = "Third paragraph here."
        let text = [first, second, third].joined(separator: "\n\n")
        let size = [first, second].joined(separator: "\n\n").count
        let chunks = AIChunker.chunk(text: text, size: size)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, size)
            XCTAssertEqual(chunk, chunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        XCTAssertEqual(chunks.joined(separator: "\n\n"), text)
    }

    func testDialogueClosersStickToLeft() {
        let curly = "Hắn hỏi “Ngươi là ai?” Cô ấy đáp."
        let curlyLead = "Hắn hỏi “Ngươi là ai?”"
        let chunks = AIChunker.chunk(text: curly, size: curlyLead.count)
        XCTAssertEqual(chunks, [curlyLead, "Cô ấy đáp."])
        XCTAssertEqual(chunks.filter { $0.contains("“Ngươi là ai?”") }.count, 1)
        let straight = "He said \"Go!\" She stayed."
        let straightLead = "He said \"Go!\""
        let straightChunks = AIChunker.chunk(text: straight, size: straightLead.count)
        XCTAssertEqual(straightChunks, [straightLead, "She stayed."])
        let loud = "Cô hét “Đi đi!” Anh cười."
        let loudLead = "Cô hét “Đi đi!”"
        XCTAssertEqual(AIChunker.chunk(text: loud, size: loudLead.count), [loudLead, "Anh cười."])
        let period = "Anh nói “Ừ.” Cô đi."
        let periodLead = "Anh nói “Ừ.”"
        XCTAssertEqual(AIChunker.chunk(text: period, size: periodLead.count), [periodLead, "Cô đi."])
        for chunk in chunks + straightChunks {
            XCTAssertFalse(chunk.hasSuffix("“"), chunk)
            XCTAssertFalse(chunk.hasPrefix("”"), chunk)
        }
    }

    func testEllipsisCloserSplitsAfterCloser() {
        let lead = "“Ta không...”"
        let text = "\(lead) Hắn dừng lại."
        let chunks = AIChunker.chunk(text: text, size: lead.count)
        XCTAssertEqual(chunks, [lead, "Hắn dừng lại."])
        XCTAssertEqual(chunks.filter { $0.contains("...") }.count, 1)
        XCTAssertFalse(chunks[1].hasPrefix("”"))
    }

    func testQuoteAttributionPacksTogether() {
        let lead = "“Đi đi!” Diệp Thiên nói."
        let text = "\(lead) Mọi người cười."
        let chunks = AIChunker.chunk(text: text, size: lead.count)
        XCTAssertEqual(chunks, [lead, "Mọi người cười."])
    }

    func testDecimalDotNeverSplits() {
        let text = "Nó nặng 3.14 kg và dài."
        let chunks = AIChunker.chunk(text: text, size: 12)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.filter { $0.contains("3.14") }.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 12)
        }
    }

    func testAbbreviationDotNeverSplits() {
        let lead = "Anh A. đi rồi."
        XCTAssertEqual(
            AIChunker.chunk(text: "\(lead) Hết chuyện.", size: lead.count),
            [lead, "Hết chuyện."]
        )
        let mister = "Mr. X đi rồi."
        XCTAssertEqual(
            AIChunker.chunk(text: "\(mister) Hết.", size: mister.count),
            [mister, "Hết."]
        )
    }

    func testRealChapter16RespectsQuotesAndBudget() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
        var current = fileURL.deletingLastPathComponent()
        var root = current
        for _ in 0 ..< 6 {
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj").path
            ) {
                root = current
                break
            }
            current = current.deletingLastPathComponent()
        }
        let zipURL = root.appendingPathComponent("docs/samples/van-gioi-chi-rut-thuong-he-thong.zip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path), zipURL.path)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        try FileManager.default.unzipItem(at: zipURL, to: work)
        let htmlURL = work.appendingPathComponent(
            "van-gioi-chi-rut-thuong-he-thong/chapters/chapter-16.html"
        )
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let text = Self.stripTags(html)
        XCTAssertGreaterThan(text.count, 1000)
        let budget = 500
        let chunks = AIChunker.chunk(text: text, size: budget)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, budget, chunk)
            XCTAssertEqual(chunk, chunk.trimmingCharacters(in: .whitespacesAndNewlines), chunk)
            XCTAssertEqual(
                chunk.filter { $0 == "“" }.count,
                chunk.filter { $0 == "”" }.count,
                chunk
            )
            XCTAssertFalse(chunk.hasSuffix("“"), chunk)
            XCTAssertFalse(chunk.hasPrefix("”"), chunk)
            for token in chunk.split(whereSeparator: \.isWhitespace) {
                XCTAssertTrue(text.contains(String(token)), String(token))
            }
        }
    }

    private static func stripTags(_ html: String) -> String {
        var text = html
        for (pattern, template) in [("<br[^>]*>", "\n"), ("<[^>]+>", "")] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: template
                )
            }
        }
        return text
    }
}
