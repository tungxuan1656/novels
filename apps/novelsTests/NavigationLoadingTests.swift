import Foundation
@testable import novels
import Observation
import XCTest

@MainActor
final class NavigationLoadingTests: XCTestCase {
    func testLibraryReusesLoadedBooksAndRefreshesAfterInvalidation() async {
        let reads = NavigationReadProbe()
        let repository = NavigationRepository(onList: {
            XCTAssertFalse(Thread.isMainThread)
            let number = reads.increment()
            return [Book(id: "book-\(number)", name: "Book", author: nil, count: 0, references: [])]
        })
        let model = library(repository: repository)
        await model.load()
        await model.load()
        XCTAssertEqual(reads.count, 1)
        XCTAssertEqual(model.books.first?.id, "book-1")
        await model.load(force: true)
        XCTAssertEqual(reads.count, 2)
        model.invalidate()
        await model.load()
        XCTAssertEqual(reads.count, 3)
        XCTAssertEqual(model.books.first?.id, "book-3")
        XCTAssertFalse(model.isLoading)
    }

    func testOldLibraryReadCannotReplaceNewRefresh() async {
        let started = expectation(description: "First scan started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let reads = NavigationReadProbe()
        let repository = NavigationRepository(onList: {
            let number = reads.increment()
            if number == 1 {
                started.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            }
            return [Book(id: "book-\(number)", name: "Book", author: nil, count: 0, references: [])]
        })
        let model = library(repository: repository)
        let first = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        await model.load(force: true)
        release.signal()
        await first.value
        XCTAssertEqual(model.books.first?.id, "book-2")
        XCTAssertFalse(model.isLoading)
    }

    func testCancelledLibraryReadIsNotPublishedAndCanRetry() async {
        let started = expectation(description: "Scan started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let reads = NavigationReadProbe()
        let repository = NavigationRepository(onList: {
            if reads.increment() == 1 {
                started.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            }
            return [Book(id: "sample", name: "Book", author: nil, count: 0, references: [])]
        })
        let model = library(repository: repository)
        let pending = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        pending.cancel()
        release.signal()
        await pending.value
        XCTAssertTrue(model.books.isEmpty)
        XCTAssertFalse(model.isLoading)
        await model.load()
        XCTAssertEqual(model.books.first?.id, "sample")
    }

    func testLibraryReadFailureRemainsRetryable() async {
        let reads = NavigationReadProbe()
        let model = library(repository: NavigationRepository(onList: {
            if reads.increment() == 1 {
                throw CocoaError(.fileReadNoPermission)
            }
            return []
        }))
        await model.load()
        XCTAssertFalse(model.isLoading)
        await model.load()
        XCTAssertEqual(reads.count, 2)
    }

    func testCacheInventoryIsBackgroundAndDetailsAreLazyAndRefreshable() async throws {
        let cache = try NavigationCache()
        try cache.upsert(chapter(book: "first", number: 1))
        try cache.upsert(chapter(book: "first", number: 1, mode: .bilingual))
        try cache.upsert(chapter(book: "second", number: 1))
        let repository = NavigationRepository(onBook: { slug in
            XCTAssertFalse(Thread.isMainThread)
            return Book(id: slug, name: "Title \(slug)", author: nil, count: 0, references: [])
        })
        let model = CacheManagerViewModel(cache: cache, bookRepository: repository)
        XCTAssertEqual(cache.inventoryReads.count, 0)
        await model.load()
        XCTAssertEqual(model.totalVersions, 3)
        XCTAssertEqual(model.distinctChapters, 2)
        XCTAssertEqual(model.books.map(\.title), ["Title first", "Title second"])
        XCTAssertEqual(cache.metadataReads.count, 0)
        await model.loadMetadata(slug: "first")
        await model.loadMetadata(slug: "first")
        XCTAssertEqual(cache.metadataReads.count, 1)
        XCTAssertEqual(model.bookMetadata["first"]?.count, 2)
        let revision = model.metadataRevision
        await model.load()
        XCTAssertTrue(model.bookMetadata.isEmpty)
        XCTAssertGreaterThan(model.metadataRevision, revision)
        await model.loadMetadata(slug: "first")
        XCTAssertEqual(cache.metadataReads.count, 2)
    }

    func testOldCacheInventoryCannotReplaceNewRefresh() async throws {
        let started = expectation(description: "First inventory started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let reads = NavigationReadProbe()
        let cache = try NavigationCache(onInventory: {
            if reads.increment() == 1 {
                started.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            }
        })
        try cache.upsert(chapter(book: "first", number: 1))
        let model = CacheManagerViewModel(cache: cache, bookRepository: NavigationRepository())
        let first = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        try cache.upsert(chapter(book: "second", number: 1))
        await model.load()
        release.signal()
        await first.value
        XCTAssertEqual(model.totalVersions, 2)
        XCTAssertEqual(model.books.count, 2)
        XCTAssertFalse(model.isLoading)
    }

    func testCancelledCacheInventoryIsNotPublishedAndCanRetry() async throws {
        let started = expectation(description: "Inventory started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let reads = NavigationReadProbe()
        let cache = try NavigationCache(onInventory: {
            if reads.increment() == 1 {
                started.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            }
        })
        try cache.upsert(chapter(book: "first", number: 1))
        let model = CacheManagerViewModel(cache: cache, bookRepository: NavigationRepository())
        let pending = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        pending.cancel()
        release.signal()
        await pending.value
        XCTAssertTrue(model.books.isEmpty)
        XCTAssertFalse(model.isLoading)
        await model.load()
        XCTAssertEqual(model.totalVersions, 1)
    }

    func testCacheInventoryFailureRemainsVisibleAndRetryable() async throws {
        let reads = NavigationReadProbe()
        let cache = try NavigationCache(onInventory: {
            if reads.increment() == 1 {
                throw CocoaError(.fileReadNoPermission)
            }
        })
        let model = CacheManagerViewModel(cache: cache, bookRepository: NavigationRepository())
        await model.load()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        await model.load()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(reads.count, 2)
    }

    func testCacheDeletionIsBackgroundAndBookScoped() async throws {
        let cache = try NavigationCache()
        try cache.upsert(chapter(book: "first", number: 1))
        try cache.upsert(chapter(book: "second", number: 1))
        let model = CacheManagerViewModel(cache: cache, bookRepository: NavigationRepository())
        await model.load()
        await model.loadMetadata(slug: "first")
        let clearedBook = await model.clear(bookId: "first")
        XCTAssertTrue(clearedBook)
        XCTAssertEqual(model.totalVersions, 1)
        XCTAssertEqual(model.books.map(\.slug), ["second"])
        XCTAssertTrue(model.bookMetadata.isEmpty)
        XCTAssertNotNil(try cache.get(bookId: "second", chapterNumber: 1, mode: .rewrite))
        let clearedAll = await model.clear()
        XCTAssertTrue(clearedAll)
        XCTAssertEqual(model.totalVersions, 0)
        XCTAssertTrue(model.books.isEmpty)
    }

    func testMetadataStartedBeforeClearCannotRepublishDeletedDetails() async throws {
        let started = expectation(description: "Metadata read started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let cache = try NavigationCache(onMetadata: {
            started.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
        })
        try cache.upsert(chapter(book: "first", number: 1))
        let model = CacheManagerViewModel(cache: cache, bookRepository: NavigationRepository())
        await model.load()
        let details = Task { await model.loadMetadata(slug: "first") }
        await fulfillment(of: [started], timeout: 2)
        let cleared = await model.clear(bookId: "first")
        XCTAssertTrue(cleared)
        release.signal()
        await details.value
        XCTAssertNil(model.bookMetadata["first"])
        XCTAssertTrue(model.books.isEmpty)
    }

    func testCacheReadAndDeleteFailuresRemainVisible() async throws {
        let cache = try NavigationCache(
            onMetadata: { throw CocoaError(.fileReadNoPermission) },
            onClear: { throw CocoaError(.fileWriteNoPermission) }
        )
        try cache.upsert(chapter(book: "first", number: 1))
        let model = CacheManagerViewModel(cache: cache, bookRepository: NavigationRepository())
        await model.load()
        await model.loadMetadata(slug: "first")
        XCTAssertNotNil(model.metadataErrors["first"])
        let cleared = await model.clear()
        XCTAssertFalse(cleared)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isClearing)
        XCTAssertEqual(try cache.countAll(), 1)
    }

    func testLogEntryUsesRecoveryThatArrivesDuringBackgroundTitleRead() async {
        let bookId = UUID().uuidString
        let runId = UUID()
        let entry: (String) -> LogEntry = { event in
            LogEntry(
                sessionId: DiagnosticsLog.sessionId, bookId: bookId,
                chapterNumber: 1, mode: "rewrite", event: event, runId: runId
            )
        }
        await DiagnosticsLog.shared.append(entry("run.start"))
        await DiagnosticsLog.shared.append(entry("run.fail"))
        let started = expectation(description: "Title read started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let repository = NavigationRepository(onList: {
            XCTAssertFalse(Thread.isMainThread)
            started.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            return [Book(id: bookId, name: "Title", author: nil, count: 0, references: [])]
        })
        let store = DiagnosticsStore()
        let pending = Task { await store.prepareForDisplay(repository: repository) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(store.failedRunCount(bookId: bookId), 1)
        await DiagnosticsLog.shared.append(entry("run.success"))
        release.signal()
        let titles = await pending.value
        XCTAssertEqual(titles[bookId], "Title")
        XCTAssertEqual(store.failedRunCount(bookId: bookId), 0)
        XCTAssertEqual(store.runGroups(bookId: bookId, bookTitles: titles).first?.status, .success)
    }

    func testLogOpenedEmptyResolvesTitleForLaterRun() async {
        await assertLiveLogTitle(includeExistingRun: false)
    }

    func testLogResolvesTitleForAnotherBooksLaterRun() async {
        await assertLiveLogTitle(includeExistingRun: true)
    }
}

private extension NavigationLoadingTests {
    func assertLiveLogTitle(includeExistingRun: Bool) async {
        await DiagnosticsLog.shared.clear()
        let books = ["First title", "Later title"].map { title in
            Book(id: UUID().uuidString, name: title, author: nil, count: 0, references: [])
        }
        let entry: (String) -> LogEntry = { bookId in
            LogEntry(
                sessionId: DiagnosticsLog.sessionId, bookId: bookId,
                chapterNumber: 1, mode: "rewrite", event: "run.start", runId: UUID()
            )
        }
        if includeExistingRun {
            await DiagnosticsLog.shared.append(entry(books[0].id))
        }
        let scans = NavigationReadProbe()
        let lookups = NavigationReadProbe()
        let repository = NavigationRepository(onList: {
            XCTAssertFalse(Thread.isMainThread)
            _ = scans.increment()
            return books
        }, onBook: { slug in
            _ = lookups.increment()
            return books.first { $0.id == slug }
        })
        let store = DiagnosticsStore()
        let titles = await store.prepareForDisplay(repository: repository)
        XCTAssertEqual(store.entries.count, includeExistingRun ? 1 : 0)
        // A non-run marker makes observer readiness visible without seeding another AI run.
        await DiagnosticsLog.shared.append(LogEntry(sessionId: DiagnosticsLog.sessionId, event: "prefetch.check"))
        let ready = expectation(description: "Observer completed its initial refresh")
        withObservationTracking {
            _ = store.entries
        } onChange: {
            ready.fulfill()
        }
        let observer = Task { await store.observe() }
        await fulfillment(of: [ready], timeout: 2)
        let later = entry(books[1].id)
        await DiagnosticsLog.shared.append(later)
        let deadline = Date().addingTimeInterval(2)
        while !store.entries.contains(where: { $0.id == later.id }), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        observer.cancel()
        await observer.value
        XCTAssertTrue(store.entries.contains { $0.id == later.id })
        let group = store.runGroups(bookId: books[1].id, bookTitles: titles).first
        XCTAssertTrue(group?.title.hasPrefix("Later title") == true)
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(lookups.count, 0)
        await DiagnosticsLog.shared.clear()
    }

    func library(repository: BookRepository) -> LibraryViewModel {
        let suite = "NavigationLoadingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return LibraryViewModel(repository: repository, settingsStore: SettingsStore(userDefaults: defaults))
    }

    func chapter(book: String, number: Int, mode: AIMode = .rewrite) -> ProcessedChapter {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return ProcessedChapter(
            bookId: book, chapterNumber: number, mode: mode, content: "content",
            contentHash: "hash", createdAt: date, updatedAt: date
        )
    }
}

private struct NavigationRepository: BookRepository {
    var onList: @Sendable () throws -> [Book] = { [] }
    var onBook: @Sendable (String) throws -> Book? = { _ in nil }

    func listBooks() throws -> [Book] {
        try onList()
    }

    func book(slug: String) throws -> Book? {
        try onBook(slug)
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        ""
    }

    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}

/// The synchronous test gates block only background reads, never the main actor.
private final class NavigationReadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int {
        lock.withLock { value }
    }

    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}

private final class NavigationCache: ProcessedChapterCaching, @unchecked Sendable {
    private let storage: SQLiteProcessedChapterCache
    private let onInventory: @Sendable () throws -> Void
    private let onMetadata: @Sendable () throws -> Void
    private let onClear: @Sendable () throws -> Void
    let inventoryReads = NavigationReadProbe()
    let metadataReads = NavigationReadProbe()

    init(
        onInventory: @escaping @Sendable () throws -> Void = {},
        onMetadata: @escaping @Sendable () throws -> Void = {},
        onClear: @escaping @Sendable () throws -> Void = {}
    ) throws {
        storage = try SQLiteProcessedChapterCache.inMemory()
        self.onInventory = onInventory
        self.onMetadata = onMetadata
        self.onClear = onClear
    }

    func inventory() throws -> [ProcessedBookSummary] {
        XCTAssertFalse(Thread.isMainThread)
        _ = inventoryReads.increment()
        let result = try storage.inventory()
        try onInventory()
        return result
    }

    func metadata(bookId: String) throws -> [ProcessedChapterMetadata] {
        XCTAssertFalse(Thread.isMainThread)
        _ = metadataReads.increment()
        let result = try storage.metadata(bookId: bookId)
        try onMetadata()
        return result
    }

    func clearAll() throws {
        XCTAssertFalse(Thread.isMainThread)
        try onClear()
        try storage.clearAll()
    }

    func clear(bookId: String) throws {
        XCTAssertFalse(Thread.isMainThread)
        try onClear()
        try storage.clear(bookId: bookId)
    }

    func get(bookId: String, chapterNumber: Int, mode: AIMode) throws -> ProcessedChapter? {
        try storage.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode)
    }

    func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) throws -> Set<Int> {
        try storage.batchStatus(bookId: bookId, mode: mode, numbers: numbers)
    }

    func upsert(_ pc: ProcessedChapter) throws {
        try storage.upsert(pc)
    }

    func countAll() throws -> Int {
        try storage.countAll()
    }

    func count(bookId: String) throws -> Int {
        try storage.count(bookId: bookId)
    }

    func allBookIds() throws -> [String] {
        try storage.allBookIds()
    }
}
