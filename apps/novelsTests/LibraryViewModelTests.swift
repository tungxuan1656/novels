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
