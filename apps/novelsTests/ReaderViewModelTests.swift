@testable import novels
import XCTest

@MainActor
final class ReaderViewModelTests: XCTestCase {
    var tempRoot: URL!
    var store: SettingsStore!
    var repo: FileBookRepository!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let slug = "test-slug"
            let bookDir = tempRoot.appendingPathComponent(slug)
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("chapters"),
                withIntermediateDirectories: true
            )
            let book = Book(id: slug, name: "Test", author: "A", count: 3, references: ["C1", "C2", "C3"])
            let data = try JSONEncoder().encode(book)
            try data.write(to: bookDir.appendingPathComponent("book.json"))
            for index in 1 ... 3 {
                try "<p>Content \(index)</p>".write(
                    to: bookDir.appendingPathComponent("chapters/chapter-\(index).html"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        } catch {
            XCTFail("Setup failed: \(error)")
        }
        store = SettingsStore(userDefaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        repo = FileBookRepository(root: tempRoot, fileManager: .default)
    }

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        super.tearDown()
    }

    func testLoadFirstChapter() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await viewModel.load()
        XCTAssertEqual(viewModel.blocks.count, 1)
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertFalse(viewModel.canGoPrev)
        XCTAssertTrue(viewModel.canGoNext)
    }

    func testBoundsDisable() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        viewModel.chapterNumber = 3
        await viewModel.load()
        XCTAssertFalse(viewModel.canGoNext)
        XCTAssertTrue(viewModel.canGoPrev)
        await viewModel.goNext()
        XCTAssertEqual(viewModel.chapterNumber, 3)
    }

    func testMissingFileShowsToast() async {
        try? FileManager.default.removeItem(at: tempRoot.appendingPathComponent("test-slug/chapters/chapter-2.html"))
        let toast = ToastCenter()
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store, toastCenter: toast)
        viewModel.chapterNumber = 2
        await viewModel.load()
        XCTAssertEqual(toast.lastMessage, "Không tìm thấy chương")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.blocks.count, 0)
    }

    func testRapidNavDoesNotCorruptOffset() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await viewModel.load()
        viewModel.saveOffset(123.4)
        await viewModel.goNext()
        await viewModel.goPrev()
        XCTAssertEqual(store.session?.chapterNumber, 1)
        XCTAssertEqual(store.session?.offset, 0)
    }

    func testGoPrevAtFirstDoesNotChange() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await viewModel.load()
        XCTAssertEqual(viewModel.chapterNumber, 1)
        await viewModel.goPrev()
        XCTAssertEqual(viewModel.chapterNumber, 1)
    }

    func testGoToChapterClamps() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await viewModel.load()
        await viewModel.goToChapter(99)
        XCTAssertEqual(viewModel.chapterNumber, 3)
        await viewModel.goToChapter(0)
        XCTAssertEqual(viewModel.chapterNumber, 1)
    }

    func testOnAppearOnDisappearPersistsSession() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await viewModel.load()
        viewModel.onAppear()
        XCTAssertEqual(store.session?.bookId, "test-slug")
        XCTAssertEqual(store.session?.onScreen, true)
        viewModel.onDisappear()
        XCTAssertEqual(store.session?.onScreen, false)
    }

    func testSaveOffsetPersists() async {
        let viewModel = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await viewModel.load()
        viewModel.onAppear()
        viewModel.saveOffset(42.5)
        XCTAssertEqual(store.session?.offset, 42.5)
        XCTAssertEqual(store.session?.chapterNumber, 1)
    }
}
