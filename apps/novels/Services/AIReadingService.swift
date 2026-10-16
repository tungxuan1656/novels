import CryptoKit
import Foundation

// swiftlint:disable:next type_body_length
actor AIReadingService {
    private let cache: ProcessedChapterCaching
    private let client: AIClient
    private let settings: SettingsStore
    private var inFlight: [String: Task<String, Error>] = [:]
    private var inFlightTokens: [String: UUID] = [:]
    private var inFlightRunIds: [String: UUID] = [:]
    private var inFlightWaiters: [String: Set<UUID>] = [:]

    init(cache: ProcessedChapterCaching, client: AIClient, settings: SettingsStore) {
        self.cache = cache
        self.client = client
        self.settings = settings
    }

    private func key(bookId: String, chapter: Int, mode: AIMode) -> String {
        "\(bookId)#\(chapter)#\(mode.rawValue)"
    }

    private func keyHash(_ cacheKey: String) -> String {
        String(SHA256.hex(cacheKey).prefix(8))
    }

    // swiftlint:disable:next function_parameter_count
    private func logChunk(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        chunkIndex: Int?,
        chunkTotal: Int,
        requestId: UUID,
        event: String,
        detail: String,
        latencyMs: Int = 0,
        bodyLen: Int? = nil,
        bodyHashPrefix: String? = nil,
        responseLen: Int? = nil,
        responseHashPrefix: String? = nil,
        errorDomain: String? = nil,
        errorCode: Int? = nil,
        runId: UUID? = nil
    ) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: requestId,
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode.rawValue,
            chunkIndex: chunkIndex,
            chunkTotal: chunkTotal,
            latencyMs: latencyMs,
            errorDomain: errorDomain,
            errorCode: errorCode,
            responseLen: responseLen,
            responseHashPrefix: responseHashPrefix,
            bodyLen: bodyLen,
            bodyHashPrefix: bodyHashPrefix,
            event: event,
            detail: detail,
            runId: runId
        ))
    }

    private func logCache(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        event: String,
        detail: String,
        runId: UUID? = nil
    ) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: UUID(),
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode.rawValue,
            event: event,
            detail: detail,
            runId: runId
        ))
    }

    // Parallel per-chunk TaskGroup with chunk.start/success/fail events.
    // Retry per-chunk happens inside `client.complete` (2 attempts); fail-fast, no partial cache.
    // swiftlint:disable:next function_parameter_count function_body_length
    private func processChunks(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        prompt: String,
        chunks: [String],
        expectedIDs: [[String]],
        cacheKey: String,
        runId: UUID
    ) async throws -> String {
        let total = chunks.count
        let hash = keyHash(cacheKey)
        let capturedClient = client
        let capturedBookId = bookId
        let capturedChapter = chapterNumber
        let capturedMode = mode.rawValue
        let capturedPrompt = prompt
        let capturedRun = runId
        let isBilingual = !expectedIDs.isEmpty
        return try await withThrowingTaskGroup(of: (Int, String, [BilingualParagraph]).self) { group in
            for (index, chunk) in chunks.enumerated() {
                group.addTask {
                    let requestId = UUID()
                    let chunkStart = Date()
                    await DiagnosticsLog.shared.append(LogEntry(
                        requestId: requestId,
                        sessionId: DiagnosticsLog.sessionId,
                        kind: .event,
                        bookId: capturedBookId,
                        chapterNumber: capturedChapter,
                        mode: capturedMode,
                        chunkIndex: index,
                        chunkTotal: total,
                        bodyLen: chunk.utf8.count,
                        bodyHashPrefix: DiagnosticsRedactor.hashPrefix(chunk),
                        event: "chunk.start",
                        detail: "chunkCount=\(total) keyHash=\(hash)",
                        runId: capturedRun
                    ))
                    let context = AIDiagnosticsContext(
                        bookId: capturedBookId,
                        chapterNumber: capturedChapter,
                        mode: capturedMode,
                        chunkIndex: index,
                        chunkTotal: total,
                        requestId: requestId,
                        runId: capturedRun
                    )
                    var receivedResponse = false
                    do {
                        let out = try await capturedClient.complete(
                            prompt: capturedPrompt,
                            chunk: chunk,
                            context: context,
                            outputSchema: isBilingual ? BilingualChapter.outputSchema : nil
                        )
                        receivedResponse = true
                        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
                        let pairs = isBilingual ? try BilingualChapter.decodeResponse(
                            trimmed, expectedIDs: expectedIDs[index]
                        ) : []
                        let latencyMs = Int(Date().timeIntervalSince(chunkStart) * 1000)
                        await DiagnosticsLog.shared.append(LogEntry(
                            requestId: requestId,
                            sessionId: DiagnosticsLog.sessionId,
                            kind: .event,
                            bookId: capturedBookId,
                            chapterNumber: capturedChapter,
                            mode: capturedMode,
                            chunkIndex: index,
                            chunkTotal: total,
                            latencyMs: latencyMs,
                            responseLen: trimmed.utf8.count,
                            responseHashPrefix: DiagnosticsRedactor.hashPrefix(trimmed),
                            event: "chunk.success",
                            detail: "keyHash=\(hash)",
                            runId: capturedRun
                        ))
                        return (index, trimmed, pairs)
                    } catch {
                        if error is CancellationError {
                            throw error
                        }
                        let latencyMs = Int(Date().timeIntervalSince(chunkStart) * 1000)
                        let nsError = error as NSError
                        await DiagnosticsLog.shared.append(LogEntry(
                            requestId: requestId,
                            sessionId: DiagnosticsLog.sessionId,
                            kind: .event,
                            bookId: capturedBookId,
                            chapterNumber: capturedChapter,
                            mode: capturedMode,
                            chunkIndex: index,
                            chunkTotal: total,
                            latencyMs: latencyMs,
                            errorDomain: nsError.domain,
                            errorCode: nsError.code,
                            event: "chunk.fail",
                            detail: "stage=\(receivedResponse ? "validation" : "request") keyHash=\(hash)",
                            runId: capturedRun
                        ))
                        throw error
                    }
                }
            }
            var buffer = [String?](repeating: nil, count: total)
            var pairs = [[BilingualParagraph]](repeating: [], count: total)
            for try await(index, text, paragraphs) in group {
                buffer[index] = text
                pairs[index] = paragraphs
            }
            if isBilingual {
                return try BilingualChapter(paragraphs: pairs.flatMap { $0 }).encoded()
            }
            return buffer.compactMap { $0 }.joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // Shared chunk/process/cache pipeline used by both entry points.
    // Callers wrap this in a single Task registered in `inFlight[cacheKey]`.
    // swiftlint:disable:next function_parameter_count
    private func runPipeline(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        rawText: String,
        cacheKey: String,
        runId: UUID
    ) async throws -> String {
        let chunkSize: Int = await MainActor.run { settings.aiMinChunkSize }
        let size = (500 ... 10000).contains(chunkSize) ? chunkSize : 1300
        let prompt: String = await MainActor.run {
            AIPromptBuilder.prompt(
                for: mode, customPrompt: settings.aiPrompt, bilingualPrompt: settings.aiBilingualPrompt
            )
        }
        let bilingualChunks = mode == .bilingual ? BilingualSourceChunker.chunks(text: rawText, size: size) : []
        let chunks = mode == .bilingual ? try bilingualChunks.map { try $0.encoded() } :
            AIChunker.chunk(text: rawText, size: size)
        let expectedIDs = bilingualChunks.map { $0.paragraphs.map(\.id) }
        if chunks.isEmpty {
            throw AIClientError.noResponse
        }
        await logCache(
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode,
            event: "cache.miss",
            detail: "chunkCount=\(chunks.count) keyHash=\(keyHash(cacheKey))",
            runId: runId
        )
        let joined = try await processChunks(
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode,
            prompt: prompt,
            chunks: chunks,
            expectedIDs: expectedIDs,
            cacheKey: cacheKey,
            runId: runId
        )
        guard !joined.isEmpty else {
            throw AIClientError.noResponse
        }
        let hash = SHA256.hex(joined)
        let now = Date()
        let pc = ProcessedChapter(
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode,
            content: joined,
            contentHash: hash,
            createdAt: now,
            updatedAt: now
        )
        try Task.checkCancellation()
        try cache.upsert(pc)
        await logCache(
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode,
            event: "cache.save",
            detail: "chunkCount=\(chunks.count) outputHash=\(String(hash.prefix(8))) keyHash=\(keyHash(cacheKey))",
            runId: runId
        )
        return joined
    }

    private func registerWaiter(cacheKey: String) -> UUID {
        let waiter = UUID()
        inFlightWaiters[cacheKey, default: []].insert(waiter)
        return waiter
    }

    private func releaseWaiter(cacheKey: String, token: UUID, waiter: UUID) {
        guard inFlightTokens[cacheKey] == token else { return }
        inFlightWaiters[cacheKey]?.remove(waiter)
        guard inFlightWaiters[cacheKey]?.isEmpty == true else { return }
        // One cancelled reader must not cancel a request still used by prefetch, or vice versa.
        inFlight[cacheKey]?.cancel()
        inFlight[cacheKey] = nil
        inFlightTokens[cacheKey] = nil
        inFlightRunIds[cacheKey] = nil
        inFlightWaiters[cacheKey] = nil
    }

    private func waitForTask(
        _ task: Task<String, Error>, cacheKey: String, token: UUID, waiter: UUID
    ) async throws -> String {
        defer { releaseWaiter(cacheKey: cacheKey, token: token, waiter: waiter) }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let result = await task.result
            try Task.checkCancellation()
            return try result.get()
        } onCancel: {
            Task { await self.releaseWaiter(cacheKey: cacheKey, token: token, waiter: waiter) }
        }
    }

    func processedContent(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        rawText: String,
        runId: UUID? = nil,
        source: String = "reader"
    ) async throws -> String {
        try await processWithBackgroundLease(
            bookId: bookId, chapterNumber: chapterNumber, mode: mode, rawText: rawText,
            runId: runId ?? UUID(), source: source, refresh: false
        )
    }

    func reprocess(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        rawText: String,
        runId: UUID? = nil
    ) async throws -> String {
        try await processWithBackgroundLease(
            bookId: bookId, chapterNumber: chapterNumber, mode: mode, rawText: rawText,
            runId: runId ?? UUID(), source: "manual", refresh: true
        )
    }

    // Hold a finite UIKit assertion; user-started continued tasks own their longer lifetime.
    // swiftlint:disable:next function_parameter_count
    private func processWithBackgroundLease(
        bookId: String, chapterNumber: Int, mode: AIMode, rawText: String,
        runId: UUID, source: String, refresh: Bool
    ) async throws -> String {
        await BackgroundAIExecution.shared.operationStarted()
        do {
            let result = try await process(
                bookId: bookId, chapterNumber: chapterNumber, mode: mode,
                rawText: rawText, runId: runId, source: source, refresh: refresh
            )
            await BackgroundAIExecution.shared.operationFinished()
            return result
        } catch {
            await BackgroundAIExecution.shared.operationFinished()
            throw error
        }
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    private func process(
        bookId: String, chapterNumber: Int, mode: AIMode, rawText: String,
        runId: UUID, source: String, refresh: Bool
    ) async throws -> String {
        guard mode != .none else { return rawText }
        try Task.checkCancellation()
        await logCache(
            bookId: bookId, chapterNumber: chapterNumber, mode: mode,
            event: "run.start", detail: "source=\(source)", runId: runId
        )
        do {
            if !refresh, let cached = try? cache.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode) {
                if mode == .bilingual {
                    _ = try BilingualChapter.decode(cached.content)
                }
                await logCache(
                    bookId: bookId, chapterNumber: chapterNumber, mode: mode,
                    event: "cache.hit",
                    detail: "keyHash=\(keyHash(key(bookId: bookId, chapter: chapterNumber, mode: mode)))",
                    runId: runId
                )
                return cached.content
            }
            let cacheKey = key(bookId: bookId, chapter: chapterNumber, mode: mode)
            if refresh, let existing = inFlight[cacheKey] {
                existing.cancel()
                inFlight[cacheKey] = nil
                inFlightTokens[cacheKey] = nil
                inFlightRunIds[cacheKey] = nil
                inFlightWaiters[cacheKey] = nil
            }
            let task: Task<String, Error>
            let token: UUID
            let originRunId = inFlightRunIds[cacheKey]
            if let existing = inFlight[cacheKey], let existingToken = inFlightTokens[cacheKey] {
                task = existing
                token = existingToken
            } else {
                task = Task {
                    try await self.runPipeline(
                        bookId: bookId, chapterNumber: chapterNumber, mode: mode,
                        rawText: rawText, cacheKey: cacheKey, runId: runId
                    )
                }
                token = UUID()
                inFlight[cacheKey] = task
                inFlightTokens[cacheKey] = token
                inFlightRunIds[cacheKey] = runId
            }
            let waiter = registerWaiter(cacheKey: cacheKey)
            if let originRunId {
                await logCache(
                    bookId: bookId, chapterNumber: chapterNumber, mode: mode,
                    event: "dedup.shared",
                    detail: "keyHash=\(keyHash(cacheKey)) originRunId=\(originRunId.uuidString)", runId: runId
                )
            }
            let content = try await waitForTask(task, cacheKey: cacheKey, token: token, waiter: waiter)
            await logCache(
                bookId: bookId, chapterNumber: chapterNumber, mode: mode,
                event: "run.success", detail: "source=\(source)", runId: runId
            )
            return content
        } catch {
            let cancelled = error is CancellationError
            let nsError = error as NSError
            await DiagnosticsLog.shared.append(LogEntry(
                sessionId: DiagnosticsLog.sessionId, bookId: bookId, chapterNumber: chapterNumber,
                mode: mode.rawValue, errorDomain: cancelled ? nil : nsError.domain,
                errorCode: cancelled ? nil : nsError.code, event: cancelled ? "run.cancel" : "run.fail",
                detail: "source=\(source)", runId: runId
            ))
            throw error
        }
    }
}
