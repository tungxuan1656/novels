import Foundation
@testable import novels
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class BilingualReaderTests: XCTestCase {
    func testTypedPublicationAndIndependentModeSwitching() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let pairs = [BilingualParagraph(id: "p001", vi: "Vietnamese", en: "English")]
        try fixture.save(BilingualChapter(paragraphs: pairs).encoded(), mode: .bilingual)
        try fixture.save("Translated", mode: .rewrite)
        await fixture.reader.setAIMode(.bilingual)
        XCTAssertEqual(fixture.reader.currentBilingualParagraphs, pairs)
        XCTAssertNil(fixture.reader.currentProcessedContent)
        await fixture.reader.setAIMode(.rewrite)
        XCTAssertEqual(fixture.reader.currentProcessedContent, "Translated")
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        await fixture.reader.setAIMode(.none)
        XCTAssertNil(fixture.reader.currentProcessedContent)
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        XCTAssertFalse(fixture.reader.isAIProcessing)
        XCTAssertEqual(fixture.reader.chapterBody, "Original body.")
        XCTAssertEqual(fixture.settings.aiMode, .none)
    }

    func testInvalidCacheAndFailedRefreshUseOriginalWithoutDestroyingCache() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try fixture.save("{invalid}", mode: .bilingual)
        await fixture.reader.setAIMode(.bilingual)
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        XCTAssertNil(fixture.reader.currentProcessedContent)
        XCTAssertNotNil(fixture.reader.aiError)
        XCTAssertFalse(fixture.reader.isAIProcessing)
        let old = try BilingualChapter(paragraphs: [
            BilingualParagraph(id: "p001", vi: "Vietnamese", en: "English"),
        ]).encoded()
        try fixture.save(old, mode: .bilingual)
        await fixture.reader.setAIMode(.bilingual)
        XCTAssertNotNil(fixture.reader.currentBilingualParagraphs)
        await fixture.reader.reprocess()
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        XCTAssertNil(fixture.reader.currentProcessedContent)
        XCTAssertTrue(fixture.reader.aiError?.contains("Hiển thị bản gốc") == true)
        XCTAssertEqual(fixture.reader.chapterBody, "Original body.")
        XCTAssertEqual(
            try fixture.cache.get(bookId: "reader-fixture", chapterNumber: 1, mode: .bilingual)?.content,
            old
        )
    }

    func testRapidModeSelectionsAndChapterIdentityNeverPublishOldPairs() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let old = try BilingualChapter(paragraphs: [
            BilingualParagraph(id: "p001", vi: "Vietnamese", en: "English"),
        ]).encoded()
        try fixture.save(old, mode: .bilingual)
        let first = Task { await fixture.reader.setAIMode(.bilingual) }
        await Task.yield()
        await fixture.reader.setAIMode(.none)
        await first.value
        XCTAssertEqual(fixture.reader.aiMode, .none)
        XCTAssertFalse(fixture.reader.isAIProcessing)
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        await fixture.reader.setAIMode(.bilingual)
        XCTAssertNotNil(fixture.reader.currentBilingualParagraphs)
        fixture.reader.chapterNumber = 2
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        XCTAssertNil(fixture.reader.currentProcessedContent)
        await fixture.reader.load()
        await fixture.reader.setAIMode(.none)
        XCTAssertNil(fixture.reader.currentBilingualParagraphs)
        XCTAssertFalse(fixture.reader.isAIProcessing)
    }

    private func makeFixture() throws -> Fixture {
        let suite = "BilingualReaderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = SettingsStore(userDefaults: defaults)
        settings.prefetchCount = 0
        // Invalid URL fails before networking; cached publication needs no AI request.
        settings.openaiAPIURL = "http://["
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let reader = ReaderViewModel(
            bookId: "reader-fixture", repository: ReaderFixtureRepository(), settingsStore: settings, cache: cache
        )
        reader.chapterBody = "Original body."
        return Fixture(reader: reader, settings: settings, cache: cache, defaults: defaults, suite: suite)
    }

    @MainActor
    private struct Fixture {
        let reader: ReaderViewModel
        let settings: SettingsStore
        let cache: SQLiteProcessedChapterCache
        let defaults: UserDefaults
        let suite: String

        func save(_ content: String, mode: AIMode) throws {
            let date = Date()
            try cache.upsert(ProcessedChapter(
                bookId: "reader-fixture", chapterNumber: 1, mode: mode, content: content,
                contentHash: "fixture", createdAt: date, updatedAt: date
            ))
        }

        func cleanUp() {
            reader.onDisappear()
            defaults.removePersistentDomain(forName: suite)
        }
    }
}

// swiftlint:enable trailing_comma

private struct ReaderFixtureRepository: BookRepository {
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
