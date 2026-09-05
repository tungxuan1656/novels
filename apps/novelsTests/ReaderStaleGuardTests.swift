@testable import novels
import XCTest

/// Manually-fulfilled mock URL protocol for the Phase 1 stale-guard tests.
///
/// Requests park until the test releases them, so "stale resolves last" is
/// enforced by release ORDER — never by sleep durations. Cancellation is
/// cooperative: `stopLoading` unparks with `URLError(.cancelled)`, which lets
/// a test prove the pipeline really cancels instead of hanging or
/// delivering late. All shared state is guarded by `condition`.
final class GatedAIURLProtocol: URLProtocol {
    enum Outcome: Equatable {
        case delivered(String)
        case cancelled
    }

    private final class Gate {
        var released = false
        var cancelled = false
        var content = ""
    }

    private struct Parked {
        let id: Int
        let epoch: Int
        let gate: Gate
    }

    private struct StampedOutcome {
        let epoch: Int
        let outcome: Outcome
    }

    private static let condition = NSCondition()
    private static var epoch = 0
    private static var nextID = 0
    private static var parked: [Parked] = []
    private static var outcomes: [Int: StampedOutcome] = [:]
    private static var events: [String] = []

    private var gate: Gate?
    private var requestID: Int = -1

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let gate = Gate()
        self.gate = gate
        let id: Int
        Self.condition.lock()
        id = Self.nextID
        Self.nextID += 1
        Self.parked.append(Parked(id: id, epoch: Self.epoch, gate: gate))
        Self.events.append("start:\(id)")
        Self.condition.unlock()
        requestID = id
        // Park OFF the URLSession thread: startLoading must return immediately
        // so no URLSession-internal lock is held while gated. A parked
        // startLoading would otherwise deadlock sibling dispatches on the same
        // machinery: stopLoading for a cancelled sibling and startLoading for
        // the next request would queue behind the park forever. Delivery (or
        // cancellation) is reported asynchronously, which URLProtocol allows.
        let client = self.client
        let requestURL = request.url
        DispatchQueue.global(qos: .default).async {
            Self.condition.lock()
            while !gate.released, !gate.cancelled {
                Self.condition.wait(until: Date().addingTimeInterval(0.05))
            }
            let content = gate.content
            let cancelled = gate.cancelled
            Self.condition.unlock()
            if cancelled {
                client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
                self.recordOutcome(id: id, outcome: .cancelled)
                return
            }
            let json = "{\"choices\":[{\"message\":{\"content\":\"\(content)\"}}]}"
            let response = HTTPURLResponse(
                url: requestURL!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: json.data(using: .utf8)!)
            client?.urlProtocolDidFinishLoading(self)
            self.recordOutcome(id: id, outcome: .delivered(content))
        }
    }

    override func stopLoading() {
        Self.condition.lock()
        gate?.cancelled = true
        Self.events.append("stop:\(requestID)")
        Self.condition.broadcast()
        Self.condition.unlock()
    }

    private func recordOutcome(id: Int, outcome: Outcome) {
        Self.condition.lock()
        Self.outcomes[id] = StampedOutcome(epoch: Self.epoch, outcome: outcome)
        Self.condition.unlock()
    }

    static func parkedIDs() -> [Int] {
        condition.lock()
        defer { condition.unlock() }
        return parked.filter { $0.epoch == epoch }.map { $0.id }
    }

    static func release(id: Int, content: String) {
        condition.lock()
        if let entry = parked.first(where: { $0.id == id && $0.epoch == epoch }) {
            entry.gate.content = content
            entry.gate.released = true
        }
        condition.broadcast()
        condition.unlock()
    }

    static func outcome(id: Int) -> Outcome? {
        condition.lock()
        defer { condition.unlock() }
        guard let stamped = outcomes[id], stamped.epoch == epoch else { return nil }
        return stamped.outcome
    }

    /// Session-level timeline for failure diagnostics (start/stop per id).
    static func eventLog() -> [String] {
        condition.lock()
        defer { condition.unlock() }
        return events
    }

    /// Unblock every parked request as cancelled (tearDown safety net).
    static func failAllParked() {
        condition.lock()
        for entry in parked {
            entry.gate.cancelled = true
        }
        condition.broadcast()
        condition.unlock()
    }

    static func reset() {
        condition.lock()
        epoch += 1
        parked.removeAll()
        outcomes.removeAll()
        events.removeAll()
        nextID = 0
        condition.unlock()
    }
}

/// feat-023 Phase 1: generation-guard for the single-slot AI state.
///
/// Ordering is enforced by manual gate release, not by sleeps: a test parks
/// the stale request, advances the VM, then releases the stale request last.
/// Fixed sleeps appear only as bounded "bug-manifest" windows after a
/// deterministic release — they cannot change the outcome order.
/// Every test asserts the view-model identity gate
/// (`isProcessedContentCurrent()`) alongside the content itself.
@MainActor
final class ReaderStaleGuardTests: XCTestCase {
    private var tempRoot: URL!
    private var store: SettingsStore!
    private var repo: FileBookRepository!
    private var cache: SQLiteProcessedChapterCache!
    private var sessions: [URLSession] = []

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
        GatedAIURLProtocol.reset()
    }

    override func tearDown() {
        GatedAIURLProtocol.failAllParked()
        GatedAIURLProtocol.reset()
        for session in sessions {
            session.finishTasksAndInvalidate()
        }
        sessions.removeAll()
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeService() -> AIReadingService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GatedAIURLProtocol.self]
        // Concurrent delegate queue: parked protocol waits must never occupy
        // URLSession's default serial queue and deadlock sibling dispatches
        // (stopLoading for a cancelled sibling, startLoading for the next
        // request). Each service gets its own session; sessions are
        // invalidated in tearDown so no task outlives its test.
        let queue = OperationQueue()
        queue.name = "test-gated-urlprotocol"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: queue)
        sessions.append(session)
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

    /// Parked request id at arrival `index`, waited with a wide timeout.
    /// Identification is arrival-order-based: each AI pipeline sends exactly
    /// one request (single short chunk, no prefetch, parked requests never
    /// fail so the client never retries). Nil means nothing arrived.
    private func waitForParkedID(at index: Int, timeoutSeconds: Double = 5) async -> Int? {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let ids = GatedAIURLProtocol.parkedIDs()
            if ids.count > index {
                return ids[index]
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return nil
    }

    private func waitForOutcome(id: Int, timeoutSeconds: Double = 5) async {
        await waitFor(timeoutSeconds: timeoutSeconds, GatedAIURLProtocol.outcome(id: id) != nil)
    }

    // MARK: - Phase 1 race tests

    /// Stale chapter-2 network task resolves AFTER we are back on chapter 1
    /// (cache-hit, 0ms). Release order — not sleeps — makes it resolve last;
    /// it must not overwrite chapter-1 content.
    func testStaleCacheHitDoesNotOverwriteNewChapter() async throws {
        try seedCache(chapter: 1, content: "CACHED-ONE")
        let viewModel = makeViewModel()
        await viewModel.load()
        await waitFor(viewModel.processedContent == "CACHED-ONE")
        XCTAssertEqual(viewModel.processedContent, "CACHED-ONE")

        // Chapter 2 parks a network fetch; return before it completes.
        // The initial load was a cache hit, so the first parked request is it.
        await viewModel.goToChapter(2)
        guard let staleID = await waitForParkedID(at: 0) else {
            XCTFail("chapter-2 request never reached the network parked=\(GatedAIURLProtocol.parkedIDs())")
            return
        }
        await viewModel.goToChapter(1)
        await waitFor(viewModel.chapterNumber == 1 && viewModel.processedContent == "CACHED-ONE")
        // Stale chapter-2 resolves last — deterministically, by manual release.
        GatedAIURLProtocol.release(id: staleID, content: "FRESH-TWO")
        await waitForOutcome(id: staleID)
        // The stale write really landed here (delivered, not silently dropped)…
        XCTAssertEqual(GatedAIURLProtocol.outcome(id: staleID), .delivered("FRESH-TWO"))
        // …give it a chance to (incorrectly) publish, then assert it did not.
        // Ordering is gate-enforced; this window only lets a bug manifest.
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertEqual(viewModel.processedContent, "CACHED-ONE")
        XCTAssertTrue(viewModel.isProcessedContentCurrent())
    }

    /// Rapid hops 1 -> 2 -> 1 with no settling: only the last generation may
    /// publish. If the middle hop reached the network, it resolves last by
    /// manual release.
    func testRapidABA121KeepsLastWriter() async throws {
        try seedCache(chapter: 1, content: "CACHED-ONE")
        let viewModel = makeViewModel()
        await viewModel.load()
        await waitFor(viewModel.processedContent == "CACHED-ONE")

        await viewModel.goToChapter(2)
        await viewModel.goToChapter(1)
        await waitFor(viewModel.chapterNumber == 1 && viewModel.processedContent == "CACHED-ONE")
        if let staleID = await waitForParkedID(at: 0, timeoutSeconds: 2) {
            GatedAIURLProtocol.release(id: staleID, content: "FRESH-TWO")
            await waitForOutcome(id: staleID)
            XCTAssertEqual(GatedAIURLProtocol.outcome(id: staleID), .delivered("FRESH-TWO"))
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertEqual(viewModel.processedContent, "CACHED-ONE")
        XCTAssertTrue(viewModel.isProcessedContentCurrent())
    }

    /// Switching AI mode to none mid-flight invalidates the in-flight
    /// rewrite: the stale result resolves after the switch yet must never
    /// appear.
    func testSetAIModeCancelsInFlightTask() async {
        let viewModel = makeViewModel()
        let rewriteTask = Task { await viewModel.setAIMode(.rewrite) }
        guard let staleID = await waitForParkedID(at: 0) else {
            XCTFail("rewrite request never reached the network")
            return
        }
        XCTAssertTrue(viewModel.isAIProcessing)

        await viewModel.setAIMode(.none)
        XCTAssertNil(viewModel.processedContent)
        // Stale resolves after the switch — deterministically released.
        GatedAIURLProtocol.release(id: staleID, content: "STALE-REWRITE")
        await rewriteTask.value
        await waitForOutcome(id: staleID)
        XCTAssertEqual(GatedAIURLProtocol.outcome(id: staleID), .delivered("STALE-REWRITE"))
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(viewModel.aiMode, .none)
        XCTAssertNil(viewModel.processedContent)
        XCTAssertFalse(viewModel.isProcessedContentCurrent())
    }

    /// Two consecutive reprocesses: the second result stands. The service
    /// cancels the first pipeline, which the mock observes as stopLoading —
    /// proof the cancel is cooperative (no hang, no late delivery).
    func testReprocessLastWriterWins() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        guard let loadID = await waitForParkedID(at: 0) else {
            XCTFail("initial request never reached the network")
            return
        }
        GatedAIURLProtocol.release(id: loadID, content: "INITIAL")
        await waitFor(viewModel.processedContent == "INITIAL")
        XCTAssertEqual(viewModel.processedContent, "INITIAL")

        let firstTask = Task { await viewModel.reprocess() }
        guard let firstID = await waitForParkedID(at: 1) else {
            XCTFail("first reprocess never reached the network")
            return
        }
        let secondTask = Task { await viewModel.reprocess() }
        // The second reprocess must reach the service and cancel the first
        // pipeline before its own request can park. Assert the cancel first
        // to localize any stall (VM-side vs downstream).
        await waitForOutcome(id: firstID)
        XCTAssertEqual(GatedAIURLProtocol.outcome(id: firstID), .cancelled)
        guard let secondID = await waitForParkedID(at: 2) else {
            XCTFail("second reprocess never reached the network events=\(GatedAIURLProtocol.eventLog())")
            return
        }
        // The second reprocess cancels the first pipeline: the mock must
        // observe the cancellation instead of hanging or delivering late.
        GatedAIURLProtocol.release(id: secondID, content: "REPROCESS-SECOND")
        await firstTask.value
        await secondTask.value
        await waitFor(viewModel.processedContent == "REPROCESS-SECOND")
        XCTAssertEqual(viewModel.processedContent, "REPROCESS-SECOND")
        XCTAssertTrue(viewModel.isProcessedContentCurrent())
    }
}
