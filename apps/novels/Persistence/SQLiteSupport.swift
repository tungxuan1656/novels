import Foundation
import SQLite3

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

final class SQLiteDB {
    private var handle: OpaquePointer?

    var rawHandle: OpaquePointer? {
        handle
    }

    init(path: String) throws {
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
    }

    deinit {
        close()
    }

    func close() {
        if let handle {
            sqlite3_close(handle)
            self.handle = nil
        }
    }

    func exec(_ sql: String) throws {
        guard let handle else { throw SQLiteError.exec(message: "db closed") }
        var errMsg: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(handle, sql, nil, nil, &errMsg)
        guard code == SQLITE_OK else {
            let message = errMsg.flatMap { String(cString: $0) } ?? "exec failed"
            sqlite3_free(errMsg)
            throw SQLiteError.exec(message: message)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else { throw SQLiteError.prepare(message: "db closed") }
        var stmt: OpaquePointer?
        let code = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard code == SQLITE_OK, let prepared = stmt else {
            let message = String(cString: sqlite3_errmsg(handle))
            throw SQLiteError.prepare(message: message)
        }
        return prepared
    }

    func userVersion() throws -> Int {
        guard let handle else { throw SQLiteError.exec(message: "db closed") }
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

    func setUserVersion(_ version: Int) throws {
        try exec("PRAGMA user_version=\(version);")
    }
}

enum SQLiteSupport {
    static func open(atPath path: String) throws -> OpaquePointer {
        var db: OpaquePointer?
        let code = sqlite3_open(path, &db)
        guard code == SQLITE_OK, let handle = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let db {
                sqlite3_close(db)
            }
            throw SQLiteError.open(message: message)
        }
        return handle
    }

    static func close(_ db: OpaquePointer?) {
        if let db {
            sqlite3_close(db)
        }
    }

    static func exec(db: OpaquePointer?, sql: String) throws {
        guard let db else { throw SQLiteError.exec(message: "db closed") }
        var errMsg: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(db, sql, nil, nil, &errMsg)
        guard code == SQLITE_OK else {
            let message = errMsg.flatMap { String(cString: $0) } ?? "exec failed"
            sqlite3_free(errMsg)
            throw SQLiteError.exec(message: message)
        }
    }

    static func prepare(db: OpaquePointer?, sql: String) throws -> OpaquePointer {
        guard let db else { throw SQLiteError.prepare(message: "db closed") }
        var stmt: OpaquePointer?
        let code = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard code == SQLITE_OK, let prepared = stmt else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
        }
        return prepared
    }

    static func userVersion(db: OpaquePointer?) throws -> Int {
        guard let db else { throw SQLiteError.exec(message: "db closed") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    static func setUserVersion(db: OpaquePointer?, version: Int) throws {
        try exec(db: db, sql: "PRAGMA user_version=\(version);")
    }
}
