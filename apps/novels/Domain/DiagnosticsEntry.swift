import Foundation

enum LogKind: String, Sendable, Equatable {
    case event
    case api
}

struct LogEntry: Identifiable, Sendable, Equatable {
    let id: UUID = .init()
    let timestamp: Date
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
    // safe response shape (no raw body, ≤10 keys, kinds only)
    let responseJsonKeys: [String]?
    let choicesCount: Int?
    let contentKind: String?
    let hasReasoningContent: Bool?
    let hasToolCalls: Bool?
    // chapter-run grouping + raw bodies (RAM-only, never persisted; never in debugSummary/OSLog)
    let runId: UUID?
    let requestBody: String?
    let responseBody: String?

    init(
        requestId: UUID = UUID(),
        timestamp: Date = Date(),
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
        timeoutKind: String? = nil,
        responseJsonKeys: [String]? = nil,
        choicesCount: Int? = nil,
        contentKind: String? = nil,
        hasReasoningContent: Bool? = nil,
        hasToolCalls: Bool? = nil,
        runId: UUID? = nil,
        requestBody: String? = nil,
        responseBody: String? = nil
    ) {
        self.requestId = requestId
        self.timestamp = timestamp
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
        self.responseJsonKeys = responseJsonKeys
        self.choicesCount = choicesCount
        self.contentKind = contentKind
        self.hasReasoningContent = hasReasoningContent
        self.hasToolCalls = hasToolCalls
        self.runId = runId
        self.requestBody = requestBody
        self.responseBody = responseBody
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
        if let choicesCount {
            parts.append("choices=\(choicesCount)")
        }
        if let contentKind {
            parts.append("content=\(contentKind)")
        }
        return parts.joined(separator: " ")
    }
}

/// Shared error predicates for log entries. Lives in Domain so both the
/// diagnostics store (Services) and the viewer (Features) use one definition.
extension LogEntry {
    /// Deliberate navigation/disappear/manual cancels — muted Cancelled, never Failed-red.
    /// Anything else (`budgetExhausted`, `bookDeleted`, unknown or missing reason) stays an error.
    static let mutedCancelReasons: Set<String> = ["chapterChange", "modeChange", "disappear", "manual", "testDone"]

    /// Extracts `reason=<token>` from a `prefetch.cancel` detail
    /// (`"reason=budgetExhausted scope=global"` → `"budgetExhausted"`).
    static func cancelReason(of entry: LogEntry) -> String? {
        guard entry.event == "prefetch.cancel",
              let detail = entry.detail,
              let range = detail.range(of: "reason=")
        else { return nil }
        let token = detail[range.upperBound...].prefix(while: { !$0.isWhitespace })
        return token.isEmpty ? nil : String(token)
    }

    static func isMutedCancel(_ entry: LogEntry) -> Bool {
        guard let reason = cancelReason(of: entry) else { return false }
        return mutedCancelReasons.contains(reason)
    }

    /// Error heuristic behind the error filter tab, the store badge, and run status.
    /// Muted cancels are intentional control flow, never errors:
    /// cancelled rows stay non-red and the error tab never lists them.
    static func isError(_ entry: LogEntry) -> Bool {
        if isMutedCancel(entry) {
            return false
        }
        if let code = entry.statusCode, code >= 400 {
            return true
        }
        if entry.errorDomain != nil || entry.errorCode != nil {
            return true
        }
        let marker = (entry.event ?? "").lowercased()
        return marker.contains("fail") || marker.contains("error")
            || marker.contains("timeout") || marker.contains("cancel")
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
    let runId: UUID?

    init(
        bookId: String = "",
        chapterNumber: Int = 0,
        mode: String = "rewrite",
        chunkIndex: Int? = nil,
        chunkTotal: Int? = nil,
        requestId: UUID? = nil,
        runId: UUID? = nil
    ) {
        self.bookId = bookId
        self.chapterNumber = chapterNumber
        self.mode = mode
        self.chunkIndex = chunkIndex
        self.chunkTotal = chunkTotal
        self.requestId = requestId ?? UUID()
        self.runId = runId
    }
}
