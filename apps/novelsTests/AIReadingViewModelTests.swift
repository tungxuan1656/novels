@testable import novels
import XCTest

@MainActor
final class AIReadingViewModelTests: XCTestCase {
    var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        AIMockURLProtocol.handler = nil
    }

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        AIMockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeTempRepoWithBook(slug: String, chapters: [String]) throws -> FileBookRepository {
        let root = tempRoot!
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent(slug, isDirectory: true)
        try FileManager.default.createDirectory(
            at: bookDir.appendingPathComponent("chapters"),
            withIntermediateDirectories: true
        )
        let references = chapters.indices.map { "C\($0 + 1)" }
        let book = Book(id: slug, name: "Test \(slug)", author: "A", count: chapters.count, references: references)
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        for (idx, content) in chapters.enumerated() {
            let html = "<p>\(content)</p>"
            try html.write(
                to: bookDir.appendingPathComponent("chapters/chapter-\(idx + 1).html"),
                atomically: true,
                encoding: .utf8
            )
        }
        return FileBookRepository(root: root, fileManager: .default)
    }

    private func makeSettings() -> SettingsStore {
        let suite = UserDefaults(suiteName: "test.vm.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: suite)
        store.openaiAPIURL = "http://localhost:8317/v1/chat/completions"
        store.openaiModel = "gpt-4o"
        store.aiMinChunkSize = 1300
        store.save()
        return store
    }

    private func makeService(cache: SQLiteProcessedChapterCache, settings: SettingsStore) -> AIReadingService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = AIClient(settings: settings, session: session)
        return AIReadingService(cache: cache, client: client, settings: settings)
    }

    func testModeSwitchShowsCachedOrTriggersProcessing() async throws {
        let slug = "test-slug"
        let repo = try makeTempRepoWithBook(slug: slug, chapters: ["raw html content for chapter one"])
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = makeSettings()
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"DỊCH\"}}]}"
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }
        let service = makeService(cache: cache, settings: settings)
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: service
        )
        await vm.load()
        XCTAssertEqual(vm.aiMode, .none)
        XCTAssertNil(vm.processedContent)
        await vm.setAIMode(.rewrite)
        XCTAssertEqual(vm.processedContent, "DỊCH")
        XCTAssertEqual(try cache.get(bookId: slug, chapterNumber: 1, mode: .rewrite)?.content, "DỊCH")
        // Second switch should hit cache without network
        AIMockURLProtocol.handler = { _ in
            XCTFail("should not hit network on cache hit")
            throw URLError(.badServerResponse)
        }
        let vm2 = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: service
        )
        await vm2.load()
        await vm2.setAIMode(.rewrite)
        XCTAssertEqual(vm2.processedContent, "DỊCH")
    }

    func testReprocessOverwritesCache() async throws {
        let slug = "reprocess-slug"
        let repo = try makeTempRepoWithBook(slug: slug, chapters: ["raw for reprocess"])
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: slug,
            chapterNumber: 1,
            mode: .rewrite,
            content: "old",
            contentHash: SHA256.hex("old"),
            createdAt: now,
            updatedAt: now
        ))
        let settings = makeSettings()
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"new\"}}]}"
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }
        let service = makeService(cache: cache, settings: settings)
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: service
        )
        await vm.load()
        await vm.setAIMode(.rewrite)
        // Should have returned cached "old" initially
        XCTAssertEqual(vm.processedContent, "old")
        // Now reprocess should overwrite with "new"
        await vm.reprocess()
        XCTAssertEqual(vm.processedContent, "new")
        XCTAssertEqual(try cache.get(bookId: slug, chapterNumber: 1, mode: .rewrite)?.content, "new")
    }

    func testModeNoneNeverCached() async throws {
        let slug = "none-slug"
        let repo = try makeTempRepoWithBook(slug: slug, chapters: ["raw none content"])
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = makeSettings()
        // Ensure any network call fails if attempted
        AIMockURLProtocol.handler = { _ in
            XCTFail("mode none should not call network")
            throw URLError(.badServerResponse)
        }
        let service = makeService(cache: cache, settings: settings)
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: service
        )
        await vm.load()
        XCTAssertEqual(vm.aiMode, .none)
        await vm.setAIMode(.none)
        XCTAssertNil(vm.processedContent)
        XCTAssertEqual(try cache.countAll(), 0)
        // set to translate then back to none should not create none entry
        AIMockURLProtocol.handler = { request in
            let json = "{\"choices\":[{\"message\":{\"content\":\"cached-translate\"}}]}"
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }
        await vm.setAIMode(.rewrite)
        XCTAssertEqual(vm.processedContent, "cached-translate")
        XCTAssertEqual(try cache.countAll(), 1)
        await vm.setAIMode(.none)
        XCTAssertNil(vm.processedContent)
        // still only translate entry, none never written
        XCTAssertEqual(try cache.countAll(), 1)
        XCTAssertNil(try cache.get(bookId: slug, chapterNumber: 1, mode: .none))
    }

    func testFailClearsProcessingFlagWhilePrefetchRunning() async throws {
        let slug = "fail-flag-slug"
        let repo = try makeTempRepoWithBook(slug: slug, chapters: ["chapter one raw", "chapter two raw"])
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = makeSettings()
        AIMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"error\":\"server\"}".utf8))
        }
        let service = makeService(cache: cache, settings: settings)
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: service
        )
        await vm.load()
        await vm.setAIMode(.rewrite)
        // Single attempt fails fast: flag cleared, error surfaced, no stuck spinner.
        XCTAssertFalse(vm.isAIProcessing)
        XCTAssertNotNil(vm.aiError)
        // Prefetch runs independently with its own indicator (running or finished/cancelled),
        // but must not leave the chapter AI spinner stuck.
        XCTAssertFalse(vm.isAIProcessing)
        // onDisappear clears the flag synchronously even if a task was in flight.
        vm.onDisappear()
        XCTAssertFalse(vm.isAIProcessing)
    }

    func testGoNextAutoReloadsAIWhenModeNotNone() async throws {
        let slug = "nav-slug"
        let repo = try makeTempRepoWithBook(slug: slug, chapters: ["chapter one raw", "chapter two raw"])
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let settings = makeSettings()
        var callCount = 0
        AIMockURLProtocol.handler = { request in
            callCount += 1
            let content = callCount == 1 ? "DỊCH 1" : "DỊCH 2"
            let json = "{\"choices\":[{\"message\":{\"content\":\"\(content)\"}}]}"
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }
        let service = makeService(cache: cache, settings: settings)
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: service
        )
        await vm.load()
        await vm.setAIMode(.rewrite)
        XCTAssertEqual(vm.processedContent, "DỊCH 1")
        // goNext should auto trigger AI for chapter 2
        await vm.goNext()
        // wait for async aiTask to complete (load spawns Task)
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(vm.chapterNumber, 2)
        XCTAssertEqual(vm.processedContent, "DỊCH 2")
        XCTAssertEqual(callCount, 2)
    }
}
