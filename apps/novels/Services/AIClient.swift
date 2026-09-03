import Foundation

// swiftlint:disable trailing_comma

// swiftlint:disable:next type_body_length
actor AIClient {
    static let requestTimeout: TimeInterval = 180
    static let resourceTimeout: TimeInterval = 600

    static func defaultConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        config.waitsForConnectivity = true
        return config
    }

    private let settings: SettingsStore
    private let session: URLSession

    init(settings: SettingsStore, session: URLSession? = nil) {
        self.settings = settings
        self.session = session ?? URLSession(configuration: Self.defaultConfiguration())
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func complete(
        prompt: String,
        chunk: String,
        context: AIDiagnosticsContext = AIDiagnosticsContext()
    ) async throws -> String {
        let urlString: String = await MainActor.run {
            let trimmed = settings.openaiAPIURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "http://localhost:8317/v1/chat/completions" : settings.openaiAPIURL
        }
        let model: String = await MainActor.run {
            settings.openaiModel.isEmpty ? "gpt-4o" : settings.openaiModel
        }
        let headers: [String: String] = await MainActor.run {
            settings.effectiveHeaders()
        }
        let extra: [String: Any] = await MainActor.run {
            settings.effectiveExtraBody()
        }
        let verbose: Bool = await MainActor.run {
            settings.diagnosticsVerbose
        }
        guard let url = URL(string: urlString) else {
            throw AIClientError.httpError(0, "bad url")
        }
        await logInvalidPayloadEvents(headers: headers, extra: extra, context: context)
        let chunkHash = DiagnosticsRedactor.hashPrefix(chunk)
        var lastError: Error?
        for attempt in 0 ..< 3 {
            let attemptNumber = attempt + 1
            let attemptStart = Date()
            func latencyMs() -> Int {
                Int(Date().timeIntervalSince(attemptStart) * 1000)
            }
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                var body: [String: Any] = [
                    "model": model,
                    "messages": [
                        ["role": "system", "content": prompt],
                        ["role": "user", "content": chunk],
                    ],
                ]
                for (key, value) in extra {
                    if key == "model" || key == "messages" || key == "stream" {
                        continue
                    }
                    body[key] = value
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = Self.requestTimeout
                let requestHeaders = request.allHTTPHeaderFields ?? [:]
                await DiagnosticsLog.shared.append(LogEntry(
                    requestId: context.requestId,
                    sessionId: DiagnosticsLog.sessionId,
                    kind: .api,
                    bookId: context.bookId,
                    chapterNumber: context.chapterNumber,
                    mode: context.mode,
                    chunkIndex: context.chunkIndex,
                    chunkTotal: context.chunkTotal,
                    attempt: attemptNumber,
                    latencyMs: 0,
                    host: DiagnosticsRedactor.endpointDisplay(url: url, verbose: verbose),
                    model: model,
                    headersRedacted: DiagnosticsRedactor.redactedHeaders(requestHeaders),
                    bodyLen: chunk.utf8.count,
                    bodyHashPrefix: chunkHash,
                    snippet: DiagnosticsRedactor.snippet(chunk, limit: 100, verbose: verbose)
                ))
                let (data, response) = try await session.data(for: request)
                let elapsed = latencyMs()
                let http = response as? HTTPURLResponse
                let statusCode = http?.statusCode ?? 0
                let retryAfter = http.flatMap { DiagnosticsRedactor.retryAfterMs(from: $0.allHeaderFields) }
                if let http, !(200 ... 299).contains(http.statusCode) {
                    await DiagnosticsLog.shared.append(LogEntry(
                        requestId: context.requestId,
                        sessionId: DiagnosticsLog.sessionId,
                        kind: .api,
                        bookId: context.bookId,
                        chapterNumber: context.chapterNumber,
                        mode: context.mode,
                        chunkIndex: context.chunkIndex,
                        chunkTotal: context.chunkTotal,
                        attempt: attemptNumber,
                        latencyMs: elapsed,
                        host: DiagnosticsRedactor.endpointDisplay(url: url, verbose: verbose),
                        statusCode: statusCode,
                        errorDomain: "AIClientError.httpError",
                        errorCode: statusCode,
                        model: model,
                        retryAfterMs: retryAfter
                    ))
                    throw AIClientError.httpError(
                        http.statusCode,
                        HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                    )
                }
                let decoded: AIChatResponse
                do {
                    decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
                } catch {
                    await DiagnosticsLog.shared.append(LogEntry(
                        requestId: context.requestId,
                        sessionId: DiagnosticsLog.sessionId,
                        kind: .api,
                        bookId: context.bookId,
                        chapterNumber: context.chapterNumber,
                        mode: context.mode,
                        chunkIndex: context.chunkIndex,
                        chunkTotal: context.chunkTotal,
                        attempt: attemptNumber,
                        latencyMs: elapsed,
                        host: DiagnosticsRedactor.endpointDisplay(url: url, verbose: verbose),
                        statusCode: statusCode,
                        errorDomain: "DecodingError",
                        errorCode: (error as NSError).code,
                        model: model,
                        responseLen: data.count,
                        responseHashPrefix: DiagnosticsRedactor.hashPrefix(
                            String(data: data, encoding: .utf8) ?? ""
                        ),
                        retryAfterMs: retryAfter
                    ))
                    throw AIClientError.noResponse
                }
                guard let content = decoded.choices.first?.message.content,
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    await DiagnosticsLog.shared.append(LogEntry(
                        requestId: context.requestId,
                        sessionId: DiagnosticsLog.sessionId,
                        kind: .api,
                        bookId: context.bookId,
                        chapterNumber: context.chapterNumber,
                        mode: context.mode,
                        chunkIndex: context.chunkIndex,
                        chunkTotal: context.chunkTotal,
                        attempt: attemptNumber,
                        latencyMs: elapsed,
                        host: DiagnosticsRedactor.endpointDisplay(url: url, verbose: verbose),
                        statusCode: statusCode,
                        errorDomain: "AIClientError.noResponse",
                        errorCode: 0,
                        model: model,
                        responseLen: data.count,
                        responseHashPrefix: DiagnosticsRedactor.hashPrefix(
                            String(data: data, encoding: .utf8) ?? ""
                        ),
                        retryAfterMs: retryAfter
                    ))
                    throw AIClientError.noResponse
                }
                await DiagnosticsLog.shared.append(LogEntry(
                    requestId: context.requestId,
                    sessionId: DiagnosticsLog.sessionId,
                    kind: .api,
                    bookId: context.bookId,
                    chapterNumber: context.chapterNumber,
                    mode: context.mode,
                    chunkIndex: context.chunkIndex,
                    chunkTotal: context.chunkTotal,
                    attempt: attemptNumber,
                    latencyMs: elapsed,
                    host: DiagnosticsRedactor.endpointDisplay(url: url, verbose: verbose),
                    statusCode: statusCode,
                    model: model,
                    responseLen: data.count,
                    responseHashPrefix: DiagnosticsRedactor.hashPrefix(content),
                    snippet: DiagnosticsRedactor.snippet(content, limit: 200, verbose: verbose),
                    retryAfterMs: retryAfter
                ))
                return content
            } catch {
                lastError = error
                if error is DecodingError {
                    throw AIClientError.noResponse
                }
                if case AIClientError.noResponse = error {
                    throw error
                }
                if case let AIClientError.httpError(code, _) = error {
                    if (400 ... 499).contains(code) {
                        throw error
                    }
                    if attempt < 2 {
                        await logRetry(context: context, attempt: attemptNumber, backoffMs: attemptBackoffMs(attempt))
                        let delay: UInt64 = attempt == 0 ? 1_000_000_000 : 2_000_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    } else {
                        throw lastError ?? error
                    }
                }
                if error is URLError || (error as NSError).domain == NSURLErrorDomain {
                    let urlError = error as? URLError
                    await DiagnosticsLog.shared.append(LogEntry(
                        requestId: context.requestId,
                        sessionId: DiagnosticsLog.sessionId,
                        kind: .api,
                        bookId: context.bookId,
                        chapterNumber: context.chapterNumber,
                        mode: context.mode,
                        chunkIndex: context.chunkIndex,
                        chunkTotal: context.chunkTotal,
                        attempt: attemptNumber,
                        latencyMs: latencyMs(),
                        host: DiagnosticsRedactor.endpointDisplay(url: url, verbose: verbose),
                        errorDomain: (error as NSError).domain,
                        errorCode: (error as NSError).code,
                        model: model,
                        timeoutKind: urlError?.code == .timedOut ? "timedOut" : nil
                    ))
                    if attempt < 2 {
                        await logRetry(context: context, attempt: attemptNumber, backoffMs: attemptBackoffMs(attempt))
                        let delay: UInt64 = attempt == 0 ? 1_000_000_000 : 2_000_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    } else {
                        throw lastError ?? AIClientError.httpError(0, "AI processing failed.")
                    }
                }
                // Programming errors (e.g., JSONSerialization) — do not retry
                throw error
            }
        }
        throw lastError ?? AIClientError.httpError(0, "AI processing failed.")
    }

    private func attemptBackoffMs(_ attempt: Int) -> Int {
        attempt == 0 ? 1000 : 2000
    }

    private func logRetry(context: AIDiagnosticsContext, attempt: Int, backoffMs: Int) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: context.requestId,
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: context.bookId,
            chapterNumber: context.chapterNumber,
            mode: context.mode,
            chunkIndex: context.chunkIndex,
            chunkTotal: context.chunkTotal,
            attempt: attempt,
            event: "retry.scheduled",
            detail: "backoffMs=\(backoffMs) nextAttempt=\(attempt + 1)"
        ))
    }

    private func logInvalidPayloadEvents(
        headers: [String: String],
        extra: [String: Any],
        context: AIDiagnosticsContext
    ) async {
        let headersTrimmed: String = await MainActor.run {
            settings.aiCustomHeadersJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let bodyTrimmed: String = await MainActor.run {
            settings.aiExtraBodyJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !headersTrimmed.isEmpty, headers.isEmpty {
            await DiagnosticsLog.shared.append(LogEntry(
                requestId: context.requestId,
                sessionId: DiagnosticsLog.sessionId,
                kind: .event,
                bookId: context.bookId,
                chapterNumber: context.chapterNumber,
                mode: context.mode,
                chunkIndex: context.chunkIndex,
                chunkTotal: context.chunkTotal,
                event: "invalid.headers",
                detail: "len=\(headersTrimmed.utf8.count) hash=\(DiagnosticsRedactor.hashPrefix(headersTrimmed))"
            ))
        }
        if !bodyTrimmed.isEmpty, extra.isEmpty {
            await DiagnosticsLog.shared.append(LogEntry(
                requestId: context.requestId,
                sessionId: DiagnosticsLog.sessionId,
                kind: .event,
                bookId: context.bookId,
                chapterNumber: context.chapterNumber,
                mode: context.mode,
                chunkIndex: context.chunkIndex,
                chunkTotal: context.chunkTotal,
                event: "invalid.body",
                detail: "len=\(bodyTrimmed.utf8.count) hash=\(DiagnosticsRedactor.hashPrefix(bodyTrimmed))"
            ))
        }
    }
}

// swiftlint:enable trailing_comma
