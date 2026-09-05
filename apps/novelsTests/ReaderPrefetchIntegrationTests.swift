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
        total: Int = 10
    ) throws -> (ReaderViewModel, SQLiteProcessedChapterCache, SettingsStore, TrackingAIClient, URL) {
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
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = UserDefaults(suiteName: "intg.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.prefetchCount = prefetchCount
        settings.save()
        let client = TrackingAIClient()
        // Need handler configured via service creation
        let svc = client.service(cache: cache, settings: settings)
        let mgr = PrefetchManager()
        let vm = ReaderViewModel(
            bookId: slug,
            repository: repo,
            settingsStore: settings,
            cache: cache,
            aiService: svc,
            prefetchManager: mgr
        )
        return (vm, cache, settings, client, tmp)
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
        XCTAssertEqual(client.calls.filter { $0 == 2 }.count, 2, "failed chunk retried once, got \(client.calls)")
        XCTAssertEqual(client.calls.filter { $0 == 4 }.count, 1, "got \(client.calls)")
        // Error recorded and continued: ch4 cached despite ch2 failing.
        XCTAssertNotNil(try cache.get(bookId: "test-slug", chapterNumber: 4, mode: .rewrite))
        XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 2, mode: .rewrite))
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        XCTAssertEqual(vm.prefetchStatus.errors.count, 1, "errors \(vm.prefetchStatus.errors)")
    }

    // MARK: - feat-023 Phase 2 Step 2: epoch-guarded poll + log-return resync

    private func waitForPrefetch(timeoutSeconds: Double = 10, _ condition: @autoclosure () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition() {
            if Date() > deadline {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// Cancel prefetch, then let trailing reads run: the stale isRunning=true
    /// must never overwrite the terminal state. The epoch seam pins the
    /// generation discipline (fails to compile before the fix).
    func testCancelTrailingReadKeepsTerminalState() async throws {
        let (vm, _, _, client, tmp) = try makeVM(prefetchCount: 3, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        client.delayPerCall = 200_000_000
        await vm.load()
        await vm.setAIMode(.rewrite)
        await waitForPrefetch(vm.prefetchStatus.isRunning)
        XCTAssertTrue(vm.prefetchStatus.isRunning, "poll should track the running batch")
        let epochBeforeCancel = vm.prefetchEpoch
        await vm.setAIMode(.none)
        // Single terminal write (cancel runs before the mode assignment, so
        // the terminal is not-running/"Đã hủy" rather than .idle)…
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        XCTAssertGreaterThan(vm.prefetchEpoch, epochBeforeCancel)
        // …then silence across several poll windows and trailing reads.
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    /// Rapid goNext -> goPrev -> goNext: every navigation advances the poll
    /// epoch and the status converges on the latest batch (old polls never
    /// overwrite the new one). Epoch assertions fail to compile pre-fix.
    func testRapidNavPollEpochAdvancesAndConverges() async throws {
        let (vm, _, _, _, tmp) = try makeVM(prefetchCount: 2, total: 10)
        defer { try? FileManager.default.removeItem(at: tmp) }
        await vm.load()
        await vm.setAIMode(.rewrite)
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        let base = vm.prefetchEpoch
        await vm.goNext()
        XCTAssertGreaterThan(vm.prefetchEpoch, base)
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        let afterNext = vm.prefetchEpoch
        await vm.goPrev()
        XCTAssertGreaterThan(vm.prefetchEpoch, afterNext)
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        let afterPrev = vm.prefetchEpoch
        await vm.goNext()
        XCTAssertGreaterThan(vm.prefetchEpoch, afterPrev)
        await waitForPrefetch(!vm.prefetchStatus.isRunning)
        XCTAssertFalse(vm.prefetchStatus.isRunning)
        XCTAssertEqual(vm.chapterNumber, 2)
    }

    /// Mid-batch Log peek and return to the same chapter+mode: status resyncs
    /// from the manager and background prefetch resumes on remaining misses —
    /// with zero API calls for the current (cached) chapter.
    func testReturnFromLogResyncsAndResumesRunningBatch() async throws {
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
}
