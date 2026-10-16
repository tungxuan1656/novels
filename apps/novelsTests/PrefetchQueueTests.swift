@testable import novels
import XCTest

final class PrefetchQueueTests: XCTestCase {
    func testExhaustedFailureIsAdmittedByNextAndPreviousWindows() async {
        for current in [3, 2] {
            let manager = PrefetchManager()
            _ = await manager.ensureWindow(cur: 2, appliedN: 3, total: 10, misses: [4])
            let initial = await manager.nextChapter(generation: 0)
            XCTAssertEqual(initial, 4)
            var errors: [String] = []
            await manager.requeueOrRecord(number: 4, message: "failed", errors: &errors, generation: 0)
            let retry = await manager.nextChapter(generation: 0)
            XCTAssertEqual(retry, 4)
            await manager.requeueOrRecord(number: 4, message: "failed", errors: &errors, generation: 0)
            XCTAssertEqual(errors, ["failed"])

            _ = await manager.ensureWindow(cur: current, appliedN: 3, total: 10, misses: [4])
            let recovered = await manager.nextChapter(generation: 0)
            XCTAssertEqual(recovered, 4, "Navigation must re-admit a settled, uncached failure")
        }
    }

    func testRetryIsBoundedEvenAfterNavigationReadmitsFailure() async {
        let manager = PrefetchManager()
        _ = await manager.ensureWindow(cur: 2, appliedN: 3, total: 10, misses: [4])
        var errors: [String] = []
        for _ in 0 ..< 2 {
            let number = await manager.nextChapter(generation: 0)
            XCTAssertEqual(number, 4)
            await manager.requeueOrRecord(number: 4, message: "failed", errors: &errors, generation: 0)
        }
        let drained = await manager.nextChapter(generation: 0)
        XCTAssertNil(drained)
        _ = await manager.ensureWindow(cur: 3, appliedN: 3, total: 10, misses: [4])
        let readmitted = await manager.nextChapter(generation: 0)
        XCTAssertEqual(readmitted, 4)
        await manager.requeueOrRecord(number: 4, message: "failed", errors: &errors, generation: 0)
        let stopped = await manager.nextChapter(generation: 0)
        XCTAssertNil(stopped)
    }

    func testSupersededFailureCannotRequeueIntoReplacementBatch() async {
        let manager = PrefetchManager()
        _ = await manager.ensureWindow(cur: 2, appliedN: 3, total: 10, misses: [4])
        let old = await manager.nextChapter(generation: 0)
        XCTAssertEqual(old, 4)
        await manager.cancel()
        _ = await manager.ensureWindow(cur: 3, appliedN: 3, total: 10, misses: [5])
        let replacement = await manager.nextChapter(generation: 1)
        XCTAssertEqual(replacement, 5)
        var errors: [String] = []
        await manager.requeueOrRecord(number: 4, message: "stale", errors: &errors, generation: 0)
        _ = await manager.ensureWindow(cur: 3, appliedN: 3, total: 10, misses: [5, 6])
        let next = await manager.nextChapter(generation: 1)
        let drained = await manager.nextChapter(generation: 1)
        XCTAssertEqual(next, 6)
        XCTAssertNil(drained)
        XCTAssertTrue(errors.isEmpty)
    }

    func testRunningChapterIsNotDuplicatedByNavigation() async {
        let manager = PrefetchManager()
        _ = await manager.ensureWindow(cur: 2, appliedN: 3, total: 10, misses: [4, 5])
        let initial = await manager.nextChapter(generation: 0)
        XCTAssertEqual(initial, 4)
        _ = await manager.ensureWindow(cur: 3, appliedN: 3, total: 10, misses: [4, 5, 6])
        let next = await manager.nextChapter(generation: 0)
        let tail = await manager.nextChapter(generation: 0)
        let drained = await manager.nextChapter(generation: 0)
        XCTAssertEqual(next, 5)
        XCTAssertEqual(tail, 6)
        XCTAssertNil(drained)
    }
}
