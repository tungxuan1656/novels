import Foundation
@testable import novels
import XCTest

@MainActor
final class BilingualChapterTests: XCTestCase {
    func testRoundTripAndReorderedResponse() throws {
        let pairs = [pair("p001"), pair("p002")]
        let chapter = try BilingualChapter(paragraphs: pairs)
        XCTAssertEqual(try BilingualChapter.decode(chapter.encoded()), chapter)
        let response = try responseText(Array(pairs.reversed()))
        XCTAssertEqual(try BilingualChapter.decodeResponse(response, expectedIDs: pairs.map(\.id)), pairs)
        XCTAssertNoThrow(try BilingualChapter.outputSchema.object(strict: true))
    }

    func testInvalidResponsesRejectRatherThanRepair() throws {
        // swiftlint:disable trailing_comma
        let fixtures = try [
            "{}", "[]", "not JSON", "```json\n{}\n```",
            #"{"paragraphs":[{"id":"p001","vi":"text"}]}"#,
            #"{"paragraphs":[{"id":"p001","vi":42,"en":"text"}]}"#,
            responseText([]),
            responseText([pair("p001", en: " \n")]),
            responseText([pair("p001", vi: "")]),
            responseText([pair("p001"), pair("p001")]),
            responseText([pair("p002")]),
            responseText([pair("p001"), pair("extra")]),
        ]
        // swiftlint:enable trailing_comma
        for fixture in fixtures {
            XCTAssertThrowsError(try BilingualChapter.decodeResponse(fixture, expectedIDs: ["p001"]))
        }
        XCTAssertThrowsError(try BilingualChapter.decode(#"{"version":2,"paragraphs":[]}"#))
        XCTAssertThrowsError(try BilingualChapter.decode(#"{"paragraphs":[]}"#))
    }

    func testSourcePackingNormalizesAndPreservesParagraphUnits() throws {
        let chunks = BilingualSourceChunker.chunks(text: " first\r\nline \r\n\r\n second \r\rthird ", size: 30)
        let units = chunks.flatMap(\.paragraphs)
        XCTAssertEqual(units.map(\.text), ["first\nline", "second", "third"])
        XCTAssertEqual(units.map(\.id), ["p001", "p002", "p003"])
        XCTAssertEqual(chunks.count, 1)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(chunks[0].encoded().utf8)) as? [String: Any])
        XCTAssertEqual((object["paragraphs"] as? [[String: String]])?.first?["id"], "p001")
        XCTAssertTrue(BilingualSourceChunker.chunks(text: " \n\r\n ", size: 500).isEmpty)
    }

    func testOversizedParagraphsKeepOrderAndBoundaries() {
        let text = "First sentence. Second sentence! Third sentence?"
        let chunks = BilingualSourceChunker.chunks(text: text + "\n\nTail.", size: 19)
        let units = chunks.flatMap(\.paragraphs)
        XCTAssertEqual(units.map(\.text), ["First sentence.", "Second sentence!", "Third sentence?", "Tail."])
        XCTAssertEqual(Set(units.map(\.id)).count, units.count)
        XCTAssertTrue(units.allSatisfy { $0.text.count <= 19 })
        let long = BilingualSourceChunker.chunks(text: "abcdef ghijkl mnopqr", size: 8).flatMap(\.paragraphs)
        XCTAssertEqual(long.map(\.text), ["abcdef", "ghijkl", "mnopqr"])
    }

    private func pair(_ id: String, vi: String = "source", en: String = "English") -> BilingualParagraph {
        BilingualParagraph(id: id, vi: vi, en: en)
    }

    private func responseText(_ pairs: [BilingualParagraph]) throws -> String {
        let data = try JSONEncoder().encode(["paragraphs": pairs])
        return try XCTUnwrap(String(bytes: data, encoding: .utf8))
    }
}
