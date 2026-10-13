import Foundation
@testable import novels
import XCTest

final class DiagnosticsOutcomeTests: XCTestCase {
    func testTransportCancellationIsNotAnErrorAndClosesRun() {
        let cancelled = entry(errorDomain: NSURLErrorDomain, errorCode: URLError.cancelled.rawValue)
        XCTAssertTrue(LogEntry.isMutedCancel(cancelled))
        XCTAssertFalse(LogEntry.isError(cancelled))
        XCTAssertFalse(LogKindFilter.error.matches(cancelled))
        XCTAssertEqual(LogRunBuilder.status(of: [cancelled]), .cancelled)
    }

    func testRealFailureSurvivesSiblingCancellation() {
        let failure = entry(errorDomain: NSURLErrorDomain, errorCode: URLError.timedOut.rawValue)
        let cancelled = entry(errorDomain: NSURLErrorDomain, errorCode: URLError.cancelled.rawValue, time: 2)
        XCTAssertTrue(LogEntry.isError(failure))
        XCTAssertEqual(LogRunBuilder.status(of: [failure, cancelled]), .failed)
    }

    func testLaterTerminalSuccessClearsRetryFailureButTiesDoNot() {
        let failure = entry(errorDomain: "AIClientError.httpError", errorCode: 503)
        let saved = entry(event: "cache.save", time: 2)
        XCTAssertEqual(LogRunBuilder.status(of: [failure, saved]), .success)
        XCTAssertEqual(LogRunBuilder.status(of: [failure, entry(event: "cache.save")]), .failed)
    }

    func testReceivedHTTP200WithInvalidJSONStillExplainsFailure() {
        let failure = LogEntry(
            sessionId: UUID(), kind: .api, statusCode: 200,
            errorDomain: "AIClientError.invalidStructuredOutput", errorCode: 0
        )
        XCTAssertTrue(LogEntry.isError(failure))
        XCTAssertEqual(failure.diagnosticTitle, "Sai JSON đầu ra")
        XCTAssertTrue(failure.diagnosticExplanation?.contains("Đã nhận phản hồi") == true)
    }

    func testRunSummaryIdentifiesChunkAttemptAndCauseWithoutRawBody() throws {
        let requestId = UUID()
        let runId = UUID()
        let failure = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 1),
            sessionId: UUID(), kind: .api, chunkIndex: 1, chunkTotal: 2, attempt: 2,
            errorDomain: NSURLErrorDomain, errorCode: URLError.timedOut.rawValue,
            runId: runId, requestBody: "private request", responseBody: "private response"
        )
        let chunkFailure = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 2),
            sessionId: UUID(), chunkIndex: 1, chunkTotal: 2,
            errorDomain: NSURLErrorDomain, errorCode: URLError.timedOut.rawValue,
            event: "chunk.fail", runId: runId
        )
        let prefetchFailure = LogEntry(
            timestamp: Date(timeIntervalSince1970: 3), sessionId: UUID(),
            event: "prefetch.error-continue", detail: "reason=aiError", runId: runId
        )
        let group = try XCTUnwrap(LogRunBuilder.build(from: [failure, chunkFailure, prefetchFailure]).first)
        XCTAssertTrue(group.issueSummary?.contains("Đoạn 2/2 · Lần thử 2") == true)
        XCTAssertTrue(group.issueSummary?.contains("Hết thời gian chờ") == true)
        XCTAssertFalse(group.issueSummary?.contains("private") == true)
        XCTAssertTrue(LogRunBuilder.matches(group, needle: "-1001"))
        XCTAssertFalse(LogRunBuilder.matches(group, needle: "private response"))
    }

    func testWrapperResolvesFinalHTTPFailureByRequestID() throws {
        let runId = UUID()
        let requestId = UUID()
        let responses = (1 ... 2).map { attempt in
            LogEntry(
                requestId: requestId, timestamp: Date(timeIntervalSince1970: Double(attempt)),
                sessionId: UUID(), kind: .api, chunkIndex: 0, chunkTotal: 2, attempt: attempt,
                statusCode: 401, errorDomain: "AIClientError.httpError", errorCode: 401, runId: runId
            )
        }
        let wrapper = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 3), sessionId: UUID(),
            chunkIndex: 0, chunkTotal: 2, errorDomain: "novels.AIClientError", errorCode: 1,
            event: "chunk.fail", runId: runId
        )
        let sibling = LogEntry(
            requestId: UUID(), timestamp: Date(timeIntervalSince1970: 4), sessionId: UUID(), kind: .api,
            errorDomain: NSURLErrorDomain, errorCode: URLError.cancelled.rawValue, runId: runId
        )
        let group = try XCTUnwrap(LogRunBuilder.build(from: responses + [wrapper, sibling]).first)
        XCTAssertEqual(group.status, .failed)
        XCTAssertTrue(group.issueSummary?.contains("Đoạn 1/2 · Lần thử 2 · HTTP 401") == true)
        XCTAssertTrue(group.issueSummary?.contains("xác thực") == true)
    }

    func testSemanticFailureDoesNotUseEarlierFailedRetry() throws {
        let requestId = UUID()
        let runId = UUID()
        let firstTry = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 1), sessionId: UUID(), kind: .api,
            statusCode: 503, errorDomain: "AIClientError.httpError", errorCode: 503, runId: runId
        )
        let secondTry = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 2),
            sessionId: UUID(), kind: .api, attempt: 2, statusCode: 200, runId: runId
        )
        let validationFailure = LogEntry(
            requestId: requestId, timestamp: Date(timeIntervalSince1970: 3), sessionId: UUID(),
            errorDomain: "novels.BilingualChapterError", errorCode: 1, event: "chunk.fail", runId: runId
        )
        let group = try XCTUnwrap(LogRunBuilder.build(from: [firstTry, secondTry, validationFailure]).first)
        XCTAssertEqual(group.status, .failed)
        XCTAssertTrue(group.issueSummary?.contains("Đầu ra song ngữ không hợp lệ") == true)
        XCTAssertFalse(group.issueSummary?.contains("HTTP 503") == true)
    }

    func testSendingAndCancellationHaveDistinctHumanLabels() {
        XCTAssertEqual(entry().diagnosticTitle, "Đang gửi")
        let cancelled = entry(errorDomain: NSURLErrorDomain, errorCode: URLError.cancelled.rawValue)
        XCTAssertEqual(cancelled.diagnosticTitle, "Đã hủy")
        XCTAssertTrue(cancelled.diagnosticExplanation?.contains("không tự thử lại") == true)
        let modeCancel = LogEntry(sessionId: UUID(), event: "prefetch.cancel", detail: "reason=modeChange")
        XCTAssertEqual(modeCancel.diagnosticExplanation, "Đã đổi chế độ AI.")
    }

    private func entry(
        errorDomain: String? = nil, errorCode: Int? = nil, event: String? = nil, time: TimeInterval = 1
    ) -> LogEntry {
        LogEntry(
            timestamp: Date(timeIntervalSince1970: time), sessionId: UUID(),
            kind: event == nil ? .api : .event, errorDomain: errorDomain, errorCode: errorCode, event: event
        )
    }
}
