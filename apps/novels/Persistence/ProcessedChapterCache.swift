import Foundation
import SQLite3

// swiftlint:disable identifier_name
/// Fallback for SQLite macro not imported into Swift.
private let SQLITE_TRANSIENT = -1
// swiftlint:enable identifier_name

enum SQLiteError: Error, LocalizedError {
    case open(message: String)
    case exec(message: String)
    case prepare(message: String)
    case step(message: String)
    case bind(message: String)

    var errorDescription: String? {
        // swiftlint:disable switch_case_alignment
        switch self {
            case let .open(message):
                "SQLite open failed: \(message)"
            case let .exec(message):
                "SQLite exec failed: \(message)"
            case let .prepare(message):
                "SQLite prepare failed: \(message)"
            case let .step(message):
                "SQLite step failed: \(message)"
            case let .bind(message):
                "SQLite bind failed: \(message)"
        }
        // swiftlint:enable switch_case_alignment
    }
}

protocol ProcessedChapterCaching {
    func get(bookId: String, chapterNumber: Int, mode: AIMode) throws -> ProcessedChapter?
    func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) throws -> Set<Int>
    func upsert(_ pc: ProcessedChapter) throws
    func clearAll() throws
    func clear(bookId: String) throws
    func countAll() throws -> Int
    func count(bookId: String) throws -> Int
    func allBookIds() throws -> [String]
}

final class SQLiteProcessedChapterCache: ProcessedChapterCaching {
    private let handle: OpaquePointer
    private let isoFormatter: ISO8601DateFormatter

    private init(path: String) throws {
        var db: OpaquePointer?
        let code = sqlite3_open(path, &db)
        guard code == SQLITE_OK, let opened = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let db {
                sqlite3_close(db)
            }
            throw SQLiteError.open(message: message)
        }
        handle = opened
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter = formatter
        try createSchema()
    }

    convenience init(dbURL: URL) throws {
        let dir = dbURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try self.init(path: dbURL.path)
    }

    static func inMemory() throws -> SQLiteProcessedChapterCache {
        try SQLiteProcessedChapterCache(path: ":memory:")
    }

    static var defaultCacheURL: URL {
        AppPaths.cacheRoot().appendingPathComponent("processed_chapters.sqlite")
    }

    convenience init() throws {
        try self.init(dbURL: Self.defaultCacheURL)
    }

    deinit {
        sqlite3_close(handle)
    }

    // MARK: - Schema

    private func createSchema() throws {
        let tableSQL = """
        CREATE TABLE IF NOT EXISTS processed_chapters (
          book_id TEXT NOT NULL,
          chapter_number INTEGER NOT NULL,
          mode TEXT NOT NULL,
          content TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (book_id, chapter_number, mode)
        ) WITHOUT ROWID;
        """
        try exec(tableSQL)
        try exec("CREATE INDEX IF NOT EXISTS idx_processed_chapters_book ON processed_chapters(book_id);")
        let version = try userVersion()
        if version == 0 {
            try exec("PRAGMA user_version=1;")
        }
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(handle, sql, nil, nil, &errMsg)
        guard code == SQLITE_OK else {
            let message = errMsg.flatMap { String(cString: $0) } ?? "exec failed"
            sqlite3_free(errMsg)
            throw SQLiteError.exec(message: message)
        }
    }

    private func userVersion() throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(handle)))
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Helpers

    private func bindText(_ stmt: OpaquePointer?, index: Int32, value: String) throws {
        let result = value.withCString { cString in
            sqlite3_bind_text(
                stmt,
                index,
                cString,
                -1,
                unsafeBitCast(SQLITE_TRANSIENT, to: sqlite3_destructor_type.self)
            )
        }
        guard result == SQLITE_OK else {
            throw SQLiteError.bind(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    private func string(from stmt: OpaquePointer?, col: Int32) -> String {
        guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: ptr)
    }

    private func dateString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    private func date(from string: String) -> Date {
        if let decoded = isoFormatter.date(from: string) {
            return decoded
        }
        // Fallback without fractional seconds
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string) ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: - ProcessedChapterCaching

    func get(bookId: String, chapterNumber: Int, mode: AIMode) throws -> ProcessedChapter? {
        let sql = """
        SELECT book_id, chapter_number, mode, content, content_hash, created_at, updated_at
        FROM processed_chapters WHERE book_id=? AND chapter_number=? AND mode=? LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: bookId)
        guard sqlite3_bind_int(stmt, 2, Int32(chapterNumber)) == SQLITE_OK else {
            throw SQLiteError.bind(message: String(cString: sqlite3_errmsg(handle)))
        }
        try bindText(stmt, index: 3, value: mode.rawValue)
        let step = sqlite3_step(stmt)
        if step == SQLITE_ROW {
            let retBookId = string(from: stmt, col: 0)
            let retNumber = Int(sqlite3_column_int(stmt, 1))
            let retModeRaw = string(from: stmt, col: 2)
            let retMode = AIMode(rawValue: retModeRaw) ?? .none
            let retContent = string(from: stmt, col: 3)
            let retHash = string(from: stmt, col: 4)
            let retCreated = string(from: stmt, col: 5)
            let retUpdated = string(from: stmt, col: 6)
            return ProcessedChapter(
                bookId: retBookId,
                chapterNumber: retNumber,
                mode: retMode,
                content: retContent,
                contentHash: retHash,
                createdAt: date(from: retCreated),
                updatedAt: date(from: retUpdated)
            )
        } else if step == SQLITE_DONE {
            return nil
        } else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) throws -> Set<Int> {
        guard !numbers.isEmpty else { return [] }
        let placeholders = numbers.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT chapter_number FROM processed_chapters WHERE book_id=? AND mode=? AND chapter_number IN (\(placeholders));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: bookId)
        try bindText(stmt, index: 2, value: mode.rawValue)
        for (offset, number) in numbers.enumerated() {
            let idx = Int32(offset + 3)
            guard sqlite3_bind_int(stmt, idx, Int32(number)) == SQLITE_OK else {
                throw SQLiteError.bind(message: String(cString: sqlite3_errmsg(handle)))
            }
        }
        var result: Set<Int> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.insert(Int(sqlite3_column_int(stmt, 0)))
        }
        return result
    }

    func upsert(_ pc: ProcessedChapter) throws {
        guard pc.mode != .none else { return }
        let sql = """
        INSERT OR REPLACE INTO processed_chapters
        (book_id, chapter_number, mode, content, content_hash, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: pc.bookId)
        guard sqlite3_bind_int(stmt, 2, Int32(pc.chapterNumber)) == SQLITE_OK else {
            throw SQLiteError.bind(message: String(cString: sqlite3_errmsg(handle)))
        }
        try bindText(stmt, index: 3, value: pc.mode.rawValue)
        try bindText(stmt, index: 4, value: pc.content)
        try bindText(stmt, index: 5, value: pc.contentHash)
        try bindText(stmt, index: 6, value: dateString(pc.createdAt))
        try bindText(stmt, index: 7, value: dateString(pc.updatedAt))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    func clearAll() throws {
        try exec("DELETE FROM processed_chapters;")
    }

    func clear(bookId: String) throws {
        let sql = "DELETE FROM processed_chapters WHERE book_id=?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: bookId)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    func countAll() throws -> Int {
        let sql = "SELECT count(*) FROM processed_chapters;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(handle)))
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func count(bookId: String) throws -> Int {
        let sql = "SELECT count(*) FROM processed_chapters WHERE book_id=?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: bookId)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(handle)))
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func allBookIds() throws -> [String] {
        let sql = "SELECT DISTINCT book_id FROM processed_chapters;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                ids.append(String(cString: cString))
            }
        }
        return ids
    }
}

actor ProcessedChapterStore {
    private let cache: SQLiteProcessedChapterCache

    init(cache: SQLiteProcessedChapterCache) {
        self.cache = cache
    }

    func get(bookId: String, chapterNumber: Int, mode: AIMode) async throws -> ProcessedChapter? {
        try await MainActor.run { try cache.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode) }
    }

    func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) async throws -> Set<Int> {
        try await MainActor.run { try cache.batchStatus(bookId: bookId, mode: mode, numbers: numbers) }
    }

    func upsert(_ pc: ProcessedChapter) async throws {
        try await MainActor.run { try cache.upsert(pc) }
    }

    func clearAll() async throws {
        try await MainActor.run { try cache.clearAll() }
    }

    func clear(bookId: String) async throws {
        try await MainActor.run { try cache.clear(bookId: bookId) }
    }
}
