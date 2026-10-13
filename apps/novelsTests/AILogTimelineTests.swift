import Foundation
@testable import novels
import XCTest

// swiftlint:disable trailing_comma
final class AILogTimelineTests: XCTestCase {
    func testTimelineOmitsCacheReadsAndGeneralQueueEvents() throws {
        let cached = UUID()
        let processing = UUID()
        let groups = LogRunBuilder.build(from: [
            event("run.start", runId: cached), event("cache.hit", runId: cached),
            event("prefetch.batchCheck"), event("prefetch.cancel"),
            event("run.start", runId: processing), event("cache.miss", runId: processing),
        ], bookTitles: ["book": "Book Name"])
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(group.id, processing.uuidString)
        XCTAssertEqual(group.title, "Book Name · Chương 12 · Song ngữ")
        XCTAssertEqual(group.status, .processing)
    }

    func testRunSummaryHasSourceDurationAndExplicitOutcome() throws {
        let runId = UUID()
        let start = event("run.start", runId: runId, time: 1, detail: "source=prefetch")
        let done = event("run.success", runId: runId, time: 4)
        let group = try XCTUnwrap(LogRunBuilder.build(from: [start, done]).first)
        XCTAssertEqual(group.status, .success)
        XCTAssertTrue(group.subtitle.contains("Tải trước"))
        XCTAssertTrue(group.subtitle.contains("3.0 giây"))
        XCTAssertTrue(LogRunBuilder.matches(group, needle: "Song ngữ"))
        XCTAssertEqual(group.entries.count, 2)
        XCTAssertEqual(LogRunBuilder.status(of: [start, done, event("run.cancel", runId: runId, time: 5)]), .cancelled)
        XCTAssertFalse(LogEntry.isError(event("run.cancel", runId: runId)))
    }

    func testRequestDetailsKeepOneOutcomePerAttemptAndRetryContext() throws {
        let runId = UUID()
        let requestId = UUID()
        let start = api(runId: runId, requestId: requestId, attempt: 1, time: 1)
        let failed = api(runId: runId, requestId: requestId, attempt: 1, time: 2, status: 503)
        let retryStart = api(runId: runId, requestId: requestId, attempt: 2, time: 3)
        let received = api(runId: runId, requestId: requestId, attempt: 2, time: 4, status: 200)
        let group = try XCTUnwrap(LogRunBuilder.build(from: [start, failed, retryStart, received]).first)
        XCTAssertEqual(group.visibleEntries.map(\.attempt), [1, 2])
        XCTAssertEqual(group.visibleEntries.compactMap(\.statusCode), [503, 200])
        XCTAssertTrue(group.visibleEntries.allSatisfy { $0.requestBody == "private request" })
        XCTAssertTrue(LogRunBuilder.matches(group, needle: "HTTP 503"))
        XCTAssertEqual(group.entries.count, 4)
        XCTAssertFalse(LogRunBuilder.matches(group, needle: "private request"))
    }

    func testSharedRunHasOriginRequestsButOwnOutcomeAndSource() throws {
        let origin = UUID()
        let joined = UUID()
        let request = api(runId: origin, requestId: UUID(), attempt: 1, time: 2, status: 200)
        let groups = LogRunBuilder.build(from: [
            event("run.start", runId: origin, time: 1, detail: "source=prefetch"), request,
            event("run.start", runId: joined, time: 1.5, detail: "source=reader"),
            event("dedup.shared", runId: joined, time: 1.6, detail: "originRunId=\(origin.uuidString)"),
            event("run.success", runId: joined, time: 3),
        ])
        let group = try XCTUnwrap(groups.first { $0.id == joined.uuidString })
        XCTAssertEqual(group.status, .success)
        XCTAssertTrue(group.subtitle.contains("Màn hình đọc"))
        XCTAssertTrue(group.subtitle.contains("1.5 giây"))
        XCTAssertTrue(group.visibleEntries.contains { $0.id == request.id })
        XCTAssertEqual(group.entries.filter { $0.event == "run.start" }.count, 1)
    }

    func testBilingualValidationFailureExplainsStageAfterHTTP200() throws {
        let runId = UUID()
        let requestId = UUID()
        let response = api(runId: runId, requestId: requestId, attempt: 1, time: 1, status: 200)
        let validation = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 2), sessionId: UUID(),
            bookId: "book", chapterNumber: 12, mode: "bilingual", chunkIndex: 0, chunkTotal: 1,
            errorDomain: "novels.AIClientError", errorCode: 0,
            event: "chunk.fail", detail: "stage=validation", runId: runId
        )
        let group = try XCTUnwrap(LogRunBuilder.build(from: [response, validation]).first)
        XCTAssertEqual(group.status, .failed)
        XCTAssertTrue(group.issueSummary?.contains("Đầu ra song ngữ không hợp lệ") == true)
        XCTAssertTrue(group.visibleEntries.contains { $0.statusCode == 200 })
    }

    func testEndpointDetailsStripURLCredentialsQueryAndFragment() {
        let request = LogEntry(
            sessionId: UUID(), kind: .api,
            host: "https://user:password@example.com/v1/chat/completions?api_key=secret#token",
            model: "fixture-model"
        )
        XCTAssertEqual(request.diagnosticEndpoint, "https://example.com/v1/chat/completions")
        XCTAssertFalse(request.debugSummary.contains("secret"))
        XCTAssertFalse(request.debugSummary.contains("password"))
    }

    func testOwnChunkFailureRemainsFailedAfterRunCancellation() throws {
        let runId = UUID()
        let failed = chunkFailure(runId: runId)
        let group = try XCTUnwrap(LogRunBuilder.build(from: [
            event("run.start", runId: runId, time: 0), failed,
            event("run.cancel", runId: runId, time: 3),
        ]).first)
        XCTAssertEqual(group.status, .failed)
        XCTAssertTrue(group.issueSummary?.contains("Đầu ra song ngữ không hợp lệ") == true)
    }

    func testCancelledSharedConsumerDoesNotOwnOriginFailure() throws {
        let origin = UUID()
        let joined = UUID()
        let groups = LogRunBuilder.build(from: [
            event("run.start", runId: origin, time: 0), chunkFailure(runId: origin),
            event("run.start", runId: joined, time: 0.5),
            event("dedup.shared", runId: joined, time: 0.6, detail: "originRunId=\(origin.uuidString)"),
            event("run.cancel", runId: joined, time: 3),
        ])
        let group = try XCTUnwrap(groups.first { $0.id == joined.uuidString })
        XCTAssertEqual(group.status, .cancelled)
        XCTAssertFalse(group.issueSummary?.contains("Đầu ra song ngữ không hợp lệ") == true)
    }

    func testFailedSharedConsumerKeepsOriginValidationCause() throws {
        let origin = UUID()
        let joined = UUID()
        let failure = LogEntry(
            timestamp: Date(timeIntervalSince1970: 3), sessionId: UUID(),
            bookId: "book", chapterNumber: 12, mode: "bilingual",
            errorDomain: "novels.AIClientError", errorCode: 1, event: "run.fail", runId: joined
        )
        let groups = LogRunBuilder.build(from: [
            event("run.start", runId: origin, time: 0), chunkFailure(runId: origin),
            event("run.start", runId: joined, time: 0.5),
            event("dedup.shared", runId: joined, time: 0.6, detail: "originRunId=\(origin.uuidString)"), failure,
        ])
        let group = try XCTUnwrap(groups.first { $0.id == joined.uuidString })
        XCTAssertEqual(group.status, .failed)
        XCTAssertTrue(group.issueSummary?.contains("Đoạn 1/1") == true)
        XCTAssertTrue(group.issueSummary?.contains("Đầu ra song ngữ không hợp lệ") == true)
    }

    func testRecoveredRetryDoesNotTurnRunCancellationIntoFailure() throws {
        let runId = UUID()
        let request = UUID()
        let group = try XCTUnwrap(LogRunBuilder.build(from: [
            api(runId: runId, requestId: request, attempt: 1, time: 1, status: 503),
            api(runId: runId, requestId: request, attempt: 2, time: 2, status: 200),
            event("run.cancel", runId: runId, time: 3),
        ]).first)
        XCTAssertEqual(group.status, .cancelled)
    }

    func testCacheFailureSummaryDoesNotBlameRecoveredHTTPRetry() throws {
        let runId = UUID()
        let request = UUID()
        let saveFailure = LogEntry(
            timestamp: Date(timeIntervalSince1970: 4), sessionId: UUID(),
            bookId: "book", chapterNumber: 12, mode: "bilingual",
            errorDomain: "novels.SQLiteError", errorCode: 2, event: "run.fail", runId: runId
        )
        let group = try XCTUnwrap(LogRunBuilder.build(from: [
            api(runId: runId, requestId: request, attempt: 1, time: 1, status: 503),
            api(runId: runId, requestId: request, attempt: 2, time: 2, status: 200),
            event("chunk.success", runId: runId, time: 3), saveFailure,
        ]).first)
        XCTAssertEqual(group.status, .failed)
        XCTAssertFalse(group.issueSummary?.contains("HTTP 503") == true)
        XCTAssertTrue(group.issueSummary?.contains("bộ nhớ đệm") == true)
    }

    @MainActor
    func testRecoveredRetryDoesNotWarnOrHideSuccessfulRun() throws {
        let store = DiagnosticsStore()
        let runId = UUID()
        let requestId = UUID()
        store.entries = [
            event("run.start", runId: runId, time: 0),
            api(runId: runId, requestId: requestId, attempt: 1, time: 1, status: 503),
            api(runId: runId, requestId: requestId, attempt: 2, time: 2, status: 200),
            event("run.success", runId: runId, time: 3),
        ]
        XCTAssertEqual(store.failedRunCount(bookId: "book"), 0)
        let group = try XCTUnwrap(store.runGroups(bookId: "book").first)
        XCTAssertEqual(group.status, .success)
        XCTAssertEqual(group.visibleEntries.compactMap(\.statusCode), [503, 200])
    }

    @MainActor
    func testOtherBookFailureDoesNotWarnForCurrentBook() {
        let store = DiagnosticsStore()
        let local = UUID()
        let other = UUID()
        store.entries = [
            event("run.start", runId: local, time: 0), event("run.success", runId: local, time: 1),
            LogEntry(sessionId: UUID(), bookId: "other-book", chapterNumber: 1, mode: "bilingual",
                     event: "run.start", runId: other),
            LogEntry(sessionId: UUID(), kind: .api, bookId: "other-book", chapterNumber: 1, mode: "bilingual",
                     statusCode: 503, runId: other),
            LogEntry(sessionId: UUID(), bookId: "other-book", chapterNumber: 1, mode: "bilingual",
                     errorDomain: NSURLErrorDomain, errorCode: URLError.timedOut.rawValue,
                     event: "run.fail", runId: other),
        ]
        XCTAssertEqual(store.failedRunCount(bookId: "book"), 0)
        XCTAssertEqual(store.failedRunCount(bookId: "other-book"), 1)
        XCTAssertEqual(store.runGroups(bookId: "book").map(\.id), [local.uuidString])
    }

    func testConfigurationWarningsCanBeSearchedAndInspectedWithoutFailingRun() throws {
        let runId = UUID()
        let warnings = ["invalid.headers", "invalid.body"].map {
            event($0, runId: runId, time: 1, detail: "len=17 hash=fixture")
        }
        let group = try XCTUnwrap(LogRunBuilder.build(from: [
            event("run.start", runId: runId, time: 0), event("run.success", runId: runId, time: 2),
        ] + warnings).first)
        XCTAssertEqual(group.status, .success)
        for warning in warnings {
            XCTAssertTrue(try LogRunBuilder.matches(group, needle: XCTUnwrap(warning.event)))
            XCTAssertTrue(group.visibleEntries.contains { $0.id == warning.id })
            XCTAssertTrue(warning.diagnosticTitle.contains("JSON"))
            XCTAssertTrue(warning.diagnosticExplanation?.contains("bỏ qua") == true)
            XCTAssertFalse(LogEntry.isError(warning))
        }
    }

    func testSharedRunKeepsOriginConfigurationWarnings() throws {
        let origin = UUID()
        let joined = UUID()
        let warning = event("invalid.body", runId: origin, time: 1)
        let groups = LogRunBuilder.build(from: [
            event("run.start", runId: origin, time: 0), warning,
            event("run.start", runId: joined, time: 0.5),
            event("dedup.shared", runId: joined, time: 0.6, detail: "originRunId=\(origin.uuidString)"),
            event("run.success", runId: joined, time: 2),
        ])
        let group = try XCTUnwrap(groups.first { $0.id == joined.uuidString })
        XCTAssertTrue(LogRunBuilder.matches(group, needle: "invalid.body"))
        XCTAssertTrue(group.visibleEntries.contains { $0.id == warning.id })
    }

    private func chunkFailure(runId: UUID) -> LogEntry {
        LogEntry(
            timestamp: Date(timeIntervalSince1970: 2), sessionId: UUID(),
            bookId: "book", chapterNumber: 12, mode: "bilingual", chunkIndex: 0, chunkTotal: 1,
            errorDomain: "novels.BilingualChapterError", errorCode: 1, event: "chunk.fail", runId: runId
        )
    }

    private func event(
        _ name: String, runId: UUID? = nil, time: TimeInterval = 1, detail: String? = nil
    ) -> LogEntry {
        LogEntry(
            timestamp: Date(timeIntervalSince1970: time), sessionId: UUID(),
            bookId: "book", chapterNumber: 12, mode: "bilingual", event: name, detail: detail, runId: runId
        )
    }

    private func api(
        runId: UUID, requestId: UUID, attempt: Int, time: TimeInterval, status: Int? = nil
    ) -> LogEntry {
        LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: time), sessionId: UUID(), kind: .api,
            bookId: "book", chapterNumber: 12, mode: "bilingual", attempt: attempt,
            statusCode: status, runId: runId, requestBody: "private request", responseBody: "private response"
        )
    }
}

// swiftlint:enable trailing_comma
