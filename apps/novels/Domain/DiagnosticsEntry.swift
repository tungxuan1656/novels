import Foundation

enum LogKind: String, Sendable, Equatable {
    case event
    case api
}

struct LogEntry: Identifiable, Sendable, Equatable {
    let id: UUID = .init()
    let timestamp: Date = .init()
    let requestId: UUID
    let sessionId: UUID
    let kind: LogKind
    let bookId: String
    let chapterNumber: Int
    let mode: String
    let chunkIndex: Int?
    let chunkTotal: Int?
    let attempt: Int
    let latencyMs: Int
    // api-only
    let host: String?
    let statusCode: Int?
    let errorDomain: String?
    let errorCode: Int?
    let model: String?
    let responseLen: Int?
    let responseHashPrefix: String?
    // redacted payloads
    let headersRedacted: [String: String]?
    let bodyLen: Int?
    let bodyHashPrefix: String?
    let snippet: String?
    // event detail
    let event: String?
    let detail: String?
    // extras derived from response headers / transport
    let retryAfterMs: Int?
    let timeoutKind: String?

    init(
        requestId: UUID = UUID(),
        sessionId: UUID,
        kind: LogKind = .event,
        bookId: String = "",
        chapterNumber: Int = 0,
        mode: String = "rewrite",
        chunkIndex: Int? = nil,
        chunkTotal: Int? = nil,
        attempt: Int = 1,
        latencyMs: Int = 0,
        host: String? = nil,
        statusCode: Int? = nil,
        errorDomain: String? = nil,
        errorCode: Int? = nil,
        model: String? = nil,
        responseLen: Int? = nil,
        responseHashPrefix: String? = nil,
        headersRedacted: [String: String]? = nil,
        bodyLen: Int? = nil,
        bodyHashPrefix: String? = nil,
        snippet: String? = nil,
        event: String? = nil,
        detail: String? = nil,
        retryAfterMs: Int? = nil,
        timeoutKind: String? = nil
    ) {
        self.requestId = requestId
        self.sessionId = sessionId
        self.kind = kind
        self.bookId = bookId
        self.chapterNumber = chapterNumber
        self.mode = mode
        self.chunkIndex = chunkIndex
        self.chunkTotal = chunkTotal
        self.attempt = attempt
        self.latencyMs = latencyMs
        self.host = host
        self.statusCode = statusCode
        self.errorDomain = errorDomain
        self.errorCode = errorCode
        self.model = model
        self.responseLen = responseLen
        self.responseHashPrefix = responseHashPrefix
        self.headersRedacted = headersRedacted
        self.bodyLen = bodyLen
        self.bodyHashPrefix = bodyHashPrefix
        self.snippet = snippet
        self.event = event
        self.detail = detail
        self.retryAfterMs = retryAfterMs
        self.timeoutKind = timeoutKind
    }

    /// One-line OSLog summary. Never embeds raw secrets, prompts, or chapter text.
    nonisolated var debugSummary: String {
        let label = event ?? "api"
        var parts = ["\(kind.rawValue)", label, "\(bookId)#\(chapterNumber)"]
        if let chunkIndex, let chunkTotal {
            parts.append("chunk=\(chunkIndex + 1)/\(chunkTotal)")
        }
        parts.append("attempt=\(attempt)")
        if let statusCode {
            parts.append("status=\(statusCode)")
        }
        if let errorDomain {
            parts.append("err=\(errorDomain):\(errorCode ?? -1)")
        }
        parts.append("latencyMs=\(latencyMs)")
        if let timeoutKind {
            parts.append("timeout=\(timeoutKind)")
        }
        return parts.joined(separator: " ")
    }
}

/// Diagnostics context threaded through one chunk POST (shared across its retry attempts).
struct AIDiagnosticsContext: Sendable {
    let bookId: String
    let chapterNumber: Int
    let mode: String
    let chunkIndex: Int?
    let chunkTotal: Int?
    let requestId: UUID

    init(
        bookId: String = "",
        chapterNumber: Int = 0,
        mode: String = "rewrite",
        chunkIndex: Int? = nil,
        chunkTotal: Int? = nil,
        requestId: UUID? = nil
    ) {
        self.bookId = bookId
        self.chapterNumber = chapterNumber
        self.mode = mode
        self.chunkIndex = chunkIndex
        self.chunkTotal = chunkTotal
        self.requestId = requestId ?? UUID()
    }
}
