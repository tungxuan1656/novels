@testable import novels
import XCTest

final class ProcessedChapterCacheTests: XCTestCase {
    func testCacheHitAndBatch() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let pc = ProcessedChapter(
            bookId: "test-slug",
            chapterNumber: 1,
            mode: .rewrite,
            content: "<p>hi</p>",
            contentHash: SHA256.hex("<p>hi</p>"),
            createdAt: Date(),
            updatedAt: Date()
        )
        try cache.upsert(pc)
        XCTAssertNotNil(try cache.get(bookId: "test-slug", chapterNumber: 1, mode: .rewrite))
        XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 1, mode: .none))
        XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 2, mode: .rewrite))
        XCTAssertEqual(try cache.batchStatus(bookId: "test-slug", mode: .rewrite, numbers: [1, 2]), [1])
        XCTAssertEqual(try cache.batchStatus(bookId: "test-slug", mode: .none, numbers: [1, 2]), [])
        XCTAssertTrue(try cache.batchStatus(bookId: "test-slug", mode: .rewrite, numbers: []).isEmpty)
    }

    func testUpsertOverwrites() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        var first = ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .rewrite,
            content: "a",
            contentHash: "a",
            createdAt: now,
            updatedAt: now
        )
        try cache.upsert(first)
        first = ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .rewrite,
            content: "b",
            contentHash: "b",
            createdAt: Date(),
            updatedAt: Date()
        )
        try cache.upsert(first)
        XCTAssertEqual(try cache.get(bookId: "s", chapterNumber: 1, mode: .rewrite)?.content, "b")
        XCTAssertEqual(try cache.get(bookId: "s", chapterNumber: 1, mode: .rewrite)?.contentHash, "b")
    }

    func testClear() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .rewrite,
            content: "x",
            contentHash: "x",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "other",
            chapterNumber: 1,
            mode: .rewrite,
            content: "y",
            contentHash: "y",
            createdAt: now,
            updatedAt: now
        ))
        try cache.clear(bookId: "s")
        XCTAssertNil(try cache.get(bookId: "s", chapterNumber: 1, mode: .rewrite))
        XCTAssertNotNil(try cache.get(bookId: "other", chapterNumber: 1, mode: .rewrite))
    }

    func testClearAll() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "a",
            chapterNumber: 1,
            mode: .rewrite,
            content: "x",
            contentHash: "x",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "b",
            chapterNumber: 2,
            mode: .rewrite,
            content: "y",
            contentHash: "y",
            createdAt: now,
            updatedAt: now
        ))
        try cache.clearAll()
        XCTAssertNil(try cache.get(bookId: "a", chapterNumber: 1, mode: .rewrite))
        XCTAssertNil(try cache.get(bookId: "b", chapterNumber: 2, mode: .rewrite))
        XCTAssertTrue(try cache.batchStatus(bookId: "a", mode: .rewrite, numbers: [1]).isEmpty)
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
            mode: .rewrite,
            content: "ok",
            contentHash: "ok",
            createdAt: now,
            updatedAt: now
        ))
        XCTAssertNotNil(try cache.get(bookId: "s", chapterNumber: 1, mode: .rewrite))
    }

    func testInMemoryIsolation() throws {
        let first = try SQLiteProcessedChapterCache.inMemory()
        let second = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try first.upsert(ProcessedChapter(
            bookId: "iso",
            chapterNumber: 1,
            mode: .rewrite,
            content: "only-first",
            contentHash: "h",
            createdAt: now,
            updatedAt: now
        ))
        XCTAssertNotNil(try first.get(bookId: "iso", chapterNumber: 1, mode: .rewrite))
        XCTAssertNil(try second.get(bookId: "iso", chapterNumber: 1, mode: .rewrite))
    }

    func testBatchStatusChunkedLargeSet() throws {
        // feat-023 Phase 5: a 1000-id batchStatus accumulates chunked (~200)
        // queries into one set instead of binding everything in one query.
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        for number in 1 ... 500 {
            try cache.upsert(ProcessedChapter(
                bookId: "big",
                chapterNumber: number,
                mode: .rewrite,
                content: "c\(number)",
                contentHash: "h\(number)",
                createdAt: now,
                updatedAt: now
            ))
        }
        XCTAssertEqual(
            try cache.batchStatus(bookId: "big", mode: .rewrite, numbers: Array(1 ... 1000)),
            Set(1 ... 500)
        )
    }
}
