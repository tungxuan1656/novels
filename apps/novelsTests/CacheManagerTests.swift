@testable import novels
import XCTest

final class CacheManagerTests: XCTestCase {
    func testCacheCountAndClearAll() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let base = Date()
        let ch1 = ProcessedChapter(
            bookId: "slug-a",
            chapterNumber: 1,
            mode: .rewrite,
            content: "hi",
            contentHash: "h",
            createdAt: base,
            updatedAt: base
        )
        try cache.upsert(ch1)
        try cache.upsert(ProcessedChapter(
            bookId: "slug-a",
            chapterNumber: 2,
            mode: .rewrite,
            content: "hi2",
            contentHash: "h2",
            createdAt: base,
            updatedAt: base
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "slug-b",
            chapterNumber: 1,
            mode: .rewrite,
            content: "x",
            contentHash: "hx",
            createdAt: base,
            updatedAt: base
        ))
        XCTAssertEqual(try cache.countAll(), 3)
        XCTAssertEqual(try cache.count(bookId: "slug-a"), 2)
        XCTAssertEqual(try cache.count(bookId: "slug-b"), 1)
        try cache.clearAll()
        XCTAssertEqual(try cache.countAll(), 0)
        XCTAssertEqual(try cache.allBookIds().count, 0)
    }

    func testClearByBook() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let base = Date()
        for num in 1 ... 2 {
            try cache.upsert(ProcessedChapter(
                bookId: "s1",
                chapterNumber: num,
                mode: .rewrite,
                content: "c\(num)",
                contentHash: "h\(num)",
                createdAt: base,
                updatedAt: base
            ))
        }
        try cache.upsert(ProcessedChapter(
            bookId: "s2",
            chapterNumber: 1,
            mode: .rewrite,
            content: "c",
            contentHash: "h",
            createdAt: base,
            updatedAt: base
        ))
        XCTAssertEqual(try cache.countAll(), 3)
        try cache.clear(bookId: "s1")
        XCTAssertEqual(try cache.countAll(), 1)
        XCTAssertEqual(try cache.count(bookId: "s2"), 1)
        XCTAssertEqual(try cache.count(bookId: "s1"), 0)
        XCTAssertEqual(try cache.allBookIds(), ["s2"])
    }

    func testAllBookIdsDistinct() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let base = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "alpha",
            chapterNumber: 1,
            mode: .rewrite,
            content: "a",
            contentHash: "ha",
            createdAt: base,
            updatedAt: base
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "alpha",
            chapterNumber: 2,
            mode: .rewrite,
            content: "b",
            contentHash: "hb",
            createdAt: base,
            updatedAt: base
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "beta",
            chapterNumber: 1,
            mode: .rewrite,
            content: "c",
            contentHash: "hc",
            createdAt: base,
            updatedAt: base
        ))
        let ids = try cache.allBookIds().sorted()
        XCTAssertEqual(ids, ["alpha", "beta"])
        XCTAssertEqual(try cache.count(bookId: "alpha"), 2)
    }

    func testCacheViewLoadReflectsImmediately() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let base = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "b1",
            chapterNumber: 1,
            mode: .rewrite,
            content: "a",
            contentHash: "h",
            createdAt: base,
            updatedAt: base
        ))
        XCTAssertEqual(try cache.countAll(), 1)
        try cache.clearAll()
        XCTAssertEqual(try cache.countAll(), 0)
    }
}
