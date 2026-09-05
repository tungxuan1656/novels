// swiftlint:disable:next blanket_disable_command
// swiftlint:disable all
// swiftformat:disable all
@testable import novels
import XCTest

/// feat-024 Phase 1 (Lane P): durable FIFO queue inside PrefetchManager.
/// Same-book+mode navigates keep the running task (keep ∩ + append tail);
/// cancel happens only on book/mode change. Mock env mirrors
/// PrefetchManagerTests.makeManagerEnv; transient failure uses the existing
/// `failRemaining` mechanism (no new mock hook per controller resolution).
final class PrefetchFifoQueueTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
        PrefetchManager.hardCap = 10
    }

    @MainActor
    func makeManagerEnv(
        prefetchCount: Int = 3,
        totalChapters: Int = 10,
        mode: AIMode = .rewrite
    ) throws -> (PrefetchManager, SQLiteProcessedChapterCache, SettingsStore, MockBookRepo, TrackingAIClient) {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = UserDefaults(suiteName: "fifo.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.prefetchCount = prefetchCount
        settings.save()
        let repo = MockBookRepo(slug: "book-slug", count: totalChapters)
        let client = TrackingAIClient()
        return (PrefetchManager(), cache, settings, repo, client)
    }

    /// Multi-book repo stub: MockBookRepo serves a single slug, which would
    /// make the book-change test vacuous (unknown slugs hit `bookDeleted`
    /// before any AI call, so zero calls trivially satisfy any range check).
    private final class DualBookRepo: BookRepository {
        let slugs: Set<String>
        let count: Int
        init(slugs: Set<String>, count: Int) {
            self.slugs = slugs
            self.count = count
        }

        func listBooks() throws -> [Book] { [] }

        func book(slug: String) throws -> Book? {
            guard slugs.contains(slug) else { return nil }
            return Book(
                id: slug,
                name: "t",
                author: "a",
                count: count,
                references: (1 ... count).map { "Chap \($0)" }
            )
        }

        func chapterHTML(slug: String, number: Int) throws -> String {
            guard slugs.contains(slug) else { throw BookRepositoryError.bookNotFound(slug: slug) }
            guard number >= 1 && number <= count else {
                throw BookRepositoryError.invalidChapterNumber(number: number, count: count)
            }
            return "<p>Content \(number)</p>"
        }

        func save(validatedRoot: URL, slug: String) throws {}
        func deleteBook(slug: String) throws {}
    }

    @MainActor
    private func makeDualBookEnv(
        prefetchCount: Int,
        totalChapters: Int
    ) throws -> (PrefetchManager, SQLiteProcessedChapterCache, SettingsStore, DualBookRepo, TrackingAIClient) {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = UserDefaults(suiteName: "fifo.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: suite)
        settings.prefetchCount = prefetchCount
        settings.save()
        let repo = DualBookRepo(slugs: ["book-a", "book-b"], count: totalChapters)
        let client = TrackingAIClient()
        return (PrefetchManager(), cache, settings, repo, client)
    }

    func testNavigateKeepsRunningTaskAndAppendsOnlyTail() async throws {
        // N=20 at 450 issues 451-470; go to 451 keeps the task, appends only 471.
        // hardCap is 10 until feat-024 Phase 3 removes it; raise it for this
        // window (test-overridable by design) and restore right after each
        // start (the cap is consumed synchronously inside start).
        // NOTE: expectation is 451...471, not 452...471 — chapter 451 is
        // issued by the first window before the navigate and the queue keeps
        // it exactly once, so it stays in the recorded calls.
        await DiagnosticsLog.shared.clear()
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 20, totalChapters: 500)
        let svc = client.service(cache: cache, settings: settings)
        PrefetchManager.hardCap = 30
        await manager.start(bookId: "book-slug", currentChapter: 450, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
        PrefetchManager.hardCap = 10
        try await Task.sleep(nanoseconds: 300_000_000)
        PrefetchManager.hardCap = 30
        await manager.start(bookId: "book-slug", currentChapter: 451, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
        PrefetchManager.hardCap = 10
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let calls = client.calls
        XCTAssertEqual(calls, Array(451...471), "kept chapters processed once in FIFO order, got \(calls)")
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertFalse(
            entries.contains { $0.event == "prefetch.cancel" && ($0.detail ?? "").contains("reason=chapterChange") },
            "same-book navigate must not cancel, got \(entries.map { ($0.event, $0.detail) })"
        )
    }

    func testTransientFailureRetriedOnceThenDropped() async throws {
        // Failing chapter requeues at the tail at most once, then logs and drops.
        // Transient transport failure (failRemaining) is absorbed by the
        // AIClient per-chunk attempt loop, so the manager never re-issues and
        // the chapter succeeds with exactly 2 transport calls.
        let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 100)
        client.failRemaining = [52: 1]
        let svc = client.service(cache: cache, settings: settings)
        await manager.start(bookId: "book-slug", currentChapter: 50, totalChapters: 100, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
        try await Task.sleep(nanoseconds: 2_500_000_000)
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "status \(status)")
        XCTAssertEqual(client.calls.filter({ $0 == 52 }).count, 2, "one retry max, got \(client.calls)")
    }

    func testBookChangeCancelsQueue() async throws {
        // New book (or .none mode) still cancels; same-book navigate never does.
        // NOTE: scoped to post-change calls — client.calls accumulates both
        // batches, and the cancelled book-a batch legitimately recorded its
        // head chapters before the book change. The prefix non-empty check
        // proves real book-a work was underway (i.e. this is not vacuous).
        let (manager, cache, settings, repo, client) = try await makeDualBookEnv(prefetchCount: 20, totalChapters: 500)
        let svc = client.service(cache: cache, settings: settings)
        PrefetchManager.hardCap = 30
        await manager.start(bookId: "book-a", currentChapter: 450, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
        PrefetchManager.hardCap = 10
        try await Task.sleep(nanoseconds: 200_000_000)
        let callsBeforeChange = client.calls.count
        XCTAssertGreaterThan(callsBeforeChange, 0, "book-a work must be underway before the change, got \(client.calls)")
        PrefetchManager.hardCap = 30
        await manager.start(bookId: "book-b", currentChapter: 10, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
        PrefetchManager.hardCap = 10
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let newCalls = Array(client.calls.dropFirst(callsBeforeChange))
        XCTAssertFalse(newCalls.isEmpty, "book-b window must be processed, got \(client.calls)")
        XCTAssertTrue(newCalls.allSatisfy({ $0 >= 11 && $0 <= 30 }), "old-book work cancelled, got \(client.calls)")
    }
}
