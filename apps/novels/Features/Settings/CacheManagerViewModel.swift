import Foundation
import Observation

@MainActor
@Observable
final class CacheManagerViewModel {
    nonisolated struct BookCacheRow: Identifiable, Equatable, Sendable {
        let slug: String
        let title: String
        let versionCount: Int

        var id: String {
            slug
        }
    }

    private(set) var totalVersions = 0
    private(set) var distinctChapters = 0
    private(set) var books: [BookCacheRow] = []
    private(set) var bookMetadata: [String: [ProcessedChapterMetadata]] = [:]
    private(set) var metadataErrors: [String: String] = [:]
    private(set) var metadataRevision = 0
    private(set) var isLoading = true
    private(set) var isClearing = false
    private(set) var errorMessage: String?
    private var generation = 0
    private var cache: ProcessedChapterCaching?
    private let repository: BookRepository

    var isUnavailable: Bool {
        !isLoading && cache == nil
    }

    init(cache: ProcessedChapterCaching? = nil, bookRepository: BookRepository? = nil) {
        self.cache = cache
        repository = bookRepository ?? FileBookRepository(root: AppPaths.booksRoot())
    }

    func load() async {
        guard !isClearing else { return }
        generation += 1
        let request = generation
        isLoading = true
        defer {
            if request == generation {
                isLoading = false
            }
        }
        do {
            let inventory = try await Self.readInventory(cache: cache, repository: repository)
            guard !Task.isCancelled, request == generation else { return }
            cache = inventory.cache
            books = inventory.books
            totalVersions = inventory.summaries.reduce(0) { $0 + $1.versionCount }
            distinctChapters = inventory.summaries.reduce(0) { $0 + $1.chapterCount }
            bookMetadata.removeAll()
            metadataErrors.removeAll()
            metadataRevision += 1
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, request == generation else { return }
            errorMessage = "Không thể tải bộ nhớ đệm: \(error.localizedDescription)"
            books = []
            totalVersions = 0
            distinctChapters = 0
        }
    }

    func loadMetadata(slug: String) async {
        guard !isLoading, !isClearing, let cache, bookMetadata[slug] == nil else { return }
        let request = generation
        do {
            let items = try await Self.readMetadata(cache: cache, slug: slug)
            guard !Task.isCancelled, request == generation else { return }
            bookMetadata[slug] = items
            metadataErrors.removeValue(forKey: slug)
        } catch {
            guard !Task.isCancelled, request == generation else { return }
            metadataErrors[slug] = "Không thể tải chi tiết: \(error.localizedDescription)"
        }
    }

    func clear(bookId: String? = nil) async -> Bool {
        guard !isLoading, !isClearing, let cache else { return false }
        isClearing = true
        generation += 1
        do {
            try await Self.delete(cache: cache, bookId: bookId)
            isClearing = false
            await load()
            return true
        } catch {
            isClearing = false
            isLoading = false
            errorMessage = "Xóa bộ nhớ đệm thất bại: \(error.localizedDescription)"
            return false
        }
    }

    private nonisolated struct Inventory: Sendable {
        let cache: ProcessedChapterCaching
        let summaries: [ProcessedBookSummary]
        let books: [BookCacheRow]
    }

    @concurrent
    private static func readInventory(
        cache: ProcessedChapterCaching?, repository: BookRepository
    ) async throws -> Inventory {
        try Task.checkCancellation()
        let opened = try cache ?? SQLiteProcessedChapterCache()
        let summaries = try opened.inventory()
        var rows: [BookCacheRow] = []
        for summary in summaries {
            try Task.checkCancellation()
            let title = (try? repository.book(slug: summary.bookId))?.name ?? summary.bookId
            rows.append(BookCacheRow(slug: summary.bookId, title: title, versionCount: summary.versionCount))
        }
        rows.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return Inventory(cache: opened, summaries: summaries, books: rows)
    }

    @concurrent
    private static func readMetadata(
        cache: ProcessedChapterCaching, slug: String
    ) async throws -> [ProcessedChapterMetadata] {
        try Task.checkCancellation()
        return try cache.metadata(bookId: slug)
    }

    @concurrent
    private static func delete(cache: ProcessedChapterCaching, bookId: String?) async throws {
        if let bookId {
            try cache.clear(bookId: bookId)
        } else {
            try cache.clearAll()
        }
    }
}
