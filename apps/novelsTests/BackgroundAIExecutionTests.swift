import Foundation
@testable import novels
import XCTest

@MainActor
final class BackgroundAIExecutionTests: XCTestCase {
    func testContinuedPrefetchIdentifierMatchesInfoPlist() {
        let identifier = ContinuedPrefetchCoordinator.identifier
        XCTAssertEqual(identifier, "com.tungxuan.novels.ai-prefetch.*")
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        XCTAssertTrue(permitted?.contains(identifier) == true)
    }

    func testIdleWorkerCannotBePromoted() async {
        let manager = PrefetchManager()
        let batch = await manager.protectCurrentBatch()
        XCTAssertNil(batch)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning)
    }

    func testCancelledWorkerCannotBePromoted() async {
        let manager = PrefetchManager()
        await manager.cancel(reason: "unitTest")
        let batch = await manager.protectCurrentBatch()
        XCTAssertNil(batch)
        let status = await manager.currentStatus()
        XCTAssertEqual(status.message, "Đã hủy")
    }
}
