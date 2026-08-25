import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testLibraryHeaderExists() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Thư viện"].waitForExistence(timeout: 5))
    }
}
