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
        do {
            _ = try await fixture.service.processedContent(
                bookId: "sample",
                chapterNumber: 1,
                mode: .bilingual,
                rawText: source
            )
            XCTFail("Missing pair must fail")
        } catch {
            XCTAssertEqual(try fixture.cache.countAll(), 0)
        }
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
        let first = Task {
            try await fixture.service.processedContent(
                bookId: "sample", chapterNumber: 1, mode: .bilingual, rawText: "source"
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
    }

    private func waitForRequest() async throws {
        let deadline = Date().addingTimeInterval(3)
        while BilingualURLProtocol.requests().isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertFalse(BilingualURLProtocol.requests().isEmpty)
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    private func makeFixture() throws -> Fixture {
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
        return Fixture(service: service, cache: cache, session: session, defaults: defaults, suite: name)
    }

    private struct Fixture {
        let service: AIReadingService
        let cache: SQLiteProcessedChapterCache
        let session: URLSession
        let defaults: UserDefaults
        let suite: String

        func cleanUp() {
            session.invalidateAndCancel()
            defaults.removePersistentDomain(forName: suite)
        }
    }
}

private final nonisolated class BilingualURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var invalid = false
    private nonisolated(unsafe) static var captured: [URLRequest] = []
    private nonisolated(unsafe) static var completed: [String] = []
    private var work: DispatchWorkItem?

    static func configure(invalid: Bool) {
        lock.withLock {
            self.invalid = invalid
            captured = []
            completed = []
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
        let work = DispatchWorkItem { [self] in
            Self.lock.withLock { Self.completed.append(id) }
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        }
        self.work = work
        DispatchQueue.global().asyncAfter(deadline: .now() + (id == "p001" ? 0.15 : 0), execute: work)
    }

    override func stopLoading() {
        work?.cancel()
    }
}
