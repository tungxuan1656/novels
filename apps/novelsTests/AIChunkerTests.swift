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
}
