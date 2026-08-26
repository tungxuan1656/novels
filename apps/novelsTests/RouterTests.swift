@testable import novels
import XCTest

@MainActor
final class RouterTests: XCTestCase {
    func testInitialRouteLibraryWhenNoSession() throws {
        let store = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        store.session = nil
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 0)
        XCTAssertNil(router.toast.current)
    }

    func testInvalidBookIdToastsAndStaysOnLibrary() throws {
        let ud = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let session = ReadingSession(bookId: "missing-slug", onScreen: true, offset: 0, chapterNumber: 1)
        if let data = try? JSONEncoder().encode(session) {
            ud.set(data, forKey: DefaultsKeys.readingSession)
        }
        let store = SettingsStore(userDefaults: ud)
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 0)
        XCTAssertEqual(router.toast.current?.message, "Không tìm thấy sách")
    }

    func testValidBookIdPushesReading() throws {
        let book = Book(id: "valid-slug", name: "V", author: "A", count: 1, references: ["C1"])
        let ud = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let session = ReadingSession(bookId: "valid-slug", onScreen: true, offset: 0, chapterNumber: 1)
        if let data = try? JSONEncoder().encode(session) {
            ud.set(data, forKey: DefaultsKeys.readingSession)
        }
        let store = SettingsStore(userDefaults: ud)
        let router = Router(settingsStore: store, repository: FakeRepository(books: [book]))
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 1)
    }

    func testReadingBackClearsOnScreen() throws {
        let ud = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "s", onScreen: true, offset: 10, chapterNumber: 1)
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.didPopFromReading()
        XCTAssertEqual(store.session?.onScreen, false)
    }

    func testRouterPushesAddBook() throws {
        let store = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.push(.addBook)
        XCTAssertEqual(router.path.count, 1)
        router.pop()
        XCTAssertEqual(router.path.count, 0)
    }

    func testAddBookViewDefaultSortIsNameAZ() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let catalog = RouterTestMockCatalog(books: [])
        let downloader = RouterTestMockDownloader()
        let viewModel = ImportViewModel(
            catalogService: catalog,
            repository: repo,
            downloader: downloader
        )
        XCTAssertEqual(viewModel.sortOption, .nameAZ)
        let view = AddBookView(viewModel: viewModel)
        XCTAssertEqual(view.viewModel.sortOption, .nameAZ)
    }
}

struct FakeRepository: BookRepository {
    var books: [Book]
    func listBooks() throws -> [Book] {
        books
    }

    func book(slug: String) throws -> Book? {
        books.first(where: { $0.id == slug })
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        ""
    }

    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}

private actor RouterTestMockCatalog: CatalogFetching {
    var books: [ExportedBook]
    init(books: [ExportedBook]) {
        self.books = books
    }

    func fetchCatalog() async throws -> [ExportedBook] {
        books
    }
}

private struct RouterTestMockDownloader: Downloader {
    func download(from url: URL) async throws -> URL {
        throw ImportError.downloadFailed
    }
}
