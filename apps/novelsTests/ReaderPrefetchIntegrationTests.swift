// swiftlint:disable:next blanket_disable_command
// swiftlint:disable all
// swiftformat:disable all
@testable import novels
import XCTest

@MainActor
final class ReaderPrefetchIntegrationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    func makeVM(
        prefetchCount: Int = 3,
        mode: AIMode = .rewrite,
        total: Int = 10,
        cache: ProcessedChapterCaching? = nil
    ) throws -> (ReaderViewModel, ProcessedChapterCaching, SettingsStore, TrackingAIClient, URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let slug = "test-slug"
        let bookDir = tmp.appendingPathComponent(slug)
        let chaptersDir = bookDir.appendingPathComponent("chapters")
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        let book = Book(id: slug, name: "Test", author: "A", count: total, references: (1 ... total).map { "C\($0)" })
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        for i in 1 ... total {
            let html = "<p>Content \(i) raw text for prefetch testing extra filler to reach chunk size handling</p>"
            try html.write(
                to: chaptersDir.appendingPathComponent("chapter-\(i).html"),
                atomically: true,
                encoding: .utf8
            )
        }
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let resolvedCache: ProcessedChapterCaching
        if let cache {
            resolvedCache = cache
        } else {
            resolvedCache = try SQLiteProcessedChapterCache.inMemory()
        }
        let suite = UserDefaults(suiteName: "intg.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.prefetchCount = prefetchCount
        settings.save()
        let client = TrackingAIClient()
        // Need handler configured via service creation
        let svc = client.service(cache: resolvedCache, settings: settings)
        let mgr = PrefetchManager()
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: resolvedCache,
            aiService: svc,
            prefetchManager: mgr
        )
        return (vm, resolvedCache, settings, client, tmp)
    }

    /// Cache stub whose batchStatus always throws (I1: a query failure must
    /// never read as miss-all). Every other call delegates to a real
    /// in-memory cache so setup batches and chapter AI work normally.
    final class ThrowingBatchStatusCache: ProcessedChapterCaching {
        private let backing: SQLiteProcessedChapterCache
        init() throws {
            backing = try SQLiteProcessedChapterCache.inMemory()
        }

        func get(bookId: String, chapterNumber: Int, mode: AIMode) throws -> ProcessedChapter? {
            try backing.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode)
        }

        func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) throws -> Set<Int> {
            throw SQLiteError.open(message: "test query failure")
        }

        func upsert(_ pc: ProcessedChapter) throws {
            try backing.upsert(pc)
        }

        func clearAll() throws {
            try backing.clearAll()
        }

        func clear(bookId: String) throws {
            try backing.clear(bookId: bookId)
        }

        func countAll() throws -> Int {
            try backing.countAll()
        }

        func count(bookId: String) throws -> Int {
            try backing.count(bookId: bookId)
        }

        func allBookIds() throws -> [String] {
            try backing.allBookIds()
        }
    }

    func testPrefetchTriggeredAfterLoadWhenEligible() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 5)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await vm.setAIMode(.rewrite)
        await vm.load()
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(client.calls.contains(2) || client.calls.contains(3), "calls \(client.calls)")
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    func testModeChangeCancelsPreviousPrefetch() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 5, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 300_000_000
        await vm.setAIMode(.rewrite)
        await vm.load()
        try await Task.sleep(nanoseconds: 200_000_000)
        await vm.setAIMode(.none)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(client.calls.count < 10, "should have cancelled, got \(client.calls.count)")
    }

    func testInvalidPrefetchCountCoercedInVM() async throws {
        let (vm, _, settings, client, tmp) = try makeVM(prefetchCount: 1001, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await MainActor.run { settings.prefetchCount = 1001; settings.save() }
        await vm.setAIMode(.rewrite)
        await vm.load()
        try await Task.sleep(nanoseconds: 800_000_000)
        // vm.load triggers AI for current chapter (1) plus prefetch 2,3,4 when coerced to 3
        let prefetchCalls = client.calls.filter { $0 != 1 }
        XCTAssertEqual(prefetchCalls.count, 3, "coerced to 3, got \(client.calls)")
        XCTAssertEqual(Set(prefetchCalls), Set([2, 3, 4]), "expected 2,3,4 got \(client.calls)")
    }

    func testPrefetchStatusRuntimeOnlyNotPersisted() async throws {
        let (vm, _, _, _, tmp) = try makeVM()
        defer { try? FileManager.default.removeItem(at: tmp) }
        await vm.setAIMode(.rewrite)
        await vm.load()
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(UserDefaults.standard.object(forKey: "PrefetchStatus"))
        XCTAssertNotNil(vm.prefetchStatus)
    }

    func testReturnFromLogMakesZeroAPICalls() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 5)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await vm.load()
        await vm.setAIMode(.rewrite)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        client.calls.removeAll()
        let runningBefore = vm.prefetchStatus.isRunning
        let messageBefore = vm.prefetchStatus.message
        let errorsBefore = vm.prefetchStatus.errors
        let processedBefore = vm.prefetchStatus.processedChapters
        await vm.load(source: .returnFromLog)
        // Give any stray aiTask/prefetch trigger time to fire if the gate regresses.
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(client.calls.isEmpty, "return-from-Log must make zero API calls, got \(client.calls)")
        XCTAssertEqual(vm.prefetchStatus.isRunning, runningBefore)
        XCTAssertEqual(vm.prefetchStatus.message, messageBefore)
        XCTAssertEqual(vm.prefetchStatus.errors, errorsBefore)
        XCTAssertEqual(vm.prefetchStatus.processedChapters, processedBefore)
    }

    func testChapterChangeProcessesMissesSequentiallyAndContinuesOnError() async throws {
        let (vm, cache, _, client, tmp) = try makeVM(prefetchCount: 3, total: 6)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "test-slug",
            chapterNumber: 3,
            mode: .rewrite,
            content: "cached3",
            contentHash: "h3",
            createdAt: now,
            updatedAt: now
        ))
        client.shouldFail = [2: NSError(
            domain: "ai",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "fail 2"]
        )]
        // Mode switch is a chapterChange-class trigger: current-chapter AI + sequential prefetch.
        // NOTE: load() first so vm.book is set (prefetch needs the chapter count).
        await vm.load()
        await vm.setAIMode(.rewrite)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertEqual(vm.chapterNumber, 1)
        XCTAssertTrue(client.calls.first == 1, "current chapter AI first, got \(client.calls)")
        XCTAssertFalse(client.calls.contains(3), "cached chapter must be skipped, got \(client.calls)")
        // feat-024 Phase 1 (Lane P, see docs/plans/feat-024.md): the queue
        // requeues a failed chapter at the tail at most once, so a persistent
        // failure costs 2 manager issues x 2 AIClient per-chunk transport
        // attempts = 4 transport calls. Spec amendment in Lane S (Phase 4).
        XCTAssertEqual(client.calls.filter { $0 == 2 }.count, 4, "failed chapter requeued once at manager level, got \(client.calls)")
        XCTAssertEqual(client.calls.filter { $0 == 4 }.count, 1, "got \(client.calls)")
        // Error recorded and continued: ch4 cached despite ch2 failing.
        XCTAssertNotNil(try cache.get(bookId: "test-slug", chapterNumber: 4, mode: .rewrite))
        XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 2, mode: .rewrite))
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        XCTAssertEqual(vm.prefetchStatus.errors.count, 1, "errors \(vm.prefetchStatus.errors)")
    }

    // MARK: - feat-023 Phase 2 Step 2: epoch-guarded poll + log-return resync

    private func waitForPrefetch(
        timeoutSeconds: Double = 10,
        _ condition: @autoclosure () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition() {
            if Date() > deadline {
                XCTFail("waitForPrefetch timed out", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// Stale nav trigger must not resurrect a batch after cancel/disappear:
    /// goToChapter's trigger captures its epoch, onDisappear supersedes it
    /// mid-debounce, and the woken trigger must bow out (epoch guard).
    /// Chapters 9-10 are virgin witnesses: no legitimate path touches them
    /// (setup window is 2-4, chapter AI logs 1 and 8).
    func testStaleNavTriggerDoesNotResurrectAfterDisappear() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 3, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 200_000_000
        await vm.load()
        await vm.setAIMode(.rewrite)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        let epochBeforeNav = vm.prefetchEpoch
        // goToChapter's trigger debounces while we disappear mid-debounce…
        let navTask = Task { await vm.goToChapter(8) }
        await waitForPrefetch(vm.prefetchEpoch >= epochBeforeNav + 2)
        vm.onDisappear()
        await navTask.value
        // …so the woken trigger must bow out: no resurrect batch, chapters
        // 9+ stay virgin, terminal holds across trailing poll windows.
        // (Settle sizing: 100ms poll + 200ms debounce + 200ms/call; ordering
        // is gate-enforced, this window only lets a bug manifest.)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        XCTAssertFalse(client.calls.contains(where: { $0 >= 9 }), "resurrected batch fetched, got \(client.calls)")
    }

    /// Stale setAIMode trigger must not resurrect after disappear: the mode
    /// trigger captures its epoch, onDisappear supersedes it mid-debounce.
    /// Setup runs no batch, so calls stay exactly [5] (ch5 AI) unless a
    /// resurrected batch fetches 6-7.
    func testStaleModeTriggerDoesNotResurrectAfterDisappear() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 30)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 200_000_000
        await vm.load()
        await vm.goToChapter(5)
        let epochBeforeMode = vm.prefetchEpoch
        // setAIMode's trigger debounces while we disappear mid-debounce…
        let modeTask = Task { await vm.setAIMode(.rewrite) }
        await waitForPrefetch(vm.prefetchEpoch >= epochBeforeMode + 2)
        vm.onDisappear()
        await modeTask.value
        // …so the woken trigger must bow out: calls frozen at [5], idle holds.
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(client.calls, [5])
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    /// Mid-batch Log peek and return to the same chapter+mode: status resyncs
    /// from the manager and background prefetch resumes on remaining misses.
    /// Scope: "zero API" here means the current (cached) chapter only —
    /// background window chapters DO fetch on resume. The settled/all-cached
    /// scope (zero calls overall, no resume) is pinned by
    /// testReturnFromLogMakesZeroAPICalls.
    func testReturnFromLogResyncsAndResumesMidBatch() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 5)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 400_000_000
        await vm.load()
        await vm.setAIMode(.rewrite)
        // Batch mid-flight: peek Log (disappear cancels everything).
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        vm.onDisappear()
        client.calls.removeAll()
        // Back to the same chapter+mode: resync + resume, no current-chapter API.
        await vm.load(source: .returnFromLog)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        XCTAssertTrue(vm.prefetchStatus.isRunning, "resumed batch should publish running")
        await waitForPrefetch(!client.calls.isEmpty)
        XCTAssertFalse(client.calls.contains(1), "current chapter must stay zero-API, got \(client.calls)")
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    /// Resume miss-check query failure must not read as miss-all: no resume
    /// trigger (exactly one resync bump), prior resynced state kept, zero
    /// background calls. Chapter AI + manager error paths still work through
    /// the delegating stub (only batchStatus throws).
    func testResumeQueryFailureKeepsPriorState() async throws {
        let throwing = try ThrowingBatchStatusCache()
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 5, cache: throwing)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await vm.load()
        await vm.setAIMode(.rewrite)
        // ch1 AI completes via working get/upsert; trigger→start hits the
        // throwing batchStatus → manager error-continues with zero calls.
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        let epochBeforeReturn = vm.prefetchEpoch
        client.calls.removeAll()
        await vm.load(source: .returnFromLog)
        // Resync bump only — a trigger bump here would mean resume fired.
        XCTAssertEqual(vm.prefetchEpoch, epochBeforeReturn + 1)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(client.calls.isEmpty, "query failure must not resume, got \(client.calls)")
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }
}
