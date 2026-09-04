@testable import novels
import XCTest

// swiftlint:disable:next type_body_length
final class BookRepositoryTests: XCTestCase {
    // MARK: - Helpers

    private func makeTempRoot() -> URL {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func createValidBook(
        at folderURL: URL,
        id: String = "valid-slug",
        count: Int = 1,
        references: [String]? = nil
    ) throws {
        let refs = references ?? (1 ... count).map { "Ch \($0)" }
        let bookJSON = """
        {"id":"\(id)","name":"V","count":\(count),"author":null,"references":\(jsonArray(refs))}
        """
        let chaptersDir = folderURL.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        try bookJSON.write(to: folderURL.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        for number in 1 ... count {
            let html = "<html>c\(number)</html>"
            try html.write(
                to: chaptersDir.appendingPathComponent("chapter-\(number).html"),
                atomically: true,
                encoding: .utf8
            )
        }
        // Handle count == 0: no chapters needed, but we already created dir above.
        if count == 0 {
            // Ensure no chapter files remain
            let existing = try? FileManager.default.contentsOfDirectory(
                at: chaptersDir,
                includingPropertiesForKeys: nil
            )
            for url in existing ?? [] {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func jsonArray(_ values: [String]) -> String {
        let escaped = values.map { "\"\($0)\"" }.joined(separator: ",")
        return "[\(escaped)]"
    }

    // MARK: - listBooks

    func testListSkipsInvalidFolder() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        try fm.createDirectory(
            at: booksRoot.appendingPathComponent("valid-slug/chapters"),
            withIntermediateDirectories: true
        )
        try #"{"id":"valid-slug","name":"V","count":1,"author":null,"references":["C1"]}"#
            .write(to: booksRoot.appendingPathComponent("valid-slug/book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: booksRoot.appendingPathComponent("valid-slug/chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try fm.createDirectory(at: booksRoot.appendingPathComponent("bad/chapters"), withIntermediateDirectories: true)
        // bad has no book.json
        try "<html>bad</html>".write(
            to: booksRoot.appendingPathComponent("bad/chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        let ids = try repo.listBooks().map(\.id)
        XCTAssertEqual(ids, ["valid-slug"])
        try fm.removeItem(at: tmp)
    }

    func testListSkipsMismatchedCount() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        // valid
        let valid = booksRoot.appendingPathComponent("valid-slug", isDirectory: true)
        try fm.createDirectory(at: valid.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: valid, id: "valid-slug", count: 1)
        // invalid: count 2 but only 1 reference
        let bad = booksRoot.appendingPathComponent("bad-slug", isDirectory: true)
        try fm.createDirectory(at: bad.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try #"{"id":"bad-slug","name":"B","count":2,"references":["OnlyOne"]}"#
            .write(to: bad.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: bad.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try "<html>c2</html>".write(
            to: bad.appendingPathComponent("chapters/chapter-2.html"),
            atomically: true,
            encoding: .utf8
        )
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertEqual(try repo.listBooks().map(\.id), ["valid-slug"])
        try fm.removeItem(at: tmp)
    }

    func testListSkipsMissingChapterFile() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        let folder = booksRoot.appendingPathComponent("incomplete", isDirectory: true)
        try fm.createDirectory(at: folder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try #"{"id":"incomplete","name":"I","count":2,"references":["C1","C2"]}"#
            .write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: folder.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        // chapter-2.html missing
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertTrue(try repo.listBooks().isEmpty)
        try fm.removeItem(at: tmp)
    }

    func testBookReturnsNilForInvalid() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        try fm.createDirectory(at: booksRoot, withIntermediateDirectories: true)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertNil(try repo.book(slug: "missing"))
        // create invalid folder (no book.json)
        try fm.createDirectory(
            at: booksRoot.appendingPathComponent("empty/chapters"),
            withIntermediateDirectories: true
        )
        XCTAssertNil(try repo.book(slug: "empty"))
        try fm.removeItem(at: tmp)
    }

    // MARK: - ZipValidator

    func testValidatorRejectsWrapper() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        try fm.createDirectory(at: tmp.appendingPathComponent("outer/chapters"), withIntermediateDirectories: true)
        // outer has chapter but no book.json -> both should be false
        try "<html>c1</html>".write(
            to: tmp.appendingPathComponent("outer/chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp.appendingPathComponent("outer")))
        // Now give outer a valid layout -> outer valid, tmp still invalid
        try fm.removeItem(at: tmp.appendingPathComponent("outer/chapters/chapter-1.html"))
        let outer = tmp.appendingPathComponent("outer")
        try createValidBook(at: outer, id: "outer-book", count: 1)
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        XCTAssertTrue(ZipValidator.isValidRoot(at: outer))
        try fm.removeItem(at: tmp)
    }

    func testValidatorChecksExactRoot() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        try fm.createDirectory(at: tmp.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try #"{"id":"s","name":"N","count":1,"references":["C1"]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        // missing chapter -> false
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        try "<html>c1</html>".write(
            to: tmp.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
        // count mismatch -> false
        try #"{"id":"s","name":"N","count":2,"references":["C1"]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        try fm.removeItem(at: tmp)
    }

    func testValidatorRejectsMacOSXAlongsideValid() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        try fm.createDirectory(at: tmp.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try #"{"id":"s","name":"N","count":1,"references":["C1"]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: tmp.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        // Initially valid
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
        // Add __MACOSX alongside valid files -> now tolerant (ignored)
        try fm.createDirectory(at: tmp.appendingPathComponent("__MACOSX"), withIntermediateDirectories: true)
        try "junk".write(to: tmp.appendingPathComponent("__MACOSX/._book.json"), atomically: true, encoding: .utf8)
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
        try fm.removeItem(at: tmp)
    }

    func testValidatorToleratesDSStoreAndMacOSX() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        try #"{"id":"s","name":"N","count":1,"references":["C1"]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let ch = tmp.appendingPathComponent("chapters")
        try fm.createDirectory(at: ch, withIntermediateDirectories: true)
        try "<p>hi</p>".write(to: ch.appendingPathComponent("chapter-1.html"), atomically: true, encoding: .utf8)
        fm.createFile(atPath: tmp.appendingPathComponent(".DS_Store").path, contents: Data())
        let mac = tmp.appendingPathComponent("__MACOSX")
        try fm.createDirectory(at: mac, withIntermediateDirectories: true)
        fm.createFile(atPath: mac.appendingPathComponent("._book.json").path, contents: Data(repeating: 0, count: 163))
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
        // Also hygiene inside chapters should be ignored
        fm.createFile(atPath: ch.appendingPathComponent(".DS_Store").path, contents: Data())
        fm.createFile(
            atPath: ch.appendingPathComponent("._chapter-1.html").path,
            contents: Data(repeating: 0, count: 10)
        )
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
        // Real extra still fails
        try "extra".write(to: tmp.appendingPathComponent("extra.txt"), atomically: true, encoding: .utf8)
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        try fm.removeItem(at: tmp.appendingPathComponent("extra.txt"))
        // Hygiene ._* at root ignored, still valid
        fm.createFile(atPath: tmp.appendingPathComponent("._DS_Store").path, contents: Data())
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
    }

    func testValidatorStillRejectsMissingChapter() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        try fm.createDirectory(at: tmp.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try #"{"id":"s","name":"N","count":2,"references":["C1","C2"]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: tmp.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        // chapter-2 missing -> false even with hygiene present
        fm.createFile(atPath: tmp.appendingPathComponent(".DS_Store").path, contents: Data())
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        try fm.removeItem(at: tmp)
    }

    func testValidatorStillRejectsRealExtraInsideChapters() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        try fm.createDirectory(at: tmp.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try #"{"id":"s","name":"N","count":1,"references":["C1"]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: tmp.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertTrue(ZipValidator.isValidRoot(at: tmp))
        // real extra inside chapters should fail
        try "extra".write(
            to: tmp.appendingPathComponent("chapters/extra.txt"),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
        try fm.removeItem(at: tmp)
    }

    // MARK: - chapterHTML

    func testChapterHTMLValidation() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        let slugFolder = booksRoot.appendingPathComponent("valid-slug", isDirectory: true)
        try fm.createDirectory(at: slugFolder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: slugFolder, id: "valid-slug", count: 2)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertEqual(try repo.chapterHTML(slug: "valid-slug", number: 1), "<html>c1</html>")
        XCTAssertEqual(try repo.chapterHTML(slug: "valid-slug", number: 2), "<html>c2</html>")
        XCTAssertThrowsError(try repo.chapterHTML(slug: "valid-slug", number: 0))
        XCTAssertThrowsError(try repo.chapterHTML(slug: "valid-slug", number: 3))
        var threwOutOfRange = false
        do {
            _ = try repo.chapterHTML(slug: "valid-slug", number: 3)
        } catch let error as BookRepositoryError {
            threwOutOfRange = (error == .invalidChapterNumber(number: 3, count: 2))
        }
        XCTAssertTrue(threwOutOfRange)
        try fm.removeItem(at: tmp)
    }

    func testChapterHTMLMissingBookThrows() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        try fm.createDirectory(at: booksRoot, withIntermediateDirectories: true)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertThrowsError(try repo.chapterHTML(slug: "nope", number: 1))
        try fm.removeItem(at: tmp)
    }

    // MARK: - delete

    func testDeleteRemovesOnlySlug() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        for slug in ["a", "b"] {
            let folder = booksRoot.appendingPathComponent(slug, isDirectory: true)
            try fm.createDirectory(at: folder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
            try createValidBook(at: folder, id: slug, count: 1)
        }
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertEqual(try repo.listBooks().count, 2)
        try repo.deleteBook(slug: "a")
        XCTAssertEqual(try repo.listBooks().map(\.id), ["b"])
        XCTAssertTrue(fm.fileExists(atPath: booksRoot.appendingPathComponent("b").path))
        // delete non-existing surfaces an error instead of a silent no-op,
        // so the UI never shows a fake success toast
        XCTAssertThrowsError(try repo.deleteBook(slug: "nonexistent")) { error in
            XCTAssertEqual(error as? BookRepositoryError, .bookNotFound(slug: "nonexistent"))
        }
        XCTAssertEqual(try repo.listBooks().map(\.id), ["b"])
        try fm.removeItem(at: tmp)
    }

    func testDeleteThrowsForInvalidSlug() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        try fm.createDirectory(at: booksRoot, withIntermediateDirectories: true)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertThrowsError(try repo.deleteBook(slug: "../escape")) { error in
            XCTAssertEqual(error as? BookRepositoryError, .invalidSlug(slug: "../escape"))
        }
        try fm.removeItem(at: tmp)
    }

    func testDeleteResolvesFolderWhenBookIdDiffersFromFolderName() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        // Folder name does not match book.json id (id drift / slugify fallback):
        // listBooks surfaces book.id, delete must still remove the real folder.
        let folder = booksRoot.appendingPathComponent("stale-folder-name", isDirectory: true)
        try fm.createDirectory(at: folder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: folder, id: "real-book-id", count: 1)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertEqual(try repo.listBooks().map(\.id), ["real-book-id"])
        try repo.deleteBook(slug: "real-book-id")
        XCTAssertFalse(fm.fileExists(atPath: folder.path))
        XCTAssertTrue(try repo.listBooks().isEmpty)
        try fm.removeItem(at: tmp)
    }

    func testDeleteMatchesSlugCaseInsensitively() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        let folder = booksRoot.appendingPathComponent("My-Book", isDirectory: true)
        try fm.createDirectory(at: folder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: folder, id: "my-book", count: 1)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        try repo.deleteBook(slug: "my-book")
        XCTAssertFalse(fm.fileExists(atPath: folder.path))
        try fm.removeItem(at: tmp)
    }

    func testBookAndChapterResolveDriftedFolder() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        // Folder name drifted from book.json id: read must resolve via book.id scan, not just exact path.
        let folder = booksRoot.appendingPathComponent("stale-folder-name", isDirectory: true)
        try fm.createDirectory(at: folder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: folder, id: "real-book-id", count: 1)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertEqual(try repo.book(slug: "real-book-id")?.id, "real-book-id")
        XCTAssertEqual(try repo.chapterHTML(slug: "real-book-id", number: 1), "<html>c1</html>")
        try fm.removeItem(at: tmp)
    }

    func testBookReadsBOMBookJSON() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        let folder = booksRoot.appendingPathComponent("bom-book", isDirectory: true)
        try fm.createDirectory(at: folder.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        let json = #"{"id":"bom-book","name":"B","count":1,"references":["C1"]}"#
        var bomData = Data([0xEF, 0xBB, 0xBF])
        bomData.append(Data(json.utf8))
        try bomData.write(to: folder.appendingPathComponent("book.json"))
        try "<html>c1</html>".write(
            to: folder.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertEqual(try repo.listBooks().map(\.id), ["bom-book"])
        XCTAssertEqual(try repo.book(slug: "bom-book")?.id, "bom-book")
        XCTAssertEqual(try repo.chapterHTML(slug: "bom-book", number: 1), "<html>c1</html>")
        try fm.removeItem(at: tmp)
    }

    // MARK: - save

    func testSaveAtomic() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        let validatedRoot = tmp.appendingPathComponent("validated", isDirectory: true)
        try fm.createDirectory(at: validatedRoot.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: validatedRoot, id: "my-slug", count: 2)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        try repo.save(validatedRoot: validatedRoot, slug: "my-slug")
        XCTAssertEqual(try repo.listBooks().map(\.id), ["my-slug"])
        XCTAssertEqual(try repo.chapterHTML(slug: "my-slug", number: 1), "<html>c1</html>")
        // overwrite atomically
        let validated2 = tmp.appendingPathComponent("validated2", isDirectory: true)
        try fm.createDirectory(at: validated2.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: validated2, id: "my-slug", count: 1)
        try "<html>new</html>".write(
            to: validated2.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try repo.save(validatedRoot: validated2, slug: "my-slug")
        XCTAssertEqual(try repo.book(slug: "my-slug")?.count, 1)
        XCTAssertEqual(try repo.chapterHTML(slug: "my-slug", number: 1), "<html>new</html>")
        XCTAssertEqual(try repo.listBooks().count, 1)
        try fm.removeItem(at: tmp)
    }

    func testSaveCreatesRootIfMissing() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        let validatedRoot = tmp.appendingPathComponent("validated", isDirectory: true)
        try fm.createDirectory(at: validatedRoot.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        try createValidBook(at: validatedRoot, id: "new-slug", count: 1)
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        XCTAssertFalse(fm.fileExists(atPath: booksRoot.path))
        try repo.save(validatedRoot: validatedRoot, slug: "new-slug")
        XCTAssertTrue(fm.fileExists(atPath: booksRoot.appendingPathComponent("new-slug/book.json").path))
        try fm.removeItem(at: tmp)
    }

    func testListDedupesDuplicateBookIdsFirstWins() throws {
        let fm = FileManager.default
        let tmp = makeTempRoot()
        let booksRoot = tmp.appendingPathComponent("books", isDirectory: true)
        // Two folders decode to the same book.id (id drift): list must return
        // one row so List(books, id: \.id) never diffs duplicate ids.
        for folder in ["aaa-folder", "zzz-folder"] {
            let folderURL = booksRoot.appendingPathComponent(folder, isDirectory: true)
            try fm.createDirectory(at: folderURL.appendingPathComponent("chapters"), withIntermediateDirectories: true)
            try createValidBook(at: folderURL, id: "dupe-id", count: 1)
        }
        let repo = FileBookRepository(root: booksRoot, fileManager: fm)
        let books = try repo.listBooks()
        XCTAssertEqual(books.map(\.id), ["dupe-id"])
        try fm.removeItem(at: tmp)
    }

    // MARK: - AppPaths

    func testAppPathsBooksRootUsesFileManager() {
        let fm = FileManager.default
        let url = AppPaths.booksRoot(fileManager: fm)
        XCTAssertTrue(url.path.hasSuffix("novels/books"))
        let cache = AppPaths.cacheRoot(fileManager: fm)
        XCTAssertTrue(cache.path.hasSuffix("novels/cache"))
    }

    func testAppPathsBaseOverload() {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertTrue(AppPaths.booksRoot(baseURL: base).path.hasSuffix("novels/books"))
        XCTAssertTrue(AppPaths.cacheRoot(baseURL: base).path.hasSuffix("novels/cache"))
    }
}
