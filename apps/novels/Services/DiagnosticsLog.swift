import Foundation
import Observation
import OSLog

// swiftlint:disable trailing_comma

/// Redaction helpers for feat-014. Safe default: never emit raw secrets,
/// prompts, or chapter text. Verbose only adds short head snippets.
enum DiagnosticsRedactor {
    static let redactedValue = "<redacted>"

    private static let sensitiveTokens = [
        "authorization", "token", "api-key", "api_key", "apikey",
        "secret", "bearer", "x-api-key", "cookie", "set-cookie",
    ]

    static func isSensitiveHeader(_ name: String) -> Bool {
        let lower = name.lowercased()
        return sensitiveTokens.contains { lower.contains($0) }
    }

    static func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        out.reserveCapacity(headers.count)
        for (key, value) in headers {
            out[key] = isSensitiveHeader(key) ? redactedValue : value
        }
        return out
    }

    static func hashPrefix(_ text: String, length: Int = 8) -> String {
        String(SHA256.hex(text).prefix(length))
    }

    /// Default host-only; verbose adds path (never query).
    static func endpointDisplay(url: URL?, verbose: Bool) -> String? {
        guard let host = url?.host, !host.isEmpty else { return nil }
        if verbose {
            let path = url?.path ?? ""
            if !path.isEmpty, path != "/" {
                return host + path
            }
        }
        return host
    }

    /// Head snippet, only when verbose. Callers must pass chunk/response heads only — never the system prompt.
    static func snippet(_ text: String, limit: Int, verbose: Bool) -> String? {
        guard verbose, !text.isEmpty else { return nil }
        if text.count <= limit {
            return text
        }
        return String(text.prefix(limit)) + "…"
    }

    /// Case-insensitive `Retry-After` (seconds) → milliseconds.
    static func retryAfterMs(from headerFields: [AnyHashable: Any]) -> Int? {
        for (key, value) in headerFields {
            guard let name = key as? String, name.lowercased() == "retry-after" else { continue }
            let raw = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
            if let seconds = Double(raw) {
                return Int(seconds * 1000)
            }
            return nil
        }
        return nil
    }
}

/// In-memory ring buffer (≤500 entries, FIFO). Cleared on launch — fresh actor state, no persistence.
actor DiagnosticsLog {
    static let shared = DiagnosticsLog()
    static let sessionId = UUID()
    static let capacity = 500

    private static let logger = Logger(
        subsystem: "com.tungxuan.novels.diagnostics",
        category: "diagnostics"
    )

    private var buffer: [LogEntry] = []

    func append(_ entry: LogEntry) {
        if buffer.count >= Self.capacity {
            buffer.removeFirst(buffer.count - Self.capacity + 1)
        }
        buffer.append(entry)
        Self.logger.info("\(entry.debugSummary, privacy: .private)")
    }

    func snapshot() -> [LogEntry] {
        buffer
    }

    func entryCount() -> Int {
        buffer.count
    }

    func clear() {
        buffer.removeAll()
    }
}

/// UI-binding mirror of `DiagnosticsLog`. The ring lives in the actor; the UI reads via `refresh()`.
@MainActor
@Observable
final class DiagnosticsStore {
    static let shared = DiagnosticsStore()

    var entries: [LogEntry] = []

    init() {}

    func refresh() async {
        entries = await DiagnosticsLog.shared.snapshot()
    }

    func clear() async {
        await DiagnosticsLog.shared.clear()
        entries.removeAll()
    }
}

// swiftlint:enable trailing_comma
