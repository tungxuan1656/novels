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

    func processedContent(bookId: String, chapterNumber: Int, mode: AIMode, rawText: String) async throws -> String {
        if mode == .none {
            return rawText
        }
        if let cached = try? cache.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode) {
            return cached.content
        }
        let cacheKey = key(bookId: bookId, chapter: chapterNumber, mode: mode)
        if let existing = inFlight[cacheKey] {
            return try await existing.value
        }
        let task = Task<String, Error> {
            let chunkSize: Int = await MainActor.run { settings.aiMinChunkSize }
            let size = (500 ... 5000).contains(chunkSize) ? chunkSize : 1300
            let prompt: String = await MainActor.run {
                AIPromptBuilder.prompt(for: mode, actionsJSON: settings.aiProcessActionsJSON)
            }
            let chunks = AIChunker.chunk(text: rawText, size: size)
            if chunks.isEmpty {
                throw AIClientError.noResponse
            }
            var outputs: [String] = []
            for chunk in chunks {
                let out = try await client.complete(prompt: prompt, chunk: chunk)
                outputs.append(out.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let joined = outputs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
        let size = (500 ... 5000).contains(chunkSize) ? chunkSize : 1300
        let prompt: String = await MainActor.run {
            AIPromptBuilder.prompt(for: mode, actionsJSON: settings.aiProcessActionsJSON)
        }
        let chunks = AIChunker.chunk(text: rawText, size: size)
        if chunks.isEmpty {
            throw AIClientError.noResponse
        }
        var outputs: [String] = []
        for chunk in chunks {
            let out = try await client.complete(prompt: prompt, chunk: chunk)
            outputs.append(out.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let joined = outputs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
        return joined
    }
}
