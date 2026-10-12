@testable import novels
import XCTest

@MainActor
final class TestHostTests: XCTestCase {
    func testHostedUnitTestsBypassProductionStartup() {
        XCTAssertTrue(NovelsApp.isUnitTestHost)
    }
}
