import Foundation
@testable import novels
import Observation
import XCTest

@MainActor
final class DiagnosticsObservationTests: XCTestCase {
    func testObservationLoadsExistingRunsBeforeAnyNewEvent() async {
        let start = outcome("run.start")
        let entry = outcome("run.fail", bookId: start.bookId, runId: start.runId)
        await DiagnosticsLog.shared.append(start)
        await DiagnosticsLog.shared.append(entry)
        let store = DiagnosticsStore()
        let observer = Task { await store.observe() }
        defer { observer.cancel() }

        await waitForEntry(entry.id, in: store)
        XCTAssertEqual(store.failedRunCount(bookId: entry.bookId), 1)
    }

    func testVisibleObserverPublishesNewFailuresAndRecovery() async {
        let start = outcome("run.start")
        await DiagnosticsLog.shared.append(start)
        let store = DiagnosticsStore()
        let observer = Task { await store.observe() }
        defer { observer.cancel() }
        await waitForEntry(start.id, in: store)

        let changed = expectation(description: "Observable failed-run count changes")
        withObservationTracking {
            _ = store.failedRunCount(bookId: start.bookId)
        } onChange: {
            changed.fulfill()
        }
        let failed = outcome("run.fail", bookId: start.bookId, runId: start.runId)
        await DiagnosticsLog.shared.append(failed)
        await fulfillment(of: [changed], timeout: 2)
        XCTAssertEqual(store.failedRunCount(bookId: start.bookId), 1)

        let recovered = outcome("run.success", bookId: start.bookId, runId: start.runId)
        await DiagnosticsLog.shared.append(recovered)
        await waitForEntry(recovered.id, in: store)
        XCTAssertEqual(store.failedRunCount(bookId: start.bookId), 0)
    }

    func testDismissedObserverCannotFinishReplacementObserver() async {
        let start = outcome("run.start")
        await DiagnosticsLog.shared.append(start)
        let previousStore = DiagnosticsStore()
        let previous = Task { await previousStore.observe() }
        defer { previous.cancel() }
        await waitForEntry(start.id, in: previousStore)

        let nextStore = DiagnosticsStore()
        let next = Task { await nextStore.observe() }
        defer { next.cancel() }
        await waitForEntry(start.id, in: nextStore)
        previous.cancel()
        await previous.value

        let failed = outcome("run.fail", bookId: start.bookId, runId: start.runId)
        await DiagnosticsLog.shared.append(failed)
        await waitForEntry(failed.id, in: nextStore)
        XCTAssertEqual(nextStore.failedRunCount(bookId: start.bookId), 1)
    }

    func testCachedGroupingTracksEntriesScopeTitlesAndObservation() async {
        let first = outcome("run.start", bookId: "first")
        let second = outcome("run.start", bookId: "second")
        let store = DiagnosticsStore()
        store.entries = [first, second]
        XCTAssertEqual(store.runGroups(bookId: nil).count, 2)
        let titles = ["first": "First title"]
        let initial = store.runGroups(bookId: "first", bookTitles: titles)
        XCTAssertEqual(initial.count, 1)
        XCTAssertTrue(initial[0].title.hasPrefix("First title"))
        XCTAssertEqual(store.runGroups(bookId: "first", bookTitles: titles), initial)

        let changed = expectation(description: "Cache hit keeps tracking source entries")
        withObservationTracking {
            _ = store.runGroups(bookId: "first", bookTitles: titles)
        } onChange: {
            changed.fulfill()
        }
        store.entries.append(outcome("run.fail", bookId: "first", runId: first.runId))
        await fulfillment(of: [changed], timeout: 1)
        XCTAssertEqual(store.runGroups(bookId: "first", bookTitles: titles).first?.status, .failed)
        XCTAssertTrue(store.runGroups(bookId: "first", bookTitles: ["first": "Renamed"])[0].title.hasPrefix("Renamed"))
        XCTAssertEqual(store.runGroups(bookId: "second").first?.status, .processing)
        store.entries.removeAll()
        XCTAssertTrue(store.runGroups(bookId: "first", bookTitles: titles).isEmpty)
    }

    private func waitForEntry(_ id: UUID, in store: DiagnosticsStore) async {
        let deadline = Date().addingTimeInterval(2)
        while !store.entries.contains(where: { $0.id == id }), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(store.entries.contains { $0.id == id })
    }

    private func outcome(_ event: String, bookId: String = UUID().uuidString, runId: UUID? = UUID()) -> LogEntry {
        LogEntry(
            sessionId: DiagnosticsLog.sessionId,
            bookId: bookId,
            chapterNumber: 1,
            mode: "bilingual",
            errorDomain: event == "run.fail" ? NSURLErrorDomain : nil,
            errorCode: event == "run.fail" ? URLError.timedOut.rawValue : nil,
            event: event,
            runId: runId
        )
    }
}
