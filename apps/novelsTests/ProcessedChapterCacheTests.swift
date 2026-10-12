import Foundation
@testable import novels
import SQLite3
import XCTest

@MainActor
final class ProcessedChapterCacheTests: XCTestCase {
    func testKeysUpsertAndBookScopedClear() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        try cache.upsert(chapter(book: "first", number: 1, content: "original"))
        try cache.upsert(chapter(book: "second", number: 1, content: "other book"))
        try cache.upsert(chapter(book: "first", number: 1, content: "replacement"))
        try cache.upsert(chapter(book: "first", number: 2, content: "ignored", mode: .none))
        XCTAssertEqual(try cache.countAll(), 2)
        XCTAssertEqual(try cache.get(bookId: "first", chapterNumber: 1, mode: .rewrite)?.content, "replacement")
        XCTAssertEqual(try cache.get(bookId: "second", chapterNumber: 1, mode: .rewrite)?.content, "other book")
        XCTAssertNil(try cache.get(bookId: "first", chapterNumber: 1, mode: .none))
        XCTAssertNil(try cache.get(bookId: "first", chapterNumber: 2, mode: .rewrite))
        try cache.clear(bookId: "first")
        XCTAssertEqual(try cache.countAll(), 1)
        XCTAssertEqual(try cache.allBookIds(), ["second"])
    }

    func testBatchStatusAcrossChunkBoundary() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let boundary = SQLiteProcessedChapterCache.batchStatusChunkSize
        for number in [1, boundary, boundary + 1, boundary * 2 + 1] {
            try cache.upsert(chapter(book: "sample", number: number, content: "cached"))
        }
        try cache.upsert(chapter(book: "other", number: 2, content: "excluded"))
        let numbers = Array(1 ... boundary * 2 + 2) + [1, boundary + 1]
        XCTAssertEqual(
            try cache.batchStatus(bookId: "sample", mode: .rewrite, numbers: numbers),
            Set([1, boundary, boundary + 1, boundary * 2 + 1])
        )
        XCTAssertEqual(try cache.batchStatus(bookId: "sample", mode: .none, numbers: numbers), [])
        XCTAssertEqual(try cache.batchStatus(bookId: "sample", mode: .rewrite, numbers: []), [])
    }

    func testVersionOneInvalidationAndVersionTwoPersistence() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = temp.appendingPathComponent("cache.sqlite")
        do {
            let cache = try SQLiteProcessedChapterCache(dbURL: url)
            try cache.upsert(chapter(book: "sample", number: 1, content: "legacy"))
        }
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        let opened = try XCTUnwrap(handle)
        XCTAssertEqual(sqlite3_exec(opened, "PRAGMA user_version=1;", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_close(opened), SQLITE_OK)
        do {
            let migrated = try SQLiteProcessedChapterCache(dbURL: url)
            XCTAssertEqual(try migrated.countAll(), 0)
            try migrated.upsert(chapter(book: "sample", number: 1, content: "current"))
        }
        let reopened = try SQLiteProcessedChapterCache(dbURL: url)
        XCTAssertEqual(try reopened.get(bookId: "sample", chapterNumber: 1, mode: .rewrite)?.content, "current")
    }

    private func chapter(book: String, number: Int, content: String, mode: AIMode = .rewrite) -> ProcessedChapter {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return ProcessedChapter(
            bookId: book, chapterNumber: number, mode: mode, content: content,
            contentHash: "hash", createdAt: date, updatedAt: date
        )
    }
}
