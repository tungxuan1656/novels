@testable import novels
import XCTest

@MainActor
final class ToastCenterTests: XCTestCase {
    func testShowAndAutoDismiss() async throws {
        let center = ToastCenter()
        center.show("Không tìm thấy sách", type: .error)
        XCTAssertEqual(center.current?.message, "Không tìm thấy sách")
        XCTAssertEqual(center.current?.type, .error)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(center.current)
    }

    func testDismissClears() {
        let center = ToastCenter()
        center.show("Đã xóa", type: .success)
        center.dismiss()
        XCTAssertNil(center.current)
    }
}
