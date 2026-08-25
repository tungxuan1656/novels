@testable import novels
import XCTest

@MainActor
final class ReadingShellTests: XCTestCase {
    func testPushReadingSetsOnScreenTrue() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = SettingsStore(userDefaults: userDefaults)
        store.session = ReadingSession(bookId: "a", onScreen: false, offset: 0, chapterNumber: 1)
        let repository = FakeRepository(books: [Book(id: "a", name: "N", author: nil, count: 1, references: ["C1"])])
        let router = Router(settingsStore: store, repository: repository)
        router.push(.reading(bookId: "a"))
        XCTAssertEqual(store.session?.onScreen, true)
        XCTAssertEqual(store.session?.bookId, "a")
    }

    func testPopReadingClearsOnScreen() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = SettingsStore(userDefaults: userDefaults)
        store.session = ReadingSession(bookId: "a", onScreen: true, offset: 5, chapterNumber: 1)
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.didPopFromReading()
        XCTAssertEqual(store.session?.onScreen, false)
        XCTAssertEqual(store.session?.offset, 5)
    }

    func testBackAtRootDoesNotCrash() throws {
        let settings = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        let router = Router(settingsStore: settings, repository: FakeRepository(books: []))
        router.pop()
        XCTAssertEqual(router.path.count, 0)
        router.pop()
        XCTAssertEqual(router.path.count, 0)
    }
}
