@testable import novels
import XCTest

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func testEmptyReturnsEmpty() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo)
        viewModel.load()
        XCTAssertTrue(viewModel.books.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testListsOnlyValidBookJSON() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let valid = tmp.appendingPathComponent("valid-slug", isDirectory: true)
        try FileManager.default.createDirectory(
            at: valid.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"valid-slug","name":"Sách Hay","count":1,"author":"Tác giả A","references":["C1"]}"#
            .write(to: valid.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<p>c1</p>".write(
            to: valid.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("bad", isDirectory: true),
            withIntermediateDirectories: true
        )
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo)
        viewModel.load()
        XCTAssertEqual(viewModel.books.map(\.id), ["valid-slug"])
    }

    func testDeleteConfirmedEmitsLibraryDeleteDiagnosticsEvent() async throws {
        await DiagnosticsLog.shared.clear()
        defer { Task { await DiagnosticsLog.shared.clear() } }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("logged-book", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"logged-book","name":"Sách Log","count":0,"author":null,"references":[]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo)
        viewModel.load()
        try viewModel.confirmDelete(XCTUnwrap(viewModel.books.first))
        viewModel.deleteConfirmed()
        var entry: LogEntry?
        let deadline = Date().addingTimeInterval(2)
        while entry == nil, Date() < deadline {
            let entries = await DiagnosticsLog.shared.snapshot()
            entry = entries.first(where: { $0.event == "library.delete" })
            if entry == nil {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        let logged = try XCTUnwrap(entry)
        XCTAssertEqual(logged.kind, .event)
        XCTAssertEqual(logged.bookId, "logged-book")
        XCTAssertEqual(logged.detail, "success")
        try? FileManager.default.removeItem(at: tmp)
    }

    func testDeleteRemovesFolderAndRefreshes() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("to-delete", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"to-delete","name":"X","count":0,"author":null,"references":[]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo)
        viewModel.load()
        XCTAssertEqual(viewModel.books.count, 1)
        try repo.deleteBook(slug: "to-delete")
        viewModel.load()
        XCTAssertTrue(viewModel.books.isEmpty)
    }

    func testDeleteConfirmedRemovesFolderAndRefreshesList() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("gone-after-confirm", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"gone-after-confirm","name":"Sách Xóa","count":0,"author":null,"references":[]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let toast = ToastCenter()
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo, toastCenter: toast)
        viewModel.load()
        XCTAssertEqual(viewModel.books.count, 1)
        try viewModel.confirmDelete(XCTUnwrap(viewModel.books.first))
        XCTAssertNotNil(viewModel.showDeleteConfirm)
        viewModel.deleteConfirmed()
        XCTAssertNil(viewModel.showDeleteConfirm)
        XCTAssertTrue(viewModel.books.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(toast.lastMessage?.contains("Đã xóa") ?? false)
        try? FileManager.default.removeItem(at: tmp)
    }

    func testDeleteConfirmedMissingFolderSurfacesErrorWithoutFakeSuccess() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("already-gone", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"already-gone","name":"Sách Mất","count":0,"author":null,"references":[]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let toast = ToastCenter()
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo, toastCenter: toast)
        viewModel.load()
        let book = try XCTUnwrap(viewModel.books.first)
        // Folder disappears out from under the library (e.g., id/folder mismatch
        // in an older install, or external removal).
        try FileManager.default.removeItem(at: folder)
        viewModel.confirmDelete(book)
        XCTAssertNotNil(viewModel.showDeleteConfirm)
        viewModel.deleteConfirmed()
        // Failure must dismiss the dialog, refresh the list, and toast an error —
        // never a fake "Đã xóa" success.
        XCTAssertNil(viewModel.showDeleteConfirm)
        XCTAssertEqual(toast.lastMessage, "Không thể xóa sách")
        XCTAssertTrue(viewModel.books.isEmpty)
        try? FileManager.default.removeItem(at: tmp)
    }

    func testDeleteConfirmFlow() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("slug-a", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"slug-a","name":"Tên Sách","count":2,"author":"Tác giả","references":["Chương 1","Chương 2"]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<p>1</p>".write(
            to: folder.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try "<p>2</p>".write(
            to: folder.appendingPathComponent("chapters/chapter-2.html"),
            atomically: true,
            encoding: .utf8
        )
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo)
        viewModel.load()
        XCTAssertEqual(viewModel.books.first?.references.count, 2)
        try viewModel.confirmDelete(XCTUnwrap(viewModel.books.first))
        XCTAssertNotNil(viewModel.showDeleteConfirm)
        viewModel.deleteConfirmed()
        XCTAssertTrue(viewModel.books.isEmpty)
        viewModel.load()
        XCTAssertTrue(viewModel.books.isEmpty)
    }

    func testDeleteConfirmedWithMismatchedFolderNameStillDeletes() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("stale-folder-name", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("chapters", isDirectory: true),
            withIntermediateDirectories: true
        )
        try #"{"id":"real-book-id","name":"Sách Lệch","count":0,"author":null,"references":[]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let toast = ToastCenter()
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let viewModel = LibraryViewModel(repository: repo, toastCenter: toast)
        viewModel.load()
        XCTAssertEqual(viewModel.books.map(\.id), ["real-book-id"])
        try viewModel.confirmDelete(XCTUnwrap(viewModel.books.first))
        viewModel.deleteConfirmed()
        XCTAssertNil(viewModel.showDeleteConfirm)
        XCTAssertTrue(viewModel.books.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(toast.lastMessage?.contains("Đã xóa") ?? false)
        try? FileManager.default.removeItem(at: tmp)
    }

    func testInfoSheetBookFields() {
        let book = Book(
            id: "s",
            name: "Vạn Giới",
            author: "Tác giả X",
            count: 2,
            references: ["Chương 1", "Chương 2"]
        )
        XCTAssertEqual(book.name, "Vạn Giới")
        XCTAssertEqual(book.references.count, 2)
    }
}
