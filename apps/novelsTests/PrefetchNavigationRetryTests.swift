import Foundation
@testable import novels
import XCTest

extension BilingualPipelineTests {
    func testNextRecoversFailedChapterBeforeNewTail() async throws {
        try await verifyNavigationRecoversFailure(goNext: true)
    }

    func testPreviousRecoversFailedChapterInsideWindow() async throws {
        try await verifyNavigationRecoversFailure(goNext: false)
    }

    private func verifyNavigationRecoversFailure(goNext: Bool) async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.settings.aiMode = .bilingual
        fixture.settings.prefetchCount = 3
        BilingualURLProtocol.configure(invalid: false)
        let bookId = "navigation-retry"
        let paragraph = BilingualParagraph(id: "p001", vi: "Cached", en: "Cached")
        let content = try BilingualChapter(paragraphs: [paragraph]).encoded()
        for number in goNext ? [2, 3, 5] : [2, 3, 5, 6] {
            try fixture.cache.upsert(ProcessedChapter(
                bookId: bookId, chapterNumber: number, mode: .bilingual, content: content,
                contentHash: "fixture", createdAt: Date(), updatedAt: Date()
            ))
        }
        let repository = PrefetchRetryRepository()
        let manager = PrefetchManager()
        let reader = ReaderViewModel(
            bookId: bookId, repository: repository, settingsStore: fixture.settings,
            cache: fixture.cache, aiService: fixture.service, prefetchManager: manager
        )
        defer { reader.onDisappear() }
        await reader.goToChapter(goNext ? 2 : 3)
        try await waitForRetryBatch(manager)
        let failed = await manager.currentStatus()
        XCTAssertEqual(failed.errors.count, 1)
        XCTAssertEqual(repository.failedChapterReads, 2)
        XCTAssertNil(try fixture.cache.get(bookId: bookId, chapterNumber: 4, mode: .bilingual))
        XCTAssertTrue(BilingualURLProtocol.requests().isEmpty)

        repository.recover()
        if goNext {
            await reader.goNext()
        } else {
            await reader.goPrev()
        }
        try await waitForRetryBatch(manager)
        XCTAssertEqual(repository.failedChapterReads, 3)
        XCTAssertNotNil(try fixture.cache.get(bookId: bookId, chapterNumber: 4, mode: .bilingual))
        if goNext {
            XCTAssertNotNil(try fixture.cache.get(bookId: bookId, chapterNumber: 6, mode: .bilingual))
        }
        let requests = BilingualURLProtocol.requests()
        XCTAssertEqual(requests.count, goNext ? 2 : 1)
        let firstBody = try String(data: XCTUnwrap(requests.first?.httpBody), encoding: .utf8)
        XCTAssertTrue(firstBody?.contains("Original body 4.") == true)
        let completed = await manager.currentStatus()
        XCTAssertTrue(completed.errors.isEmpty)
    }

    private func waitForRetryBatch(_ manager: PrefetchManager) async throws {
        let deadline = Date().addingTimeInterval(5)
        while await manager.currentStatus().isRunning, Date() < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        let status = await manager.currentStatus()
        XCTAssertFalse(status.isRunning, "Prefetch must stop after its bounded retry")
    }
}

private final nonisolated class PrefetchRetryRepository: BookRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var failing = true
    private var chapterReads = 0

    var failedChapterReads: Int {
        lock.withLock { chapterReads }
    }

    func recover() {
        lock.withLock { failing = false }
    }

    func listBooks() throws -> [Book] {
        []
    }

    func book(slug: String) throws -> Book? {
        Book(id: slug, name: "Fixture", author: nil, count: 10, references: [])
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        if number == 4 {
            let shouldFail = lock.withLock {
                chapterReads += 1
                return failing
            }
            if shouldFail {
                throw CocoaError(.fileReadNoSuchFile)
            }
        }
        return "<h1>Chapter \(number)</h1><p>Original body \(number).</p>"
    }

    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}
