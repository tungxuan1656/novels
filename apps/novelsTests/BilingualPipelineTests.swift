import Foundation
@testable import novels
import XCTest

@MainActor
final class BilingualPipelineTests: XCTestCase {
    func testOrderedAssemblyCacheFirstAndIndependentModes() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        BilingualURLProtocol.configure(invalid: false)
        let source = ["first", "second", "third"].map { String(repeating: $0 + " ", count: 50) }
            .joined(separator: "\n\n")
        let content = try await fixture.service.processedContent(
            bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: source
        )
        let chapter = try BilingualChapter.decode(content)
        XCTAssertEqual(chapter.paragraphs.map(\.id), ["p001", "p002", "p003"])
        XCTAssertEqual(BilingualURLProtocol.completedIDs().last, "p001")
        XCTAssertEqual(BilingualURLProtocol.requests().count, 3)
        for request in BilingualURLProtocol.requests() {
            XCTAssertNotNil(try body(request)["response_format"])
        }
        let cached = try await fixture.service.processedContent(
            bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "unused"
        )
        XCTAssertEqual(cached, content)
        let raw = try await fixture.service.processedContent(
            bookId: "sample", chapterNumber: 1, mode: .none, rawText: "original"
        )
        XCTAssertEqual(raw, "original")
        XCTAssertEqual(BilingualURLProtocol.requests().count, 3)
        let rewrite = try await fixture.service.processedContent(
            bookId: "sample", chapterNumber: 1, mode: .rewrite, rawText: "rewrite source"
        )
        XCTAssertEqual(rewrite, "rewritten")
        XCTAssertNil(try body(XCTUnwrap(BilingualURLProtocol.requests().last))["response_format"])
        XCTAssertEqual(try fixture.cache.countAll(), 2)
        XCTAssertEqual(try fixture.cache.get(bookId: "sample", chapterNumber: 1, mode: .bilingual)?.content, content)
    }

    func testSemanticFailureNeverWritesPartialAndFailedReprocessRetainsOldCache() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        BilingualURLProtocol.configure(invalid: true)
        let source = String(repeating: "first ", count: 60) + "\n\n" + String(repeating: "second ", count: 60)
        let failedRunId = UUID()
        do {
            _ = try await fixture.service.processedContent(
                bookId: "sample",
                chapterNumber: 1,
                mode: .bilingual,
                rawText: source,
                runId: failedRunId
            )
            XCTFail("Missing pair must fail")
        } catch {
            XCTAssertEqual(try fixture.cache.countAll(), 0)
        }
        let failedEntries = await DiagnosticsLog.shared.snapshot().filter { $0.runId == failedRunId }
        XCTAssertTrue(failedEntries.contains { $0.event == "run.fail" })
        XCTAssertTrue(failedEntries.contains {
            $0.event == "chunk.fail" && $0.detail?.contains("stage=validation") == true
        })
        BilingualURLProtocol.configure(invalid: false)
        let old = try await fixture.service.processedContent(
            bookId: "sample",
            chapterNumber: 1,
            mode: .bilingual,
            rawText: source
        )
        BilingualURLProtocol.configure(invalid: true)
        do {
            _ = try await fixture.service.reprocess(
                bookId: "sample",
                chapterNumber: 1,
                mode: .bilingual,
                rawText: source
            )
            XCTFail("Failed refresh must not replace old cache")
        } catch {
            XCTAssertEqual(try fixture.cache.get(bookId: "sample", chapterNumber: 1, mode: .bilingual)?.content, old)
        }
    }

    func testCorruptCacheIsRejectedWithoutNetworkOrRawJSONRendering() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let date = Date()
        try fixture.cache.upsert(ProcessedChapter(
            bookId: "sample", chapterNumber: 1, mode: .bilingual, content: "{invalid}",
            contentHash: "fixture", createdAt: date, updatedAt: date
        ))
        BilingualURLProtocol.configure(invalid: false)
        do {
            _ = try await fixture.service.processedContent(
                bookId: "sample",
                chapterNumber: 1,
                mode: .bilingual,
                rawText: "source"
            )
            XCTFail("Corrupt cache must fail explicitly")
        } catch {
            XCTAssertTrue(BilingualURLProtocol.requests().isEmpty)
        }
    }

    func testCancelledMissDoesNotSaveCache() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        BilingualURLProtocol.configure(invalid: false)
        let consumer = Task {
            try await fixture.service.processedContent(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "source"
            )
        }
        try await waitForRequest()
        consumer.cancel()
        do {
            _ = try await consumer.value
            XCTFail("Cancelled consumer must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(try fixture.cache.countAll(), 0)
    }

    func testCancelledRefreshPreservesOldCache() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        BilingualURLProtocol.configure(invalid: false)
        let old = try await fixture.service.processedContent(
            bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "old source"
        )
        BilingualURLProtocol.configure(invalid: false)
        let consumer = Task {
            try await fixture.service.reprocess(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "replacement source"
            )
        }
        try await waitForRequest()
        consumer.cancel()
        do {
            _ = try await consumer.value
            XCTFail("Cancelled refresh must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(try fixture.cache.get(bookId: "sample", chapterNumber: 1, mode: .bilingual)?.content, old)
    }

    func testCancelledSharedConsumerDoesNotCancelLiveConsumer() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        BilingualURLProtocol.configure(invalid: false)
        let runId = UUID()
        let originRunId = UUID()
        let first = Task {
            try await fixture.service.processedContent(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "source",
                runId: originRunId, source: "prefetch"
            )
        }
        try await waitForRequest()
        let second = Task {
            try await fixture.service.processedContent(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "source", runId: runId
            )
        }
        let deadline = Date().addingTimeInterval(3)
        while !(await DiagnosticsLog.shared.snapshot()).contains(where: {
            $0.runId == runId && $0.event == "dedup.shared"
        }), Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertTrue(entries.contains { $0.runId == runId && $0.event == "dedup.shared" })
        first.cancel()
        let result = try await second.value
        do {
            _ = try await first.value
            XCTFail("Cancelled shared consumer must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(BilingualURLProtocol.requests().count, 1)
        XCTAssertEqual(try fixture.cache.get(bookId: "sample", chapterNumber: 1, mode: .bilingual)?.content, result)
        let groups = LogRunBuilder.build(from: await DiagnosticsLog.shared.snapshot())
        let joined = try XCTUnwrap(groups.first { $0.id == runId.uuidString })
        XCTAssertEqual(joined.status, .success)
        XCTAssertEqual(joined.chunkProgress, "1/1 đoạn")
        XCTAssertTrue(joined.visibleEntries.contains { $0.kind == .api && $0.statusCode == 200 })
        XCTAssertEqual(groups.first { $0.id == originRunId.uuidString }?.status, .cancelled)
    }

    func testLogCoverKeepsReaderAndPrefetchWithoutDuplicateCurrentRequest() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.settings.aiMode = .bilingual
        fixture.settings.prefetchCount = 1
        BilingualURLProtocol.configure(invalid: false)
        let reader = ReaderViewModel(
            bookId: "log-cover", repository: LogCoverRepository(), settingsStore: fixture.settings,
            cache: fixture.cache, aiService: fixture.service
        )
        defer { reader.onDisappear() }
        await reader.load()
        try await waitForRequest()
        XCTAssertTrue(reader.isAIProcessing)
        reader.prepareForLog()
        reader.onDisappear()
        XCTAssertTrue(reader.isAIProcessing)
        reader.onAppear()
        await reader.load(source: .returnFromLog)
        let deadline = Date().addingTimeInterval(3)
        while try (reader.isAIProcessing || fixture.cache.countAll() < 2), Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertNotNil(reader.currentBilingualParagraphs)
        XCTAssertEqual(try fixture.cache.countAll(), 2)
        XCTAssertEqual(BilingualURLProtocol.requests().count, 2)
        XCTAssertNil(reader.aiError)
    }

    func testActualReaderExitStillCancelsCurrentRequest() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.settings.aiMode = .bilingual
        fixture.settings.prefetchCount = 0
        BilingualURLProtocol.configure(invalid: false)
        let reader = ReaderViewModel(
            bookId: "reader-exit", repository: LogCoverRepository(), settingsStore: fixture.settings,
            cache: fixture.cache, aiService: fixture.service
        )
        await reader.load()
        try await waitForRequest()
        reader.onDisappear()
        XCTAssertFalse(reader.isAIProcessing)
        let deadline = Date().addingTimeInterval(3)
        while !(await DiagnosticsLog.shared.snapshot()).contains(where: {
            $0.bookId == "reader-exit" && $0.errorCode == URLError.cancelled.rawValue
        }), Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertEqual(try fixture.cache.countAll(), 0)
        XCTAssertEqual(BilingualURLProtocol.requests().count, 1)
        XCTAssertNil(reader.aiError)
    }

    func waitForRequest() async throws {
        let deadline = Date().addingTimeInterval(3)
        while BilingualURLProtocol.requests().isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertFalse(BilingualURLProtocol.requests().isEmpty)
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    func makeFixture() throws -> Fixture {
        let name = "BilingualPipelineTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let store = SettingsStore(userDefaults: defaults)
        store.openaiAPIURL = "https://bilingual-fixture.test/v1/chat/completions"
        store.aiProvider = "openai"
        store.aiMinChunkSize = 500
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BilingualURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = AIReadingService(
            cache: cache,
            client: AIClient(settings: store, session: session),
            settings: store
        )
        return Fixture(
            service: service,
            cache: cache,
            session: session,
            settings: store,
            defaults: defaults,
            suite: name
        )
    }

    struct Fixture {
        let service: AIReadingService
        let cache: SQLiteProcessedChapterCache
        let session: URLSession
        let settings: SettingsStore
        let defaults: UserDefaults
        let suite: String

        func cleanUp() {
            session.invalidateAndCancel()
            defaults.removePersistentDomain(forName: suite)
        }
    }
}

final nonisolated class BilingualURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var invalid = false
    private nonisolated(unsafe) static var captured: [URLRequest] = []
    private nonisolated(unsafe) static var completed: [String] = []
    private nonisolated(unsafe) static var holdResponses = false
    private nonisolated(unsafe) static var heldWork: [DispatchWorkItem] = []
    private var work: DispatchWorkItem?

    static func configure(invalid: Bool, holdResponses: Bool = false) {
        lock.withLock {
            self.invalid = invalid
            self.holdResponses = holdResponses
            for item in heldWork {
                item.cancel()
            }
            heldWork = []
            captured = []
            completed = []
        }
    }

    static func releasePendingResponses() {
        let items: [DispatchWorkItem] = lock.withLock {
            holdResponses = false
            let pending = heldWork
            heldWork = []
            return pending
        }
        for item in items {
            DispatchQueue.global().async(execute: item)
        }
    }

    static func requests() -> [URLRequest] {
        lock.withLock { captured }
    }

    static func completedIDs() -> [String] {
        lock.withLock { completed }
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "bilingual-fixture.test"
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var copy = request
        if copy.httpBody == nil, let stream = copy.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            var count = stream.read(&buffer, maxLength: buffer.count)
            while count > 0 {
                data.append(buffer, count: count)
                count = stream.read(&buffer, maxLength: buffer.count)
            }
            copy.httpBody = data
        }
        let invalid = Self.lock.withLock {
            Self.captured.append(copy)
            return Self.invalid
        }
        let body = (try? JSONSerialization.jsonObject(with: copy.httpBody ?? Data())) as? [String: Any]
        let messages = body?["messages"] as? [[String: Any]]
        let input = messages?.last?["content"] as? String ?? ""
        let source = (try? JSONSerialization.jsonObject(with: Data(input.utf8))) as? [String: Any]
        let paragraphs = source?["paragraphs"] as? [[String: String]]
        let id = paragraphs?.first?["id"] ?? "rewrite"
        let pairs = (paragraphs ?? []).reversed().map { paragraph in
            ["id": paragraph["id"] ?? "", "vi": paragraph["text"] ?? "", "en": "English \(paragraph["id"] ?? "")"]
        }
        let content = paragraphs == nil ? "rewritten" : (String(
            bytes: (try? JSONSerialization
                .data(withJSONObject: ["paragraphs": invalid && id == "p002" ? [] : pairs])) ?? Data(),
            encoding: .utf8
        ) ?? "")
        // swiftlint:disable trailing_comma
        let responseData = (try? JSONSerialization.data(withJSONObject: ["choices": [
            ["finish_reason": "stop", "message": ["content": content]],
        ]])) ?? Data()
        // swiftlint:enable trailing_comma
        let work = DispatchWorkItem { [weak self] in
            guard let self, !(self.work?.isCancelled ?? false) else { return }
            Self.lock.withLock { Self.completed.append(id) }
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        }
        self.work = work

        let shouldHold = Self.lock.withLock { () -> Bool in
            if Self.holdResponses {
                Self.heldWork.append(work)
                return true
            }
            return false
        }
        if !shouldHold {
            DispatchQueue.global().asyncAfter(deadline: .now() + (id == "p001" ? 0.15 : 0), execute: work)
        }
    }

    override func stopLoading() {
        work?.cancel()
    }
}

private struct LogCoverRepository: BookRepository {
    func listBooks() throws -> [Book] {
        []
    }

    func book(slug: String) throws -> Book? {
        Book(id: slug, name: "Fixture", author: nil, count: 2, references: ["First", "Second"])
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        "<h1>Chapter \(number)</h1><p>Original body.</p>"
    }

    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}
