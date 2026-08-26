@testable import novels
import XCTest

@MainActor
final class ReaderNavigationTests: XCTestCase {
    var tempRoot: URL!
    var store: SettingsStore!
    var repo: FileBookRepository!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let slug = "nav-slug"
            let bookDir = tempRoot.appendingPathComponent(slug)
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("chapters"),
                withIntermediateDirectories: true
            )
            let book = Book(id: slug, name: "Nav Test", author: "A", count: 2, references: ["C1", "C2"])
            let data = try JSONEncoder().encode(book)
            try data.write(to: bookDir.appendingPathComponent("book.json"))
            for index in 1 ... 2 {
                try "<p>Content \(index)</p>".write(
                    to: bookDir.appendingPathComponent("chapters/chapter-\(index).html"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        } catch {
            XCTFail("Setup failed: \(error)")
        }
        store = SettingsStore(userDefaults: UserDefaults(suiteName: "test.nav.\(UUID().uuidString)")!)
        repo = FileBookRepository(root: tempRoot, fileManager: .default)
    }

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        super.tearDown()
    }

    private func makeVM(count _: Int = 2) -> ReaderViewModel {
        ReaderViewModel(bookId: "nav-slug", repository: repo, settingsStore: store)
    }

    func testPrevNextDisabledAtBounds() async {
        let viewModel = makeVM(count: 2)
        await viewModel.load()
        XCTAssertFalse(viewModel.canGoPrev)
        XCTAssertTrue(viewModel.canGoNext)
        await viewModel.goNext()
        XCTAssertTrue(viewModel.canGoPrev)
        XCTAssertFalse(viewModel.canGoNext)
    }

    func testPrevDisabledAtFirstNextDisabledAtLast() async {
        let viewModel = makeVM(count: 2)
        await viewModel.load()
        XCTAssertEqual(viewModel.chapterNumber, 1)
        await viewModel.goPrev()
        XCTAssertEqual(viewModel.chapterNumber, 1)
        await viewModel.goNext()
        XCTAssertEqual(viewModel.chapterNumber, 2)
        await viewModel.goNext()
        XCTAssertEqual(viewModel.chapterNumber, 2)
    }

    func testRapidNavDoesNotCorruptState() async {
        let viewModel = makeVM(count: 2)
        await viewModel.load()
        await viewModel.goNext()
        await viewModel.goPrev()
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertFalse(viewModel.canGoPrev)
        XCTAssertTrue(viewModel.canGoNext)
    }
}
