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

    // swiftlint:disable:next function_body_length
    func complete(
        prompt: String,
        chunk: String,
        context: AIDiagnosticsContext = AIDiagnosticsContext()
    ) async throws -> String {
        // One MainActor hop for all settings reads (A4).
        // swiftlint:disable:next large_tuple
        let settingsSnapshot: (
            urlRaw: String,
            modelRaw: String,
            headers: [String: String],
            extra: [String: Any],
            verbose: Bool
        ) = await MainActor.run {
            (
                urlRaw: settings.openaiAPIURL,
                modelRaw: settings.openaiModel,
                headers: settings.effectiveHeaders(),
                extra: settings.effectiveExtraBody(),
                verbose: settings.diagnosticsVerbose
            )
        }
        let trimmedURL = settingsSnapshot.urlRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmedURL.isEmpty ? "http://localhost:8317/v1/chat/completions" : trimmedURL
        let model = settingsSnapshot.modelRaw.isEmpty ? "gpt-4o" : settingsSnapshot.modelRaw
        let headers = settingsSnapshot.headers
        let extra = settingsSnapshot.extra
        let verbose = settingsSnapshot.verbose
        guard let url = URL(string: urlString) else {
            throw AIClientError.httpError(0, "bad url")
        }
        await logInvalidPayloadEvents(headers: headers, extra: extra, context: context)
        let chunkHash = DiagnosticsRedactor.hashPrefix(chunk)
        try Task.checkCancellation()
        // S3: serialize the request body once up front. Invalid extraBody types
        // (e.g. string for a numeric field) are deterministic programming errors:
        // log once and fail without retry so the broken payload is not double-fired.
        let requestBodyData: Data
        do {
            requestBodyData = try Self.makeRequestBodyData(
                model: model,
                prompt: prompt,
                chunk: chunk,
                extra: extra
            )
        } catch {
            let nsError = error as NSError
            await recordApiAttempt(
                context: context,
                attempt: 1,
                latencyMs: 0,
                urlString: url.absoluteString,
                model: model,
                errorDomain: nsError.domain,
                errorCode: nsError.code,
                bodyLen: chunk.utf8.count,
                bodyHashPrefix: chunkHash,
                snippet: DiagnosticsRedactor.snippet(chunk, limit: 100, verbose: verbose)
            )
            throw error
        }
        let requestBodyStringConstant = String(data: requestBodyData, encoding: .utf8)
        var lastError: Error?
        for attemptNumber in 1 ... 2 {
            let attemptStart = Date()
            func latencyMs() -> Int {
                Int(Date().timeIntervalSince(attemptStart) * 1000)
            }
            var requestBodyString: String? = requestBodyStringConstant
            do {
                try Task.checkCancellation()
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                request.httpBody = requestBodyData
                request.timeoutInterval = Self.requestTimeout
                let requestHeaders = request.allHTTPHeaderFields ?? [:]
                requestBodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
                await recordApiAttempt(
                    context: context,
                    attempt: attemptNumber,
                    latencyMs: 0,
                    urlString: url.absoluteString,
                    model: model,
                    headersRedacted: DiagnosticsRedactor.redactedHeaders(requestHeaders),
                    bodyLen: chunk.utf8.count,
                    bodyHashPrefix: chunkHash,
                    snippet: DiagnosticsRedactor.snippet(chunk, limit: 100, verbose: verbose),
                    requestBody: requestBodyString
                )
                let (data, response) = try await session.data(for: request)
                let elapsed = latencyMs()
                let responseBodyString = String(data: data, encoding: .utf8)
                let http = response as? HTTPURLResponse
                let statusCode = http?.statusCode ?? 0
                let retryAfter = http.flatMap { DiagnosticsRedactor.retryAfterMs(from: $0.allHeaderFields) }
                if let http, !(200 ... 299).contains(http.statusCode) {
                    await recordApiAttempt(
                        context: context,
                        attempt: attemptNumber,
                        latencyMs: elapsed,
                        urlString: url.absoluteString,
                        model: model,
                        statusCode: statusCode,
                        errorDomain: "AIClientError.httpError",
                        errorCode: statusCode,
                        retryAfterMs: retryAfter,
                        requestBody: requestBodyString,
                        responseBody: responseBodyString
                    )
                    throw AIClientError.httpError(
                        http.statusCode,
                        HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                    )
                }
                let shape = AIResponseShape.parse(data)
                let decoded: AIChatResponse
                do {
                    decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
                } catch {
                    await recordApiAttempt(
                        context: context,
                        attempt: attemptNumber,
                        latencyMs: elapsed,
                        urlString: url.absoluteString,
                        model: model,
                        statusCode: statusCode,
                        errorDomain: "DecodingError",
                        errorCode: (error as NSError).code,
                        responseLen: data.count,
                        responseHashPrefix: DiagnosticsRedactor.hashPrefix(
                            String(data: data, encoding: .utf8) ?? ""
                        ),
                        retryAfterMs: retryAfter,
                        responseJsonKeys: shape.responseJsonKeys,
                        choicesCount: shape.choicesCount,
                        contentKind: shape.contentKind,
                        hasReasoningContent: shape.hasReasoningContent,
                        hasToolCalls: shape.hasToolCalls,
                        requestBody: requestBodyString,
                        responseBody: responseBodyString
                    )
                    throw AIClientError.noResponse
                }
                guard let content = decoded.resolvedText
                else {
                    await recordApiAttempt(
                        context: context,
                        attempt: attemptNumber,
                        latencyMs: elapsed,
                        urlString: url.absoluteString,
                        model: model,
                        statusCode: statusCode,
                        errorDomain: "AIClientError.noResponse",
                        errorCode: 0,
                        responseLen: data.count,
                        responseHashPrefix: DiagnosticsRedactor.hashPrefix(
                            String(data: data, encoding: .utf8) ?? ""
                        ),
                        retryAfterMs: retryAfter,
                        responseJsonKeys: shape.responseJsonKeys,
                        choicesCount: shape.choicesCount,
                        contentKind: shape.contentKind,
                        hasReasoningContent: shape.hasReasoningContent,
                        hasToolCalls: shape.hasToolCalls,
                        requestBody: requestBodyString,
                        responseBody: responseBodyString
                    )
                    throw AIClientError.noResponse
                }
                await recordApiAttempt(
                    context: context,
                    attempt: attemptNumber,
                    latencyMs: elapsed,
                    urlString: url.absoluteString,
                    model: model,
                    statusCode: statusCode,
                    snippet: DiagnosticsRedactor.snippet(content, limit: 200, verbose: verbose),
                    responseLen: data.count,
                    responseHashPrefix: DiagnosticsRedactor.hashPrefix(content),
                    retryAfterMs: retryAfter,
                    requestBody: requestBodyString,
                    responseBody: responseBodyString
                )
                return content
            } catch {
                if error is CancellationError {
                    throw CancellationError()
                }
                if error is DecodingError {
                    lastError = AIClientError.noResponse
                } else if case AIClientError.noResponse = error {
                    lastError = error
                } else if case AIClientError.httpError = error {
                    lastError = error
                } else if error is URLError || (error as NSError).domain == NSURLErrorDomain {
                    let urlError = error as? URLError
                    await recordApiAttempt(
                        context: context,
                        attempt: attemptNumber,
                        latencyMs: latencyMs(),
                        urlString: url.absoluteString,
                        model: model,
                        errorDomain: (error as NSError).domain,
                        errorCode: (error as NSError).code,
                        timeoutKind: urlError?.code == .timedOut ? "timedOut" : nil,
                        requestBody: requestBodyString
                    )
                    lastError = error
                } else {
                    // Any other error inside the attempt loop is retryable once.
                    // (Request-body serialization already failed fast above, before retry.)
                    lastError = error
                }
                if attemptNumber == 2 {
                    throw lastError ?? error
                }
                continue
            }
        }
        throw lastError ?? AIClientError.noResponse
    }

    private static func makeRequestBodyData(
        model: String,
        prompt: String,
        chunk: String,
        extra: [String: Any]
    ) throws -> Data {
        var baseBody: [String: Any] = [
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
            baseBody[key] = value
        }
        return try JSONSerialization.data(withJSONObject: baseBody)
    }

    /// Single helper for all per-attempt `.api` log entries (A1/A4).
    /// Same fields, redaction, and requestBody/responseBody threading as before.
    private func recordApiAttempt(
        context: AIDiagnosticsContext,
        attempt: Int,
        latencyMs: Int,
        urlString: String,
        model: String,
        statusCode: Int? = nil,
        errorDomain: String? = nil,
        errorCode: Int? = nil,
        headersRedacted: [String: String]? = nil,
        bodyLen: Int? = nil,
        bodyHashPrefix: String? = nil,
        snippet: String? = nil,
        responseLen: Int? = nil,
        responseHashPrefix: String? = nil,
        retryAfterMs: Int? = nil,
        timeoutKind: String? = nil,
        responseJsonKeys: [String]? = nil,
        choicesCount: Int? = nil,
        contentKind: String? = nil,
        hasReasoningContent: Bool? = nil,
        hasToolCalls: Bool? = nil,
        requestBody: String? = nil,
        responseBody: String? = nil
    ) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: context.requestId,
            sessionId: DiagnosticsLog.sessionId,
            kind: .api,
            bookId: context.bookId,
            chapterNumber: context.chapterNumber,
            mode: context.mode,
            chunkIndex: context.chunkIndex,
            chunkTotal: context.chunkTotal,
            attempt: attempt,
            latencyMs: latencyMs,
            host: urlString,
            statusCode: statusCode,
            errorDomain: errorDomain,
            errorCode: errorCode,
            model: model,
            responseLen: responseLen,
            responseHashPrefix: responseHashPrefix,
            headersRedacted: headersRedacted,
            bodyLen: bodyLen,
            bodyHashPrefix: bodyHashPrefix,
            snippet: snippet,
            retryAfterMs: retryAfterMs,
            timeoutKind: timeoutKind,
            responseJsonKeys: responseJsonKeys,
            choicesCount: choicesCount,
            contentKind: contentKind,
            hasReasoningContent: hasReasoningContent,
            hasToolCalls: hasToolCalls,
            runId: context.runId,
            requestBody: requestBody,
            responseBody: responseBody
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
                detail: "len=\(headersTrimmed.utf8.count) hash=\(DiagnosticsRedactor.hashPrefix(headersTrimmed))",
                runId: context.runId
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
                detail: "len=\(bodyTrimmed.utf8.count) hash=\(DiagnosticsRedactor.hashPrefix(bodyTrimmed))",
                runId: context.runId
            ))
        }
    }
}

// swiftlint:enable trailing_comma
