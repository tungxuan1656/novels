import BackgroundTasks
import Foundation
@testable import novels
import XCTest

extension BilingualPipelineTests {
    func testContinuedBatchDoesNotFollowReplacementWorker() async throws {
        let fixture = try makeFixture()
        defer {
            BilingualURLProtocol.releasePendingResponses()
            fixture.cleanUp()
        }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let manager = PrefetchManager()
        await startPrefetch(manager, fixture: fixture, bookId: "first")
        let oldProtection = await manager.protectCurrentBatch()
        let oldBatch = try XCTUnwrap(oldProtection)
        await startPrefetch(manager, fixture: fixture, bookId: "second")
        let newProtection = await manager.protectCurrentBatch()
        let newBatch = try XCTUnwrap(newProtection)
        XCTAssertNotEqual(oldBatch.generation, newBatch.generation)

        // A delayed consumer sees only its original batch, never the replacement.
        var oldStatuses: [PrefetchStatus] = []
        for await status in oldBatch.updates {
            oldStatuses.append(status)
        }
        XCTAssertEqual(oldStatuses.map(\.currentBookId), ["first"])
        await manager.cancel(reason: "oldExpiration", generation: oldBatch.generation)
        await manager.releaseProtection(generation: oldBatch.generation)
        await manager.cancel(reason: "disappear", unlessContinued: true)
        let protectedStatus = await manager.currentStatus()
        XCTAssertTrue(protectedStatus.isRunning)
        XCTAssertEqual(protectedStatus.currentBookId, "second")

        await manager.releaseProtection(generation: newBatch.generation)
        await manager.cancel(reason: "disappear", unlessContinued: true)
        let cancelledStatus = await manager.currentStatus()
        XCTAssertFalse(cancelledStatus.isRunning)
    }

    func testExpirationCompletesBeforeSharedReaderRequestFinishes() async throws {
        let fixture = try makeFixture()
        var reader: Task<String, Error>?
        defer {
            reader?.cancel()
            BilingualURLProtocol.releasePendingResponses()
            fixture.cleanUp()
        }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let manager = PrefetchManager()
        await startPrefetch(manager, fixture: fixture, bookId: "shared")
        try await waitForRequest()
        let readerRun = UUID()
        let consumer = Task {
            try await fixture.service.processedContent(
                bookId: "shared", chapterNumber: 2, mode: .bilingual,
                rawText: "Original body.", runId: readerRun
            )
        }
        reader = consumer
        try await waitForPrefetchCondition {
            await DiagnosticsLog.shared.snapshot().contains {
                $0.runId == readerRun && $0.event == "dedup.shared"
            }
        }

        var identifier = ""
        let coordinator = ContinuedPrefetchCoordinator { identifier = $0.identifier }
        try await coordinator.submit(manager: manager, chapters: 1)
        var completions: [Bool] = []
        coordinator.launch(identifier: identifier, report: { _ in }, completion: { completions.append($0) })
        coordinator.expire(identifier: identifier)
        XCTAssertEqual(completions, [false])
        coordinator.expire(identifier: identifier)
        try await waitForPrefetchCondition { await !manager.currentStatus().isRunning }
        XCTAssertTrue(BilingualURLProtocol.completedIDs().isEmpty)
        XCTAssertNil(try fixture.cache.get(bookId: "shared", chapterNumber: 2, mode: .bilingual))

        BilingualURLProtocol.releasePendingResponses()
        let content = try await consumer.value
        XCTAssertFalse(content.isEmpty)
        XCTAssertEqual(completions, [false])
        XCTAssertEqual(BilingualURLProtocol.requests().count, 1)
    }

    func testDelayedLaunchDoesNotWaitForReplacement() async throws {
        let fixture = try makeFixture()
        defer {
            BilingualURLProtocol.releasePendingResponses()
            fixture.cleanUp()
        }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let manager = PrefetchManager()
        await startPrefetch(manager, fixture: fixture, bookId: "first")
        var identifier = ""
        let coordinator = ContinuedPrefetchCoordinator { identifier = $0.identifier }
        try await coordinator.submit(manager: manager, chapters: 1)
        await startPrefetch(manager, fixture: fixture, bookId: "second")
        var reports: [String?] = []
        var completions: [Bool] = []
        coordinator.launch(
            identifier: identifier, report: { reports.append($0.currentBookId) },
            completion: { completions.append($0) }
        )
        try await waitForPrefetchCondition { !completions.isEmpty }
        XCTAssertEqual(completions, [false])
        XCTAssertEqual(reports, ["first"])
        await manager.cancel(reason: "disappear", unlessContinued: true)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning)
    }

    func testContinuedBatchReportsSuccessfulCompletionOnce() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let manager = PrefetchManager()
        await startPrefetch(manager, fixture: fixture, bookId: "success")
        var identifier = ""
        let coordinator = ContinuedPrefetchCoordinator { identifier = $0.identifier }
        try await coordinator.submit(manager: manager, chapters: 1)
        var reports: [PrefetchStatus] = []
        var completions: [Bool] = []
        coordinator.launch(
            identifier: identifier, report: { reports.append($0) }, completion: { completions.append($0) }
        )
        BilingualURLProtocol.releasePendingResponses()
        try await waitForPrefetchCondition { !completions.isEmpty }
        XCTAssertEqual(completions, [true])
        XCTAssertEqual(reports.last?.processedChapters, 1)
        XCTAssertEqual(reports.last?.isRunning, false)
        coordinator.expire(identifier: identifier)
        XCTAssertEqual(completions, [true])
        XCTAssertNotNil(try fixture.cache.get(bookId: "success", chapterNumber: 2, mode: .bilingual))
    }

    func testRefusedSubmissionReleasesProtectionWithoutCancellingWorker() async throws {
        let fixture = try makeFixture()
        defer {
            BilingualURLProtocol.releasePendingResponses()
            fixture.cleanUp()
        }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let manager = PrefetchManager()
        await startPrefetch(manager, fixture: fixture, bookId: "refused")
        let coordinator = ContinuedPrefetchCoordinator { _ in throw URLError(.notConnectedToInternet) }
        do {
            try await coordinator.submit(manager: manager, chapters: 1)
            XCTFail("Submission should fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
        let running = await manager.currentStatus()
        XCTAssertTrue(running.isRunning)
        await manager.cancel(reason: "disappear", unlessContinued: true)
        let cancelled = await manager.currentStatus()
        XCTAssertFalse(cancelled.isRunning)
    }

    private func startPrefetch(_ manager: PrefetchManager, fixture: Fixture, bookId: String) async {
        fixture.settings.prefetchCount = 1
        await manager.start(
            bookId: bookId, currentChapter: 1, totalChapters: 2, mode: .bilingual,
            settings: fixture.settings, cache: fixture.cache, aiService: fixture.service,
            repository: ContinuedPrefetchRepository()
        )
    }

    private func waitForPrefetchCondition(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !(await condition()), Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        let satisfied = await condition()
        XCTAssertTrue(satisfied)
    }
}

private struct ContinuedPrefetchRepository: BookRepository {
    func listBooks() throws -> [Book] {
        []
    }

    func book(slug: String) throws -> Book? {
        Book(id: slug, name: "Fixture", author: nil, count: 2, references: ["First", "Second"])
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        "<h1>Chapter \(number)</h1><p>Original body.</p>"
    }

    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}
