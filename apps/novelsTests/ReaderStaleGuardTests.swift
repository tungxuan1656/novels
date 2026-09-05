@testable import novels
import XCTest

/// feat-023 Phase 1: generation-guard for the single-slot AI state.
///
/// Timing control: cache-hit chapters resolve ~instantly (0ms, no network),
/// network chapters sleep inside the mock URL protocol (fresh-chapter delay).
/// Every test asserts the view-model identity gate
/// (`isProcessedContentCurrent()`) alongside the content itself.
@MainActor
final class ReaderStaleGuardTests: XCTestCase {
    private var tempRoot: URL!
    private var store: SettingsStore!
    private var repo: FileBookRepository!
    private var cache: SQLiteProcessedChapterCache!

    private let slug = "stale-guard"

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let bookDir = tempRoot.appendingPathComponent(slug)
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("chapters"),
                withIntermediateDirectories: true
            )
            let book = Book(
                id: slug,
                name: "Stale",
                author: "A",
                count: 3,
                references: ["C1", "C2", "C3"]
            )
            try JSONEncoder().encode(book).write(to: bookDir.appendingPathComponent("book.json"))
            try "<p>CHAPTER-ONE raw text alpha</p>".write(
                to: bookDir.appendingPathComponent("chapters/chapter-1.html"),
                atomically: true,
                encoding: .utf8
            )
            try "<p>CHAPTER-TWO raw text beta</p>".write(
                to: bookDir.appendingPathComponent("chapters/chapter-2.html"),
                atomically: true,
                encoding: .utf8
            )
            try "<p>CHAPTER-THREE raw text gamma</p>".write(
                to: bookDir.appendingPathComponent("chapters/chapter-3.html"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            XCTFail("Setup failed: \(error)")
        }
        store = SettingsStore(userDefaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.aiMode = .rewrite
        store.prefetchCount = 0
        store.openaiAPIURL = "http://localhost:8317/v1/chat/completions"
        store.openaiModel = "gpt-4o"
        store.aiMinChunkSize = 1300
        store.save()
        repo = FileBookRepository(root: tempRoot, fileManager: .default)
        do {
            cache = try SQLiteProcessedChapterCache.inMemory()
        } catch {
            XCTFail("Cache setup failed: \(error)")
        }
        AIMockURLProtocol.handler = nil
    }

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        AIMockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private static func jsonResponse(request: URLRequest, content: String) throws -> (HTTPURLResponse, Data) {
        let json = "{\"choices\":[{\"message\":{\"content\":\"\(content)\"}}]}"
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, json.data(using: .utf8)!)
    }

    private func makeService() -> AIReadingService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = AIClient(settings: store, session: session)
        return AIReadingService(cache: cache, client: client, settings: store)
    }

    private func makeViewModel() -> ReaderViewModel {
        ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: store,
            cache: cache,
            aiService: makeService()
        )
    }

    private func seedCache(chapter: Int, content: String) throws {
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: slug,
            chapterNumber: chapter,
            mode: .rewrite,
            content: content,
            contentHash: SHA256.hex(content),
            createdAt: now,
            updatedAt: now
        ))
    }

    private func waitFor(timeoutSeconds: Double = 5, _ condition: @autoclosure () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition() {
            if Date() > deadline {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // MARK: - Phase 1 race tests

    /// Stale chapter-2 network task resolves AFTER we are back on chapter 1
    /// (cache-hit, 0ms). It must not overwrite chapter-1 content.
    func testStaleCacheHitDoesNotOverwriteNewChapter() async throws {
        try seedCache(chapter: 1, content: "CACHED-ONE")
        AIMockURLProtocol.handler = { request in
            let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if body.contains("CHAPTER-TWO") {
                Thread.sleep(forTimeInterval: 0.3)
                return try Self.jsonResponse(request: request, content: "FRESH-TWO")
            }
            return try Self.jsonResponse(request: request, content: "FRESH-UNEXPECTED")
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        await waitFor(viewModel.processedContent == "CACHED-ONE")
        XCTAssertEqual(viewModel.processedContent, "CACHED-ONE")

        // Chapter 2 starts a slow network fetch; return before it completes.
        await viewModel.goToChapter(2)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await viewModel.goToChapter(1)
        await waitFor(viewModel.chapterNumber == 1 && viewModel.processedContent == "CACHED-ONE")
        // Let the stale chapter-2 task resolve last.
        try? await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertEqual(viewModel.processedContent, "CACHED-ONE")
        XCTAssertTrue(viewModel.isProcessedContentCurrent())
    }

    /// Three rapid hops 1 -> 2 -> 1 with no settling: only the last
    /// generation may publish, even when the middle hop is the slowest.
    func testRapidABA450_451_450KeepsLastWriter() async throws {
        try seedCache(chapter: 1, content: "CACHED-ONE")
        AIMockURLProtocol.handler = { request in
            let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if body.contains("CHAPTER-TWO") {
                Thread.sleep(forTimeInterval: 0.3)
                return try Self.jsonResponse(request: request, content: "FRESH-TWO")
            }
            return try Self.jsonResponse(request: request, content: "FRESH-UNEXPECTED")
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        await waitFor(viewModel.processedContent == "CACHED-ONE")

        await viewModel.goToChapter(2)
        await viewModel.goToChapter(1)
        await waitFor(viewModel.chapterNumber == 1 && viewModel.processedContent == "CACHED-ONE")
        // Let every stale in-flight task finish; none may overwrite.
        try? await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertEqual(viewModel.processedContent, "CACHED-ONE")
        XCTAssertTrue(viewModel.isProcessedContentCurrent())
    }

    /// Switching AI mode to none mid-flight must cancel/invalidate the
    /// in-flight rewrite: the stale result must never appear.
    func testSetAIModeCancelsInFlightTask() async {
        AIMockURLProtocol.handler = { request in
            Thread.sleep(forTimeInterval: 0.3)
            return try Self.jsonResponse(request: request, content: "STALE-REWRITE")
        }
        let viewModel = makeViewModel()
        let rewriteTask = Task { await viewModel.setAIMode(.rewrite) }
        await waitFor(viewModel.isAIProcessing)
        XCTAssertTrue(viewModel.isAIProcessing)

        await viewModel.setAIMode(.none)
        XCTAssertNil(viewModel.processedContent)
        await rewriteTask.value
        // Let any late stale write land.
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(viewModel.aiMode, .none)
        XCTAssertNil(viewModel.processedContent)
        XCTAssertFalse(viewModel.isProcessedContentCurrent())
    }

    /// Two consecutive reprocesses: the second result stands, even when the
    /// first pipeline was slower.
    func testReprocessLastWriterWins() async {
        var callCount = 0
        AIMockURLProtocol.handler = { request in
            callCount += 1
            if callCount == 1 {
                return try Self.jsonResponse(request: request, content: "INITIAL")
            } else if callCount == 2 {
                Thread.sleep(forTimeInterval: 0.3)
                return try Self.jsonResponse(request: request, content: "REPROCESS-FIRST")
            } else {
                return try Self.jsonResponse(request: request, content: "REPROCESS-SECOND")
            }
        }
        let viewModel = makeViewModel()
        await viewModel.load()
        await waitFor(viewModel.processedContent == "INITIAL")
        XCTAssertEqual(viewModel.processedContent, "INITIAL")

        async let first: () = viewModel.reprocess()
        // Yield so the first reprocess is in flight before the second starts.
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let second: () = viewModel.reprocess()
        await first
        await second
        await waitFor(viewModel.processedContent == "REPROCESS-SECOND")
        // Let the slower first pipeline finish; it must not overwrite.
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(viewModel.processedContent, "REPROCESS-SECOND")
        XCTAssertTrue(viewModel.isProcessedContentCurrent())
    }
}
