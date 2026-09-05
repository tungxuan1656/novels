@testable import novels
import XCTest

/// Phase 1 seamless-restore tests: kill → relaunch must reopen the same
/// book + chapter + scroll offset, even when killed while TOC/references/log
/// cover Reader, from chapter top (offset 0), or right after backgrounding.
@MainActor
final class SeamlessRestoreTests: XCTestCase {
    private func makeStore() throws -> (SettingsStore, UserDefaults) {
        let ud = try XCTUnwrap(UserDefaults(suiteName: "test.seamless.\(UUID().uuidString)"))
        return (SettingsStore(userDefaults: ud), ud)
    }

    private func makeRepo(id: String = "seamless-a") -> FakeRepository {
        let book = Book(id: id, name: "S", author: "A", count: 5, references: ["C1", "C2", "C3", "C4", "C5"])
        return FakeRepository(books: [book])
    }

    /// (a) Cover (push TOC/references/log over Reader) keeps onScreen + offset,
    /// so kill-then-relaunch restores Reading instead of stranding on Library.
    func testCoverKeepsSessionRestorable() throws {
        let (store, ud) = try makeStore()
        let repo = makeRepo()
        let viewModel = ReaderViewModel(bookId: "seamless-a", repository: repo, settingsStore: store)
        viewModel.onAppear()
        viewModel.saveOffset(123.4)
        // TOC pushed over Reader: disappear is a cover, not a back.
        viewModel.onDisappear()
        XCTAssertEqual(store.session?.onScreen, true)
        XCTAssertEqual(store.session?.offset ?? -1, 123.4, accuracy: 0.001)
        // Simulate kill + relaunch: fresh store from the same suite.
        let relaunched = SettingsStore(userDefaults: ud)
        XCTAssertEqual(relaunched.session?.onScreen, true)
        let router = Router(settingsStore: relaunched, repository: repo)
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 1)
    }

    /// (a2) Pushing references at router level leaves the session restorable.
    func testReferencesPushKeepsRestorable() throws {
        let (store, ud) = try makeStore()
        let repo = makeRepo()
        store.session = ReadingSession(bookId: "seamless-a", onScreen: true, offset: 42, chapterNumber: 3)
        store.save()
        let router = Router(settingsStore: store, repository: repo)
        router.push(.references(bookId: "seamless-a"))
        XCTAssertEqual(store.session?.onScreen, true)
        let relaunched = SettingsStore(userDefaults: ud)
        let router2 = Router(settingsStore: relaunched, repository: repo)
        router2.restoreInitialRoute()
        XCTAssertEqual(router2.path.count, 1)
    }

    /// (b) Only a true back (popReading) clears onScreen; relaunch stays on Library.
    func testTrueBackClearsAndStaysOnLibrary() throws {
        let (store, ud) = try makeStore()
        let repo = makeRepo()
        let viewModel = ReaderViewModel(bookId: "seamless-a", repository: repo, settingsStore: store)
        viewModel.onAppear()
        viewModel.saveOffset(50)
        let router = Router(settingsStore: store, repository: repo)
        router.popReading()
        XCTAssertEqual(store.session?.onScreen, false)
        XCTAssertEqual(store.session?.offset ?? -1, 50, accuracy: 0.001)
        let relaunched = SettingsStore(userDefaults: ud)
        let router2 = Router(settingsStore: relaunched, repository: repo)
        router2.restoreInitialRoute()
        XCTAssertEqual(router2.path.count, 0)
    }

    /// (c) Background flush: the AppRoot scenePhase save persists the in-memory
    /// session so kill-after-background relaunches into the same position.
    func testBackgroundFlushPersistsSession() throws {
        let (store, ud) = try makeStore()
        store.session = ReadingSession(bookId: "seamless-a", onScreen: true, offset: 77.7, chapterNumber: 3)
        // Same call AppRoot performs on scenePhase background/inactive.
        store.save()
        let relaunched = SettingsStore(userDefaults: ud)
        XCTAssertEqual(relaunched.session?.bookId, "seamless-a")
        XCTAssertEqual(relaunched.session?.offset ?? -1, 77.7, accuracy: 0.001)
        XCTAssertEqual(relaunched.session?.chapterNumber, 3)
        XCTAssertEqual(relaunched.session?.onScreen, true)
    }

    func testAppRootFlushesStoreOnBackground() throws {
        let src = try source("apps/novels/App/AppRoot.swift")
        let code = stripped(src)
        XCTAssertTrue(code.contains("scenePhase"), "AppRoot must observe scenePhase")
        XCTAssertTrue(code.contains("settingsStore.save()"), "AppRoot must flush the store on background/inactive")
        XCTAssertTrue(code.contains(".background"), "AppRoot must handle the background phase")
    }

    /// (d) Offset 0 (chapter top) is a valid restore position for the same book.
    func testZeroOffsetRestores() {
        XCTAssertEqual(
            ReaderOffsetRestore.offsetToRestore(
                sessionBookId: "seamless-a",
                sessionOffset: 0,
                currentBookId: "seamless-a"
            ),
            0
        )
    }

    /// VM init keeps restoring chapterNumber from the session (unchanged principle).
    func testInitRestoresChapterNumber() throws {
        let (store, _) = try makeStore()
        store.session = ReadingSession(bookId: "seamless-a", onScreen: true, offset: 0, chapterNumber: 4)
        let viewModel = ReaderViewModel(bookId: "seamless-a", repository: makeRepo(), settingsStore: store)
        XCTAssertEqual(viewModel.chapterNumber, 4)
    }

    // MARK: - Source helpers (same pattern as ReaderHeaderSpinnerTests)

    private func repoRoot() -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        var current = fileURL.deletingLastPathComponent()
        for _ in 0 ..< 6 {
            let candidate = current.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return fileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        let root = repoRoot()
        let candidate = root.appendingPathComponent(relative)
        let path = FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : relative
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    private func stripped(_ text: String) -> String {
        var result = text
        if let regex = try? NSRegularExpression(
            pattern: "/\\*.*?\\*/",
            options: [.dotMatchesLineSeparators]
        ) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        let lines = result.components(separatedBy: "\n")
        let withoutLineComments = lines.map { line -> String in
            if let range = line.range(of: "//") {
                return String(line[..<range.lowerBound])
            }
            return line
        }
        return withoutLineComments.joined(separator: "\n")
    }
}
