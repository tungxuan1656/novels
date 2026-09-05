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
        // feat-024 Phase 2 (see docs/plans/feat-024.md): no debounce/poll —
        // trigger mirrors running synchronously, terminal arrives via the
        // one-shot returnFromLog resync (all-cached here, so no resume).
        XCTAssertTrue(vm.prefetchStatus.isRunning, "sync trigger must mirror running")
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(client.calls.contains(2) || client.calls.contains(3), "calls \(client.calls)")
        await vm.load(source: .returnFromLog)
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
        // feat-024 Phase 2 (see docs/plans/feat-024.md): no poll, so settle
        // the VM mirror with an explicit resync before capturing the baseline
        // (all-cached here, so this resync itself resumes nothing).
        await vm.load(source: .returnFromLog)
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
        // feat-024 Phase 2 (see docs/plans/feat-024.md): no poll, so the VM
        // mirror holds the sync-trigger running state; completion/errors live
        // in the manager. Assert via quiescence + cache, not the VM mirror.
        XCTAssertTrue(vm.prefetchStatus.isRunning, "sync trigger mirrors running; terminal via resync")
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

    /// Disappear cancels and nothing resurrects: with no debounce there is no
    /// delayed trigger to wake, so after onDisappear calls freeze and the
    /// terminal holds. (feat-024 Phase 2, see docs/plans/feat-024.md: queue
    /// absorbs churn, cancel only on book/mode change/.none/disappear.)
    func testStaleNavTriggerDoesNotResurrectAfterDisappear() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 3, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 200_000_000
        await vm.load()
        await vm.setAIMode(.rewrite)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        // Sync trigger: navigate keeps the queue (no cancel, no debounce)…
        await vm.goToChapter(8)
        XCTAssertTrue(vm.prefetchStatus.isRunning, "navigate keeps queue running")
        // …then disappear cancels once; no delayed trigger can resurrect.
        // (No returnFromLog here: it would legitimately resume on misses.
        // Sleep lets the ordered disappear-cancel land before sampling.)
        vm.onDisappear()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        let frozen = client.calls.count
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(client.calls.count, frozen, "no resurrect batch fetched, got \(client.calls)")
    }

    /// Mode trigger is synchronous: setAIMode starts the batch immediately,
    /// disappear cancels it, and calls freeze with the terminal held.
    /// (feat-024 Phase 2, see docs/plans/feat-024.md: no debounce/epoch.)
    func testStaleModeTriggerDoesNotResurrectAfterDisappear() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 30)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 200_000_000
        await vm.load()
        await vm.goToChapter(5)
        await vm.setAIMode(.rewrite)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        // (No returnFromLog: it would resume on misses. Sleep lets the
        // ordered disappear-cancel land before sampling the freeze.)
        vm.onDisappear()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        let frozen = client.calls.count
        XCTAssertTrue(client.calls.contains(5), "ch5 AI must have run, got \(client.calls)")
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(client.calls.count, frozen, "no resurrect after disappear, got \(client.calls)")
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
        // feat-024 Phase 2 (see docs/plans/feat-024.md): one-shot resync, no
        // poll task — running shows synchronously, terminal via a second
        // resync once the window is all-cached (resume then finds no misses).
        await vm.load(source: .returnFromLog)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        XCTAssertTrue(vm.prefetchStatus.isRunning, "resumed batch should publish running")
        await waitForPrefetch(!client.calls.isEmpty)
        XCTAssertFalse(client.calls.contains(1), "current chapter must stay zero-API, got \(client.calls)")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await vm.load(source: .returnFromLog)
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
        // feat-024 Phase 2 (see docs/plans/feat-024.md): no epoch/poll — a
        // resume firing would start a batch (running + calls); a clean
        // no-resume return stays idle with zero calls.
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        client.calls.removeAll()
        await vm.load(source: .returnFromLog)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(client.calls.isEmpty, "query failure must not resume, got \(client.calls)")
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    // MARK: - feat-024 Phase 2: sync trigger + one-shot resync (no debounce/poll/epoch)

    /// Queue absorbs churn: the trigger issues start synchronously with no
    /// 200ms debounce — batchCheck is logged and running mirrors by the time
    /// load returns, well within 100ms of idle overhead.
    /// (feat-024 Phase 2, see docs/plans/feat-024.md.)
    func testTriggerHasNoDebounceDelay() async throws {
        let (vm, _, _, _, tmp) = try makeVM(prefetchCount: 2, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await DiagnosticsLog.shared.clear()
        await vm.load()
        await vm.setAIMode(.rewrite)
        // setAIMode awaits the current-chapter AI then triggers synchronously:
        // running must already mirror with no extra settle sleep.
        XCTAssertTrue(vm.prefetchStatus.isRunning, "trigger must be synchronous, no 200ms debounce")
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertTrue(
            entries.contains { $0.event == "prefetch.batchCheck" },
            "batchCheck must be logged synchronously, got \(entries.map { ($0.event, $0.detail) })"
        )
        await DiagnosticsLog.shared.clear()
    }

    /// returnFromLog resyncs once with no poll task: a settled all-cached
    /// return shows idle immediately and stays stable with zero API calls.
    /// (feat-024 Phase 2, see docs/plans/feat-024.md.)
    func testReturnFromLogResyncsWithoutPoll() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 2, total: 5)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await vm.load()
        await vm.setAIMode(.rewrite)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        await vm.load(source: .returnFromLog)
        XCTAssertFalse(vm.prefetchStatus.isRunning, "settled resync must show idle")
        let message = vm.prefetchStatus.message
        client.calls.removeAll()
        // Second return: single resync, no poll-driven churn, zero API.
        await vm.load(source: .returnFromLog)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        XCTAssertEqual(vm.prefetchStatus.message, message)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(client.calls.isEmpty, "no poll/resume calls, got \(client.calls)")
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    /// Real VM flow keeps the running task across same-book navigate:
    /// steady goNext appends only the new tail with no cancel event.
    /// (feat-024 Phase 1 keep branch via Phase 2 reader path, see
    /// docs/plans/feat-024.md; mirrors PrefetchFifoQueueTests keep test.)
    func testNavigateViaViewModelKeepsRunningTask() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 3, total: 30)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 200_000_000
        await DiagnosticsLog.shared.clear()
        await vm.load()
        await vm.setAIMode(.rewrite)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        await vm.goToChapter(5)
        XCTAssertTrue(vm.prefetchStatus.isRunning, "same-book navigate must keep the queue")
        await vm.goNext()
        XCTAssertTrue(vm.prefetchStatus.isRunning, "steady next must keep the queue")
        XCTAssertEqual(vm.chapterNumber, 6)
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertFalse(
            entries.contains { $0.event == "prefetch.cancel" && ($0.detail ?? "").contains("reason=chapterChange") },
            "steady reading must not cancel, got \(entries.map { ($0.event, $0.detail) })"
        )
        // New tail appended through the real VM flow (6+3 window reaches 9).
        XCTAssertTrue(client.calls.contains(9), "navigate must append only the new tail, got \(client.calls)")
    }
}
