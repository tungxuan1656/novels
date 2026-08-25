@testable import novels
import XCTest

final class ProcessedChapterCacheTests: XCTestCase {
    func testCacheHitAndBatch() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let pc = ProcessedChapter(
            bookId: "test-slug",
            chapterNumber: 1,
            mode: .translate,
            content: "<p>hi</p>",
            contentHash: SHA256.hex("<p>hi</p>"),
            createdAt: Date(),
            updatedAt: Date()
        )
        try cache.upsert(pc)
        XCTAssertNotNil(try cache.get(bookId: "test-slug", chapterNumber: 1, mode: .translate))
        XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 1, mode: .summary))
        XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 2, mode: .translate))
        XCTAssertEqual(try cache.batchStatus(bookId: "test-slug", mode: .translate, numbers: [1, 2]), [1])
        XCTAssertEqual(try cache.batchStatus(bookId: "test-slug", mode: .summary, numbers: [1, 2]), [])
        XCTAssertTrue(try cache.batchStatus(bookId: "test-slug", mode: .translate, numbers: []).isEmpty)
    }

    func testUpsertOverwrites() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        var first = ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .translate,
            content: "a",
            contentHash: "a",
            createdAt: now,
            updatedAt: now
        )
        try cache.upsert(first)
        first = ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .translate,
            content: "b",
            contentHash: "b",
            createdAt: Date(),
            updatedAt: Date()
        )
        try cache.upsert(first)
        XCTAssertEqual(try cache.get(bookId: "s", chapterNumber: 1, mode: .translate)?.content, "b")
        XCTAssertEqual(try cache.get(bookId: "s", chapterNumber: 1, mode: .translate)?.contentHash, "b")
    }

    func testClear() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .summary,
            content: "x",
            contentHash: "x",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "other",
            chapterNumber: 1,
            mode: .summary,
            content: "y",
            contentHash: "y",
            createdAt: now,
            updatedAt: now
        ))
        try cache.clear(bookId: "s")
        XCTAssertNil(try cache.get(bookId: "s", chapterNumber: 1, mode: .summary))
        XCTAssertNotNil(try cache.get(bookId: "other", chapterNumber: 1, mode: .summary))
    }

    func testClearAll() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "a",
            chapterNumber: 1,
            mode: .translate,
            content: "x",
            contentHash: "x",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "b",
            chapterNumber: 2,
            mode: .summary,
            content: "y",
            contentHash: "y",
            createdAt: now,
            updatedAt: now
        ))
        try cache.clearAll()
        XCTAssertNil(try cache.get(bookId: "a", chapterNumber: 1, mode: .translate))
        XCTAssertNil(try cache.get(bookId: "b", chapterNumber: 2, mode: .summary))
        XCTAssertTrue(try cache.batchStatus(bookId: "a", mode: .translate, numbers: [1]).isEmpty)
    }

    func testNoneNeverWritten() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .none,
            content: "x",
            contentHash: "x",
            createdAt: now,
            updatedAt: now
        ))
        XCTAssertNil(try cache.get(bookId: "s", chapterNumber: 1, mode: .none))
        XCTAssertTrue(try cache.batchStatus(bookId: "s", mode: .none, numbers: [1]).isEmpty)
        // Ensure translate still writable after none attempt
        try cache.upsert(ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .translate,
            content: "ok",
            contentHash: "ok",
            createdAt: now,
            updatedAt: now
        ))
        XCTAssertNotNil(try cache.get(bookId: "s", chapterNumber: 1, mode: .translate))
    }

    func testInMemoryIsolation() throws {
        let first = try SQLiteProcessedChapterCache.inMemory()
        let second = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try first.upsert(ProcessedChapter(
            bookId: "iso",
            chapterNumber: 1,
            mode: .translate,
            content: "only-first",
            contentHash: "h",
            createdAt: now,
            updatedAt: now
        ))
        XCTAssertNotNil(try first.get(bookId: "iso", chapterNumber: 1, mode: .translate))
        XCTAssertNil(try second.get(bookId: "iso", chapterNumber: 1, mode: .translate))
    }
}
