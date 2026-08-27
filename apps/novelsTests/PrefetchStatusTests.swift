@testable import novels
import XCTest

final class PrefetchStatusTests: XCTestCase {
    func testIdleDefaults() {
        let status = PrefetchStatus.idle
        XCTAssertFalse(status.isRunning)
        XCTAssertNil(status.currentBookId)
        XCTAssertEqual(status.totalChapters, 0)
        XCTAssertEqual(status.processedChapters, 0)
        XCTAssertTrue(status.errors.isEmpty)
    }

    func testEquality() {
        var first = PrefetchStatus.idle
        first.isRunning = true
        first.currentBookId = "slug"
        var second = first
        XCTAssertEqual(first, second)
        second.errors.append("oops")
        XCTAssertNotEqual(first, second)
    }
}
