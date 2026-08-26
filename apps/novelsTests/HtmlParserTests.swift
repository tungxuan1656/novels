@testable import novels
import XCTest

final class HtmlParserTests: XCTestCase {
    func testParseSingleParagraph() {
        let html = "<p>Hello <b>world</b></p>"
        let blocks = HtmlParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].spans.count, 2)
        XCTAssertEqual(blocks[0].spans[0].text, "Hello ")
        XCTAssertEqual(blocks[0].spans[0].kind, .body)
        XCTAssertEqual(blocks[0].spans[1].text, "world")
        XCTAssertEqual(blocks[0].spans[1].kind, .bold)
    }

    func testParseHeadingAndBr() {
        let html = "<h2>Title</h2><p>Line1<br>Line2</p>"
        let blocks = HtmlParser.parse(html: html)
        XCTAssertEqual(blocks[0].isHeading, true)
        XCTAssertEqual(blocks[0].headingLevel, 2)
        XCTAssertEqual(blocks[0].spans[0].text, "Title")
        XCTAssertEqual(blocks[1].spans.map { $0.text }.joined(separator: "|"), "Line1|Line2")
    }

    func testParseNestedBoldItalicAndWhitespace() {
        let html = "<p>  A <b><i>BC</i> D</b>  E  </p>"
        let blocks = HtmlParser.parse(html: html)
        XCTAssertEqual(blocks[0].spans[1].kind, .boldItalic)
        XCTAssertEqual(blocks[0].spans[1].text, "BC")
        XCTAssertEqual(blocks[0].spans.map { $0.text }.joined(), "A BC D E")
    }

    func testParseEmptyAndDivSpanPassthrough() {
        XCTAssertEqual(HtmlParser.parse(html: ""), [])
        XCTAssertEqual(HtmlParser.parse(html: "<div><span>Hi</span></div>")[0].spans[0].text, "Hi")
    }

    func testParseHeadingLevels() {
        for level in 1 ... 6 {
            XCTAssertEqual(
                HtmlParser.parse(html: "<h\(level)>T\(level)</h\(level)>")[0].headingLevel,
                level
            )
        }
    }
}
