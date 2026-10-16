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

    func testWaitForCompletionDoesNotStartIdleWork() async {
        let manager = PrefetchManager()
        let status = await manager.waitForCompletion()
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(status.processedChapters, 0)
    }

    func testExplicitCancellationMakesWaiterReturnCancelledState() async {
        let manager = PrefetchManager()
        await manager.cancel(reason: "unitTest")
        let status = await manager.waitForCompletion()
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(status.message, "Đã hủy")
    }
}
