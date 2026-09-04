import CryptoKit
import Foundation

// swiftlint:disable:next type_body_length
actor AIReadingService {
    private let cache: ProcessedChapterCaching
    private let client: AIClient
    private let settings: SettingsStore
    private var inFlight: [String: Task<String, Error>] = [:]
    private var inFlightTokens: [String: UUID] = [:]

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
        return try await withThrowingTaskGroup(of: (Int, String).self) { group in
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
                    do {
                        let out = try await capturedClient.complete(
                            prompt: capturedPrompt,
                            chunk: chunk,
                            context: context
                        )
                        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        return (index, trimmed)
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
                            detail: "keyHash=\(hash)",
                            runId: capturedRun
                        ))
                        throw error
                    }
                }
            }
            var buffer = [String?](repeating: nil, count: total)
            for try await(index, text) in group {
                buffer[index] = text
            }
            return buffer.compactMap { $0 }.joined(separator: "\n")
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
            AIPromptBuilder.prompt(for: mode, customPrompt: settings.aiPrompt)
        }
        let chunks = AIChunker.chunk(text: rawText, size: size)
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

    func processedContent(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        rawText: String,
        runId: UUID? = nil
    ) async throws -> String {
        let run = runId ?? UUID()
        if mode == .none {
            return rawText
        }
        if let cached = try? cache.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode) {
            await logCache(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                event: "cache.hit",
                detail: "keyHash=\(keyHash(key(bookId: bookId, chapter: chapterNumber, mode: mode)))",
                runId: run
            )
            return cached.content
        }
        let cacheKey = key(bookId: bookId, chapter: chapterNumber, mode: mode)
        if let existing = inFlight[cacheKey] {
            await logCache(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                event: "dedup.shared",
                detail: "keyHash=\(keyHash(cacheKey))",
                runId: run
            )
            return try await existing.value
        }
        let task = Task<String, Error> {
            try await self.runPipeline(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                rawText: rawText,
                cacheKey: cacheKey,
                runId: run
            )
        }
        let token = UUID()
        inFlight[cacheKey] = task
        inFlightTokens[cacheKey] = token
        defer {
            if inFlightTokens[cacheKey] == token {
                inFlight[cacheKey] = nil
                inFlightTokens[cacheKey] = nil
            }
        }
        return try await task.value
    }

    func reprocess(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        rawText: String,
        runId: UUID? = nil
    ) async throws -> String {
        let run = runId ?? UUID()
        if mode == .none {
            return rawText
        }
        let cacheKey = key(bookId: bookId, chapter: chapterNumber, mode: mode)
        if let existing = inFlight[cacheKey] {
            // Cancel previous in-flight work before reprocessing
            existing.cancel()
            inFlight[cacheKey] = nil
            inFlightTokens[cacheKey] = nil
        }
        let token = UUID()
        let task = Task<String, Error> {
            try await self.runPipeline(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                rawText: rawText,
                cacheKey: cacheKey,
                runId: run
            )
        }
        inFlight[cacheKey] = task
        inFlightTokens[cacheKey] = token
        defer {
            if inFlightTokens[cacheKey] == token {
                inFlight[cacheKey] = nil
                inFlightTokens[cacheKey] = nil
            }
        }
        return try await task.value
    }
}
