@testable import novels
import XCTest

@MainActor
final class ReferencesTests: XCTestCase {
    func testReferencesCountMatches() {
        let book = Book(id: "s", name: "N", author: "A", count: 2, references: ["C1", "C2"])
        XCTAssertEqual(book.references.count, 2)
        XCTAssertEqual(book.count, 2)
    }

    func testGoToChapterUpdatesCurrent() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let slug = "ref-slug"
            let bookDir = tempRoot.appendingPathComponent(slug)
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("chapters"),
                withIntermediateDirectories: true
            )
            let book = Book(id: slug, name: "Test", author: "A", count: 2, references: ["C1", "C2"])
            let data = try JSONEncoder().encode(book)
            try data.write(to: bookDir.appendingPathComponent("book.json"))
            for index in 1 ... 2 {
                try "<p>Content \(index)</p>".write(
                    to: bookDir.appendingPathComponent("chapters/chapter-\(index).html"),
                    atomically: true,
                    encoding: .utf8
                )
            }
            let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
            let store = SettingsStore(userDefaults: defaults)
            let repo = FileBookRepository(root: tempRoot, fileManager: .default)
            let viewModel = ReaderViewModel(bookId: slug, repository: repo, settingsStore: store)
            await viewModel.load()
            XCTAssertEqual(viewModel.chapterNumber, 1)
            await viewModel.goToChapter(2)
            XCTAssertEqual(viewModel.chapterNumber, 2)
            XCTAssertEqual(store.session?.chapterNumber, 2)
        } catch {
            XCTFail("Setup failed: \(error)")
        }
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testReferencesViewInit() throws {
        let book = Book(id: "s", name: "N", author: "A", count: 2, references: ["C1", "C2"])
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: defaults)
        let router = Router(settingsStore: store)
        let view = ReferencesView(book: book, current: 2, onSelect: { _ in }, router: router)
        XCTAssertNotNil(view.body)
    }
}
