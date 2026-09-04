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

/// Safe response-shape parser (feat-017). JSONSerialization only, kinds/counts/keys — never raw values.
struct AIResponseShape: Sendable, Equatable {
    let responseJsonKeys: [String]?
    let choicesCount: Int?
    let contentKind: String?
    let hasReasoningContent: Bool?
    let hasToolCalls: Bool?

    static func parse(_ data: Data) -> AIResponseShape {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else {
            return AIResponseShape(
                responseJsonKeys: nil,
                choicesCount: nil,
                contentKind: nil,
                hasReasoningContent: nil,
                hasToolCalls: nil
            )
        }
        let keys = Array(dict.keys).sorted().prefix(10).map { $0 }
        var count: Int?
        var kind = "missing"
        var hasReasoning = false
        var hasTools = false
        if let choices = dict["choices"] as? [[String: Any]] {
            count = choices.count
            if let first = choices.first {
                let message = first["message"] as? [String: Any] ?? [:]
                kind = contentKind(of: message["content"])
                hasReasoning = isNonEmptyString(message["reasoning_content"])
                    || isNonEmptyString(first["reasoning_content"])
                hasTools = isNonEmptyArray(message["tool_calls"]) || isNonEmptyArray(first["tool_calls"])
            }
        } else if let output = dict["output"] as? [[String: Any]] {
            count = output.count
            if dict.keys.contains("output_text") {
                kind = contentKind(of: dict["output_text"])
            } else {
                kind = responsesTextKind(from: output)
            }
            hasReasoning = output.contains { ($0["type"] as? String) == "reasoning" }
            hasTools = output.contains { ($0["type"] as? String) == "function_call" }
        } else if let content = dict["content"] as? [[String: Any]] {
            count = content.count
            if let firstText = content.first(where: { ($0["type"] as? String) == "text" }) {
                kind = contentKind(of: firstText["text"])
            } else {
                kind = "missing"
            }
            hasReasoning = content.contains {
                ($0["type"] as? String) == "thinking" || ($0["type"] as? String) == "redacted_thinking"
            }
            hasTools = content.contains {
                ($0["type"] as? String) == "tool_use" || ($0["type"] as? String) == "server_tool_use"
            }
        }
        return AIResponseShape(
            responseJsonKeys: keys,
            choicesCount: count,
            contentKind: kind,
            hasReasoningContent: hasReasoning,
            hasToolCalls: hasTools
        )
    }

    static func contentKind(of value: Any?) -> String {
        guard let value else { return "missing" }
        if value is NSNull {
            return "null"
        }
        if let text = value as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "empty-string" : "ok"
        }
        return "missing"
    }

    private static func isNonEmptyString(_ value: Any?) -> Bool {
        guard let text = value as? String else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func isNonEmptyArray(_ value: Any?) -> Bool {
        guard let array = value as? [Any] else { return false }
        return !array.isEmpty
    }

    private static func responsesTextKind(from output: [[String: Any]]) -> String {
        for item in output where (item["type"] as? String) == "message" {
            guard let blocks = item["content"] as? [[String: Any]] else { continue }
            for block in blocks where (block["type"] as? String) == "output_text" {
                if block.keys.contains("text") {
                    return contentKind(of: block["text"])
                }
            }
        }
        return "missing"
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

    var errorCount: Int {
        entries.filter { $0.event == "chunk.fail" || $0.errorCode != nil }.count
    }

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
