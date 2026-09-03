import CryptoKit
import Foundation

actor AIReadingService {
    private let cache: ProcessedChapterCaching
    private let client: AIClient
    private let settings: SettingsStore
    private var inFlight: [String: Task<String, Error>] = [:]

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
        errorCode: Int? = nil
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
            detail: detail
        ))
    }

    private func logCache(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        event: String,
        detail: String
    ) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: UUID(),
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode.rawValue,
            event: event,
            detail: detail
        ))
    }

    // Sequential per-chunk loop with chunk.start/success/fail events.
    // Called outside `client.complete` so retry attempts (up to 3x) are not triple-counted.
    // swiftlint:disable:next function_parameter_count function_body_length
    private func processChunks(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        prompt: String,
        chunks: [String],
        cacheKey: String
    ) async throws -> String {
        let total = chunks.count
        let hash = keyHash(cacheKey)
        var outputs: [String] = []
        outputs.reserveCapacity(total)
        for (index, chunk) in chunks.enumerated() {
            let requestId = UUID()
            let chunkStart = Date()
            await logChunk(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                chunkIndex: index,
                chunkTotal: total,
                requestId: requestId,
                event: "chunk.start",
                detail: "chunkCount=\(total) keyHash=\(hash)",
                bodyLen: chunk.utf8.count,
                bodyHashPrefix: DiagnosticsRedactor.hashPrefix(chunk)
            )
            do {
                let context = AIDiagnosticsContext(
                    bookId: bookId,
                    chapterNumber: chapterNumber,
                    mode: mode.rawValue,
                    chunkIndex: index,
                    chunkTotal: total,
                    requestId: requestId
                )
                let out = try await client.complete(prompt: prompt, chunk: chunk, context: context)
                let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
                let latencyMs = Int(Date().timeIntervalSince(chunkStart) * 1000)
                await logChunk(
                    bookId: bookId,
                    chapterNumber: chapterNumber,
                    mode: mode,
                    chunkIndex: index,
                    chunkTotal: total,
                    requestId: requestId,
                    event: "chunk.success",
                    detail: "keyHash=\(hash)",
                    latencyMs: latencyMs,
                    responseLen: trimmed.utf8.count,
                    responseHashPrefix: DiagnosticsRedactor.hashPrefix(trimmed)
                )
                outputs.append(trimmed)
            } catch {
                let latencyMs = Int(Date().timeIntervalSince(chunkStart) * 1000)
                let nsError = error as NSError
                await logChunk(
                    bookId: bookId,
                    chapterNumber: chapterNumber,
                    mode: mode,
                    chunkIndex: index,
                    chunkTotal: total,
                    requestId: requestId,
                    event: "chunk.fail",
                    detail: "keyHash=\(hash)",
                    latencyMs: latencyMs,
                    errorDomain: nsError.domain,
                    errorCode: nsError.code
                )
                throw error
            }
        }
        return outputs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // swiftlint:disable:next function_body_length
    func processedContent(bookId: String, chapterNumber: Int, mode: AIMode, rawText: String) async throws -> String {
        if mode == .none {
            return rawText
        }
        if let cached = try? cache.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode) {
            await logCache(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                event: "cache.hit",
                detail: "keyHash=\(keyHash(key(bookId: bookId, chapter: chapterNumber, mode: mode)))"
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
                detail: "keyHash=\(keyHash(cacheKey))"
            )
            return try await existing.value
        }
        let task = Task<String, Error> {
            let chunkSize: Int = await MainActor.run { settings.aiMinChunkSize }
            let size = (500 ... 10000).contains(chunkSize) ? chunkSize : 1300
            let prompt: String = await MainActor.run {
                AIPromptBuilder.prompt(for: mode, customPrompt: settings.aiPrompt)
            }
            let chunks = AIChunker.chunk(text: rawText, size: size)
            if chunks.isEmpty {
                throw AIClientError.noResponse
            }
            await self.logCache(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                event: "cache.miss",
                detail: "chunkCount=\(chunks.count) keyHash=\(self.keyHash(cacheKey))"
            )
            let joined = try await self.processChunks(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                prompt: prompt,
                chunks: chunks,
                cacheKey: cacheKey
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
            await self.logCache(
                bookId: bookId,
                chapterNumber: chapterNumber,
                mode: mode,
                event: "cache.save",
                detail: "chunkCount=\(chunks.count) outputHash=\(String(hash.prefix(8))) keyHash=\(self.keyHash(cacheKey))"
            )
            return joined
        }
        inFlight[cacheKey] = task
        defer { inFlight[cacheKey] = nil }
        return try await task.value
    }

    func reprocess(bookId: String, chapterNumber: Int, mode: AIMode, rawText: String) async throws -> String {
        if mode == .none {
            return rawText
        }
        let cacheKey = key(bookId: bookId, chapter: chapterNumber, mode: mode)
        if let existing = inFlight[cacheKey] {
            // Cancel previous in-flight work before reprocessing
            existing.cancel()
            inFlight[cacheKey] = nil
        }
        let chunkSize: Int = await MainActor.run { settings.aiMinChunkSize }
        let size = (500 ... 10000).contains(chunkSize) ? chunkSize : 1300
        let prompt: String = await MainActor.run {
            AIPromptBuilder.prompt(for: mode, customPrompt: settings.aiPrompt)
        }
        let chunks = AIChunker.chunk(text: rawText, size: size)
        if chunks.isEmpty {
            throw AIClientError.noResponse
        }
        let joined = try await processChunks(
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode,
            prompt: prompt,
            chunks: chunks,
            cacheKey: cacheKey
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
            detail: "chunkCount=\(chunks.count) outputHash=\(String(hash.prefix(8))) keyHash=\(keyHash(cacheKey))"
        )
        return joined
    }
}
