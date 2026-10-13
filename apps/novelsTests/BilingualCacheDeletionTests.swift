import Foundation
@testable import novels
import XCTest

extension BilingualPipelineTests {
    func testClearAllPreservesInFlightAIAndAllowsPostDeleteCacheCreation() async throws {
        let fixture = try makeFixture()
        var consumer: Task<String, Error>?
        defer {
            consumer?.cancel()
            BilingualURLProtocol.releasePendingResponses()
            fixture.cleanUp()
        }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let oldDate = Date().addingTimeInterval(-60)
        try fixture.cache.upsert(ProcessedChapter(
            bookId: "sample", chapterNumber: 2, mode: .bilingual, content: "prior-content",
            contentHash: "h1", createdAt: oldDate, updatedAt: oldDate
        ))
        try fixture.cache.upsert(ProcessedChapter(
            bookId: "other-book", chapterNumber: 1, mode: .bilingual, content: "other-content",
            contentHash: "h2", createdAt: oldDate, updatedAt: oldDate
        ))
        XCTAssertEqual(try fixture.cache.countAll(), 2)

        let runId = UUID()
        let source = String(repeating: "word ", count: 60)
        let task = Task {
            try await fixture.service.processedContent(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: source, runId: runId
            )
        }
        consumer = task

        try await waitForRequest()
        XCTAssertEqual(try fixture.cache.countAll(), 2)

        try fixture.cache.clearAll()
        XCTAssertEqual(try fixture.cache.countAll(), 0)

        BilingualURLProtocol.releasePendingResponses()
        let result = try await task.value
        let chapter = try BilingualChapter.decode(result)
        XCTAssertFalse(chapter.paragraphs.isEmpty)

        XCTAssertEqual(try fixture.cache.countAll(), 1)
        let cached = try fixture.cache.get(bookId: "sample", chapterNumber: 1, mode: .bilingual)
        XCTAssertEqual(cached?.content, result)
        XCTAssertEqual(BilingualURLProtocol.requests().count, 1)

        let entries = await DiagnosticsLog.shared.snapshot()
        let run = try XCTUnwrap(LogRunBuilder.build(from: entries).first {
            $0.id == runId.uuidString
        })
        XCTAssertEqual(run.status, .success)
        XCTAssertFalse(run.visibleEntries.contains { $0.errorCode == URLError.cancelled.rawValue })
    }

    func testClearBookPreservesOtherBookAndAllowsPostDeleteCacheCreation() async throws {
        let fixture = try makeFixture()
        var consumer: Task<String, Error>?
        defer {
            consumer?.cancel()
            BilingualURLProtocol.releasePendingResponses()
            fixture.cleanUp()
        }
        BilingualURLProtocol.configure(invalid: false, holdResponses: true)
        let oldDate = Date().addingTimeInterval(-60)
        try fixture.cache.upsert(ProcessedChapter(
            bookId: "sample", chapterNumber: 2, mode: .bilingual, content: "prior-content",
            contentHash: "h1", createdAt: oldDate, updatedAt: oldDate
        ))
        try fixture.cache.upsert(ProcessedChapter(
            bookId: "other-book", chapterNumber: 1, mode: .bilingual, content: "other-content",
            contentHash: "h2", createdAt: oldDate, updatedAt: oldDate
        ))
        XCTAssertEqual(try fixture.cache.countAll(), 2)

        let runId = UUID()
        let source = String(repeating: "word ", count: 60)
        let task = Task {
            try await fixture.service.processedContent(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: source, runId: runId
            )
        }
        consumer = task

        try await waitForRequest()
        XCTAssertEqual(try fixture.cache.count(bookId: "sample"), 1)
        XCTAssertEqual(try fixture.cache.count(bookId: "other-book"), 1)

        try fixture.cache.clear(bookId: "sample")
        XCTAssertEqual(try fixture.cache.count(bookId: "sample"), 0)
        XCTAssertEqual(try fixture.cache.count(bookId: "other-book"), 1)
        XCTAssertEqual(
            try fixture.cache.get(bookId: "other-book", chapterNumber: 1, mode: .bilingual)?.content,
            "other-content"
        )

        BilingualURLProtocol.releasePendingResponses()
        let result = try await task.value
        let chapter = try BilingualChapter.decode(result)
        XCTAssertFalse(chapter.paragraphs.isEmpty)

        XCTAssertEqual(try fixture.cache.count(bookId: "sample"), 1)
        XCTAssertEqual(try fixture.cache.count(bookId: "other-book"), 1)
        XCTAssertEqual(try fixture.cache.get(bookId: "sample", chapterNumber: 1, mode: .bilingual)?.content, result)
        XCTAssertEqual(BilingualURLProtocol.requests().count, 1)

        let entries = await DiagnosticsLog.shared.snapshot()
        let run = try XCTUnwrap(LogRunBuilder.build(from: entries).first {
            $0.id == runId.uuidString
        })
        XCTAssertEqual(run.status, .success)
        XCTAssertFalse(run.visibleEntries.contains { $0.errorCode == URLError.cancelled.rawValue })
    }
}
