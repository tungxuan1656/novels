@testable import novels
import XCTest

@MainActor
final class RouterReadingTests: XCTestCase {
    func testRouterPushReadingSetsSessionOnScreen() throws {
        let ud = try XCTUnwrap(UserDefaults(suiteName: "test.router.push.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: ud)
        store.session = nil
        let router = Router(settingsStore: store, repository: FakeReadingRepo(exists: true))
        router.push(.reading(bookId: "slug-a"))
        XCTAssertEqual(store.session?.bookId, "slug-a")
        XCTAssertEqual(store.session?.onScreen, true)
        XCTAssertEqual(store.session?.chapterNumber, 1)
        XCTAssertEqual(router.path.count, 1)
    }

    func testPopReadingClearsOnScreenKeepsOffset() throws {
        let ud = try XCTUnwrap(UserDefaults(suiteName: "test.router.pop.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "slug-a", onScreen: true, offset: 88, chapterNumber: 2)
        store.save()
        let router = Router(settingsStore: store, repository: FakeReadingRepo(exists: true))
        router.didPopFromReading()
        XCTAssertEqual(store.session?.onScreen, false)
        XCTAssertEqual(store.session?.offset, 88)
        XCTAssertEqual(store.session?.bookId, "slug-a")
        XCTAssertEqual(store.session?.chapterNumber, 2)
    }

    func testRestoreWithMissingBookToasts() throws {
        let ud = try XCTUnwrap(UserDefaults(suiteName: "test.router.restore.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "missing", onScreen: true, offset: 0, chapterNumber: 1)
        store.save()
        let router = Router(settingsStore: store, repository: FakeReadingRepo(exists: false))
        router.restoreInitialRoute()
        XCTAssertEqual(router.toast.current?.message, "Không tìm thấy sách")
        // Also via lastMessage extension
        XCTAssertEqual(router.toast.lastMessage, "Không tìm thấy sách")
        XCTAssertNil(store.session)
        XCTAssertEqual(router.path.count, 0)
    }

    func testReferencesPushDoesNotChangeSession() throws {
        let ud = try XCTUnwrap(UserDefaults(suiteName: "test.router.ref.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "slug-a", onScreen: true, offset: 42, chapterNumber: 3)
        store.save()
        let router = Router(settingsStore: store, repository: FakeReadingRepo(exists: true))
        router.push(.references(bookId: "slug-a"))
        XCTAssertEqual(store.session?.bookId, "slug-a")
        XCTAssertEqual(store.session?.offset, 42)
        XCTAssertEqual(store.session?.chapterNumber, 3)
        XCTAssertEqual(store.session?.onScreen, true)
        XCTAssertEqual(router.path.count, 1)
    }
}

struct FakeReadingRepo: BookRepository {
    var exists: Bool
    var books: [Book] = []

    func listBooks() throws -> [Book] {
        books
    }

    func book(slug: String) throws -> Book? {
        if exists {
            // Return a dummy book for valid slug unless caller wants missing
            if let found = books.first(where: { $0.id == slug }) {
                return found
            }
            return Book(id: slug, name: "Dummy", author: "A", count: 5, references: Array(repeating: "C", count: 5))
        } else {
            return nil
        }
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        ""
    }

    func save(validatedRoot: URL, slug: String) throws {}

    func deleteBook(slug: String) throws {}
}
