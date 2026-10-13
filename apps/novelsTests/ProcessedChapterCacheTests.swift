import Foundation
@testable import novels
import SQLite3
import XCTest

// swiftlint:disable trailing_comma

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

    func testMetadataQueryOrderModeCoexistenceAndIsolation() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let t1 = Date(timeIntervalSince1970: 1_700_000_100)
        let t2 = Date(timeIntervalSince1970: 1_700_000_200)
        let t3 = Date(timeIntervalSince1970: 1_700_000_300)

        // Chapter 2 rewrite
        try cache.upsert(ProcessedChapter(
            bookId: "book-a", chapterNumber: 2, mode: .rewrite,
            content: "ch2 rewrite", contentHash: "h1", createdAt: t1, updatedAt: t1
        ))
        // Chapter 1 bilingual
        try cache.upsert(ProcessedChapter(
            bookId: "book-a", chapterNumber: 1, mode: .bilingual,
            content: "ch1 bi", contentHash: "h2", createdAt: t2, updatedAt: t2
        ))
        // Chapter 1 rewrite (coexists with bilingual)
        try cache.upsert(ProcessedChapter(
            bookId: "book-a", chapterNumber: 1, mode: .rewrite,
            content: "ch1 rw", contentHash: "h3", createdAt: t3, updatedAt: t3
        ))
        // Chapter from another book
        try cache.upsert(ProcessedChapter(
            bookId: "book-b", chapterNumber: 1, mode: .rewrite,
            content: "other", contentHash: "h4", createdAt: t1, updatedAt: t1
        ))

        let metaA = try cache.metadata(bookId: "book-a")
        XCTAssertEqual(metaA.count, 3)
        // Chapter 1 bilingual, Chapter 1 rewrite, Chapter 2 rewrite (ordered by chapter_number, then mode)
        XCTAssertEqual(metaA[0].chapterNumber, 1)
        XCTAssertEqual(metaA[0].mode, .bilingual)
        XCTAssertEqual(metaA[0].updatedAt.timeIntervalSince1970, t2.timeIntervalSince1970, accuracy: 0.01)

        XCTAssertEqual(metaA[1].chapterNumber, 1)
        XCTAssertEqual(metaA[1].mode, .rewrite)
        XCTAssertEqual(metaA[1].updatedAt.timeIntervalSince1970, t3.timeIntervalSince1970, accuracy: 0.01)

        XCTAssertEqual(metaA[2].chapterNumber, 2)
        XCTAssertEqual(metaA[2].mode, .rewrite)
        XCTAssertEqual(metaA[2].updatedAt.timeIntervalSince1970, t1.timeIntervalSince1970, accuracy: 0.01)

        // Book isolation: book-b only sees its own
        let metaB = try cache.metadata(bookId: "book-b")
        XCTAssertEqual(metaB.count, 1)
        XCTAssertEqual(metaB[0].chapterNumber, 1)

        // Unknown book returns empty list
        let metaEmpty = try cache.metadata(bookId: "book-none")
        XCTAssertEqual(metaEmpty, [])

        // Clear reflects in metadata
        try cache.clear(bookId: "book-a")
        XCTAssertEqual(try cache.metadata(bookId: "book-a"), [])
        XCTAssertEqual(try cache.metadata(bookId: "book-b").count, 1)
    }

    func testInventoryCountsVersionsAndDistinctChaptersWithoutMetadata() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        XCTAssertEqual(try cache.inventory(), [])
        try cache.upsert(chapter(book: "first", number: 1, content: "one"))
        try cache.upsert(chapter(book: "first", number: 1, content: "two", mode: .bilingual))
        try cache.upsert(chapter(book: "first", number: 2, content: "three"))
        try cache.upsert(chapter(book: "second", number: 1, content: "other"))
        try cache.upsert(chapter(book: "first", number: 2, content: "replacement"))
        XCTAssertEqual(try cache.inventory(), [
            ProcessedBookSummary(bookId: "first", versionCount: 3, chapterCount: 2),
            ProcessedBookSummary(bookId: "second", versionCount: 1, chapterCount: 1),
        ])
        try cache.clear(bookId: "first")
        XCTAssertEqual(try cache.inventory(), [
            ProcessedBookSummary(bookId: "second", versionCount: 1, chapterCount: 1),
        ])
        try cache.clearAll()
        XCTAssertEqual(try cache.inventory(), [])
    }

    private func chapter(book: String, number: Int, content: String, mode: AIMode = .rewrite) -> ProcessedChapter {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return ProcessedChapter(
            bookId: book, chapterNumber: number, mode: mode, content: content,
            contentHash: "hash", createdAt: date, updatedAt: date
        )
    }
}

// swiftlint:enable trailing_comma
