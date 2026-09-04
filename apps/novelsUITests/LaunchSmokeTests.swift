import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testLibraryHeaderExists() {
        let app = XCUIApplication()
        app.launchArguments.append("--reset-session")
        app.launch()
        let exists = app.staticTexts["Thư viện"].waitForExistence(timeout: 5)
            || app.navigationBars.element.waitForExistence(timeout: 5)
        XCTAssertTrue(exists)
    }
}
