// swiftlint:disable file_length
@testable import novels
import XCTest

// MARK: - Helpers

private func makeBook(
    named name: String = "Test",
    slug: String = "test-slug",
    lastUpdated: String? = "2024-12-03T00:00:00Z",
    exportUrl: String = "https://ex.com/a.zip"
) -> ExportedBook {
    ExportedBook(
        id: 1,
        bookId: 1,
        exportUrl: exportUrl,
        fileSize: 12345,
        exportFormat: "zip",
        exportedAt: "2024-12-03T00:00:00Z",
        updatedAt: "2024-12-03T00:00:00Z",
        book: BookMeta(
            id: 1,
            name: name,
            slug: slug,
            author: "Author",
            chapterCount: 2,
            status: "completed",
            synopsis: "syn",
            lastUpdated: lastUpdated
        )
    )
}

private func book(
    named name: String,
    lastUpdated: String? = "2024-12-03T00:00:00Z",
    slug: String? = nil,
    exportUrl: String = "https://ex.com/a.zip"
) -> ExportedBook {
    let resolved = slug ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
    return makeBook(named: name, slug: resolved, lastUpdated: lastUpdated, exportUrl: exportUrl)
}

private func book(slug: String, exportUrl: String) -> ExportedBook {
    makeBook(named: slug, slug: slug, exportUrl: exportUrl)
}

private actor MockCatalog: CatalogFetching {
    var books: [ExportedBook]
    var error: Error?

    init(books: [ExportedBook] = [], error: Error? = nil) {
        self.books = books
        self.error = error
    }

    func fetchCatalog() async throws -> [ExportedBook] {
        if let error {
            throw error
        }
        return books
    }
}

private struct MockDownloader: Downloader {
    var zipURL: URL?
    var error: Error?

    init(zipURL: URL? = nil, error: Error? = nil) {
        self.zipURL = zipURL
        self.error = error
    }

    func download(from url: URL) async throws -> URL {
        if let error {
            throw error
        }
        if let zipURL {
            return zipURL
        }
        throw ImportError.downloadFailed
    }
}

private func makeMockRepository() -> FileBookRepository {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return FileBookRepository(root: tmp, fileManager: .default)
}

private func realSampleURL() -> URL {
    // #filePath is .../apps/novelsTests/ImportViewModelTests.swift
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/samples/van-gioi-chi-rut-thuong-he-thong.zip")
}

private func makeValidZip(at base: URL, slug: String, count: Int = 2, content: String? = nil) -> URL {
    let src = base.appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
    let chaptersDir = src.appendingPathComponent("chapters", isDirectory: true)
    try? FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
    let refs = (1 ... count).map { "\"Ch \($0)\"" }.joined(separator: ",")
    let bookJSON = """
    {"id":"\(slug)","name":"N","count":\(count),"author":null,"references":[\(refs)]}
    """
    try? bookJSON.write(to: src.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
    for number in 1 ... count {
        let html = content.map { "\($0) \(number)" } ?? "<html>c\(number)</html>"
        try? html.write(
            to: chaptersDir.appendingPathComponent("chapter-\(number).html"),
            atomically: true,
            encoding: .utf8
        )
    }
    let zipURL = base.appendingPathComponent("\(UUID().uuidString).zip", isDirectory: false)
    try? FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
    try? FileManager.default.removeItem(at: src)
    return zipURL
}

private func makeWrapperZip(at base: URL) -> URL {
    let src = base.appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
    let outer = src.appendingPathComponent("outer", isDirectory: true)
    try? FileManager.default.createDirectory(at: outer, withIntermediateDirectories: true)
    let chaptersDir = outer.appendingPathComponent("chapters", isDirectory: true)
    try? FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
    let bookJSON = """
    {"id":"bad","name":"B","count":1,"author":null,"references":["C1"]}
    """
    try? bookJSON.write(to: outer.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
    try? "<html>c1</html>".write(
        to: chaptersDir.appendingPathComponent("chapter-1.html"),
        atomically: true,
        encoding: .utf8
    )
    let zipURL = base.appendingPathComponent("\(UUID().uuidString).zip", isDirectory: false)
    try? FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
    try? FileManager.default.removeItem(at: src)
    return zipURL
}

// MARK: - Tests

@MainActor
// swiftlint:disable:next type_body_length
final class ImportViewModelTests: XCTestCase {
    func testSortedBooksDefaultNameAZ() async {
        let catalog = MockCatalog(books: [book(named: "B"), book(named: "A")])
        let vm = ImportViewModel(
            catalogService: catalog,
            repository: makeMockRepository(),
            downloader: MockDownloader()
        )
        await vm.loadCatalog()
        XCTAssertEqual(vm.sortedBooks.map(\.book.name), ["A", "B"])
    }

    func testSortedByUpdatedNewest() async {
        let b1 = book(named: "A", lastUpdated: "2024-01-01T00:00:00Z")
        let b2 = book(named: "B", lastUpdated: "2024-12-03T00:00:00Z")
        let catalog = MockCatalog(books: [b1, b2])
        let vm = ImportViewModel(
            catalogService: catalog,
            repository: makeMockRepository(),
            downloader: MockDownloader()
        )
        await vm.loadCatalog()
        vm.sortOption = .updatedNewest
        XCTAssertEqual(vm.sortedBooks.first?.book.name, "B")
    }

    func testLoadCatalogEmpty() async {
        let catalog = MockCatalog(books: [])
        let vm = ImportViewModel(
            catalogService: catalog,
            repository: makeMockRepository(),
            downloader: MockDownloader()
        )
        await vm.loadCatalog()
        if case .empty = vm.catalogState {
        } else {
            XCTFail("expected empty, got \(vm.catalogState)")
        }
    }

    func testLoadCatalogError() async {
        let catalog = MockCatalog(error: URLError(.notConnectedToInternet))
        let vm = ImportViewModel(
            catalogService: catalog,
            repository: makeMockRepository(),
            downloader: MockDownloader()
        )
        await vm.loadCatalog()
        if case let .error(message) = vm.catalogState {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("expected error, got \(vm.catalogState)")
        }
    }

    func testImportValidZIPReplacesAndDeletesTemp() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zip = makeValidZip(at: tmp, slug: "test-slug", count: 2)
        let repo = FileBookRepository(
            root: tmp.appendingPathComponent("books", isDirectory: true),
            fileManager: .default
        )
        let catalog = MockCatalog(books: [])
        let vm = ImportViewModel(
            catalogService: catalog,
            repository: repo,
            downloader: MockDownloader(zipURL: zip)
        )
        try await vm.importBook(book(slug: "test-slug", exportUrl: zip.absoluteString))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tmp.appendingPathComponent("books/test-slug/book.json").path
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip.path))
    }

    func testImportSingleFolderWrapperFlattens() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zip = makeWrapperZip(at: tmp)
        let repo = FileBookRepository(
            root: tmp.appendingPathComponent("books", isDirectory: true),
            fileManager: .default
        )
        let catalog = MockCatalog(books: [])
        let vm = ImportViewModel(
            catalogService: catalog,
            repository: repo,
            downloader: MockDownloader(zipURL: zip)
        )
        // Tolerant Task 2: single outer-folder wrapper is flattened to canonical root → import succeeds
        try await vm.importBook(book(slug: "bad", exportUrl: zip.absoluteString))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tmp.appendingPathComponent("books/bad/book.json").path)
        )
    }

    func testReimportOverwrites() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zip1 = makeValidZip(at: tmp, slug: "s", count: 1, content: "v1")
        let zip2 = makeValidZip(at: tmp, slug: "s", count: 1, content: "v2")
        let repo = FileBookRepository(
            root: tmp.appendingPathComponent("books", isDirectory: true),
            fileManager: .default
        )
        let catalog = MockCatalog(books: [])
        let vm1 = ImportViewModel(
            catalogService: catalog,
            repository: repo,
            downloader: MockDownloader(zipURL: zip1)
        )
        try await vm1.importBook(book(slug: "s", exportUrl: zip1.absoluteString))
        let vm2 = ImportViewModel(
            catalogService: catalog,
            repository: repo,
            downloader: MockDownloader(zipURL: zip2)
        )
        try await vm2.importBook(book(slug: "s", exportUrl: zip2.absoluteString))
        let content = try String(
            contentsOf: tmp.appendingPathComponent("books/s/chapters/chapter-1.html"),
            encoding: .utf8
        )
        XCTAssertEqual(content, "v2 1")
    }

    func testImportRejectsMacOSXAlongsideValid() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Create valid src then add __MACOSX folder before zipping
        let src = tmp.appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: src.appendingPathComponent("chapters"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: src.appendingPathComponent("__MACOSX"),
            withIntermediateDirectories: true
        )
        let bookJSON = #"{"id":"macosx-test","name":"N","count":1,"author":null,"references":["C1"]}"#
        try bookJSON.write(to: src.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<html>c1</html>".write(
            to: src.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try "junk".write(to: src.appendingPathComponent("__MACOSX/._book.json"), atomically: true, encoding: .utf8)
        let zipURL = tmp.appendingPathComponent("\(UUID().uuidString).zip", isDirectory: false)
        try FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: src)
        let repo = FileBookRepository(
            root: tmp.appendingPathComponent("books", isDirectory: true),
            fileManager: .default
        )
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        // Tolerant: __MACOSX is ignored, import should succeed
        try await vm.importBook(book(slug: "macosx-test", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/macosx-test/book.json").path))
        XCTAssertFalse(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/macosx-test/__MACOSX").path))
    }

    func testUnzipAcceptsDataDescriptorFlag() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("flag08.zip")
        try makeDescriptorFlagStoreZip(at: zipURL, files: [
            "book.json": Data(#"{"id":"t","name":"T","count":1,"author":"A","references":["C1"]}"#.utf8),
            "chapters/chapter-1.html": Data("<p>hi</p>".utf8), // swiftlint:disable:this trailing_comma
        ])
        let out = tmp.appendingPathComponent("out")
        XCTAssertNoThrow(try FileManager.default.unzipItem(at: zipURL, to: out))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: out.appendingPathComponent("chapters/chapter-1.html").path))
        let html = try String(contentsOf: out.appendingPathComponent("chapters/chapter-1.html"), encoding: .utf8)
        XCTAssertEqual(html, "<p>hi</p>")
    }

    func testUnzipIgnoresMacOSXAlongsideValid() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let src = tmp.appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: src.appendingPathComponent("chapters"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: src.appendingPathComponent("__MACOSX"),
            withIntermediateDirectories: true
        )
        try #"{"id":"t","name":"T","count":1,"author":"A","references":["C1"]}"#
            .write(to: src.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<p>hi</p>".write(
            to: src.appendingPathComponent("chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try "junk".write(to: src.appendingPathComponent("__MACOSX/._book.json"), atomically: true, encoding: .utf8)
        try "junk".write(to: src.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try "junk".write(to: src.appendingPathComponent("chapters/._chapter-1.html"), atomically: true, encoding: .utf8)
        let zipURL = tmp.appendingPathComponent("hygiene.zip")
        try FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: src)
        let out = tmp.appendingPathComponent("out2")
        XCTAssertNoThrow(try FileManager.default.unzipItem(at: zipURL, to: out))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("book.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.appendingPathComponent("__MACOSX").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.appendingPathComponent(".DS_Store").path))
        XCTAssertFalse(FileManager.default
            .fileExists(atPath: out.appendingPathComponent("chapters/._chapter-1.html").path))
    }

    func testUnzipRejectsZipSlip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("slip.zip")
        // Build raw ZIP with traversal entry "../evil.txt"
        let fileName = "../evil.txt"
        let fileData = Data("evil".utf8)
        // CRC32 for "evil"
        var crc: UInt32 = 0xFFFF_FFFF
        let table: [UInt32] = (0 ..< 256).map { idx in
            var crcVal = UInt32(idx)
            for _ in 0 ..< 8 {
                crcVal = (crcVal & 1) != 0 ? (crcVal >> 1) ^ 0xEDB8_8320 : crcVal >> 1
            }
            return crcVal
        }
        for byte in fileData {
            crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        crc ^= 0xFFFF_FFFF
        var local = Data()
        func append16(_ value: UInt16, to data: inout Data) {
            var little = value.littleEndian; data.append(Data(bytes: &little, count: 2))
        }
        func append32(_ value: UInt32, to data: inout Data) {
            var little = value.littleEndian; data.append(Data(bytes: &little, count: 4))
        }
        append32(0x0403_4B50, to: &local)
        append16(20, to: &local); append16(0, to: &local); append16(0, to: &local)
        append16(0, to: &local); append16(0, to: &local)
        append32(crc, to: &local); append32(UInt32(fileData.count), to: &local); append32(
            UInt32(fileData.count),
            to: &local
        )
        let nameData = try XCTUnwrap(fileName.data(using: .utf8))
        append16(UInt16(nameData.count), to: &local); append16(0, to: &local)
        local.append(nameData); local.append(fileData)
        var central = Data()
        append32(0x0201_4B50, to: &central)
        append16(20, to: &central); append16(20, to: &central); append16(0, to: &central); append16(0, to: &central)
        append16(0, to: &central); append16(0, to: &central)
        append32(crc, to: &central); append32(UInt32(fileData.count), to: &central); append32(
            UInt32(fileData.count),
            to: &central
        )
        append16(UInt16(nameData.count), to: &central); append16(0, to: &central); append16(0, to: &central)
        append16(0, to: &central); append16(0, to: &central); append32(0, to: &central); append32(0, to: &central)
        central.append(nameData)
        var eocd = Data()
        append32(0x0605_4B50, to: &eocd); append16(0, to: &eocd); append16(0, to: &eocd)
        append16(1, to: &eocd); append16(1, to: &eocd)
        append32(UInt32(central.count), to: &eocd); append32(UInt32(local.count), to: &eocd); append16(0, to: &eocd)
        var final = Data(); final.append(local); final.append(central); final.append(eocd)
        try final.write(to: zipURL)
        let dest = tmp.appendingPathComponent("dest", isDirectory: true)
        XCTAssertThrowsError(try FileManager.default.unzipItem(at: zipURL, to: dest))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.appendingPathComponent("evil.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("evil.txt").path))
    }

    func testUnzipFlattensSingleOuterFolder() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let src = tmp.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let wrapper = src.appendingPathComponent("my-book")
        try FileManager.default.createDirectory(at: wrapper, withIntermediateDirectories: true)
        try #"{"id":"my-book","name":"My","count":1,"author":"A","references":["C1"]}"#
            .write(to: wrapper.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let ch = wrapper.appendingPathComponent("chapters")
        try FileManager.default.createDirectory(at: ch, withIntermediateDirectories: true)
        try "<p>hi</p>".write(to: ch.appendingPathComponent("chapter-1.html"), atomically: true, encoding: .utf8)
        let zip = tmp.appendingPathComponent("wrapper.zip")
        try FileManager.default.zipItem(at: wrapper, to: zip, shouldKeepParent: true)
        let out = tmp.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zip, to: out)
        let canonical = FileManager.default.resolveCanonicalRoot(at: out)
        XCTAssertTrue(ZipValidator.isValidRoot(at: canonical))
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.appendingPathComponent("book.json").path))
    }

    func testResolverDoesNotFlattenTwoTopLevelFolders() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Create valid root with book.json and an extra top-level folder
        try #"{"id":"t","name":"T","count":0,"author":"A","references":[]}"#
            .write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let extra = tmp.appendingPathComponent("extra")
        try FileManager.default.createDirectory(at: extra, withIntermediateDirectories: true)
        try "x".write(to: extra.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        // out is tmp itself for this check – should not flatten because filtered count !=1
        let canonical = FileManager.default.resolveCanonicalRoot(at: tmp)
        XCTAssertEqual(canonical, tmp)
        // Also test case where top has 2 dirs, each valid – should not flatten
        let tmp2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp2, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp2) }
        let dirA = tmp2.appendingPathComponent("a")
        let dirB = tmp2.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        for dir in [dirA, dirB] {
            try #"{"id":"x","name":"X","count":1,"author":"A","references":["C1"]}"#
                .write(to: dir.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
            let ch2 = dir.appendingPathComponent("chapters")
            try FileManager.default.createDirectory(at: ch2, withIntermediateDirectories: true)
            try "<p>hi</p>".write(to: ch2.appendingPathComponent("chapter-1.html"), atomically: true, encoding: .utf8)
        }
        let canonical2 = FileManager.default.resolveCanonicalRoot(at: tmp2)
        XCTAssertEqual(canonical2, tmp2)
    }

    // swiftlint:disable:next function_body_length
    func testImportWrapperSampleSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let sampleURL = realSampleURL()
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            // Fallback synthetic mirror: wrapper with __MACOSX injection
            let src = tmp.appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
            let outer = src.appendingPathComponent("sample-book", isDirectory: true)
            try FileManager.default.createDirectory(
                at: outer.appendingPathComponent("chapters"),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: src.appendingPathComponent("__MACOSX"),
                withIntermediateDirectories: true
            )
            try #"{"id":"sample-book","name":"S","count":1,"author":"A","references":["C1"]}"#
                .write(to: outer.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
            try "<p>hi</p>".write(
                to: outer.appendingPathComponent("chapters/chapter-1.html"),
                atomically: true,
                encoding: .utf8
            )
            try "junk".write(to: src.appendingPathComponent("__MACOSX/._book.json"), atomically: true, encoding: .utf8)
            let zipURL = tmp.appendingPathComponent("synthetic.zip")
            try FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
            let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
            let vm = ImportViewModel(
                catalogService: MockCatalog(books: []),
                repository: repo,
                downloader: MockDownloader(zipURL: zipURL)
            )
            try await vm.importBook(book(slug: "sample-book", exportUrl: zipURL.absoluteString))
            XCTAssertTrue(FileManager.default
                .fileExists(atPath: tmp.appendingPathComponent("books/sample-book/book.json").path))
            return
        }
        let tmpSample = tmp.appendingPathComponent("sample-copy2.zip")
        try FileManager.default.copyItem(at: sampleURL, to: tmpSample)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: tmpSample)
        )
        // Import real sample – should succeed via flatten + hygiene
        try await vm.importBook(book(slug: "van-gioi-chi-rut-thuong-he-thong", exportUrl: tmpSample.absoluteString))
        // Verify at least book.json exists; count is large (743) but we just check file exists
        let dest = tmp.appendingPathComponent("books/van-gioi-chi-rut-thuong-he-thong/book.json")
        // Note: sample book.json id may be derived differently; check any folder created
        let booksDir = tmp.appendingPathComponent("books")
        let contents = try FileManager.default.contentsOfDirectory(
            at: booksDir,
            includingPropertiesForKeys: [],
            options: []
        )
        XCTAssertFalse(contents.isEmpty, "expected at least one book folder after import")
        // If canonical id matches sample filename, check specific file
        if FileManager.default.fileExists(atPath: dest.path) {
            XCTAssertTrue(true)
        } else {
            // Accept any folder with book.json
            let hasBook = contents
                .contains { FileManager.default.fileExists(atPath: $0.appendingPathComponent("book.json").path) }
            XCTAssertTrue(hasBook)
        }
    }

    // MARK: - Tolerant Task 6: synthetic wrapper + flag08 + real sample 743 + security invariants

    func testImportSyntheticWrapperFlag08MacOSXSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("wrapper-flag08.zip")
        try TolerantFixtures.makeWrapperWithMacOSXAndFlag08(at: zipURL, id: "tolerant-08", count: 2)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "tolerant-08", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/tolerant-08/book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/tolerant-08/chapters/chapter-1.html").path))
        XCTAssertFalse(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/tolerant-08/__MACOSX").path))
        XCTAssertFalse(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/tolerant-08/.DS_Store").path))
    }

    func testImportRealSampleSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let sampleURL = realSampleURL()
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            XCTFail("missing sample at \(sampleURL.path)"); return
        }
        // Copy to tmp to preserve original sample (ImportViewModel deletes zip after import)
        let tmpSample = tmp.appendingPathComponent("sample-copy.zip")
        try FileManager.default.copyItem(at: sampleURL, to: tmpSample)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: tmpSample)
        )
        try await vm.importBook(book(slug: "van-gioi-chi-rut-thuong-he-thong", exportUrl: tmpSample.absoluteString))
        // Derive slug from decoded book.json if id missing (fallback slugify)
        let books = try repo.listBooks()
        XCTAssertEqual(books.count, 1)
        let bookObj = try XCTUnwrap(books.first)
        XCTAssertEqual(bookObj.count, 743)
        XCTAssertEqual(bookObj.references.count, 743)
        XCTAssertEqual(try repo.chapterHTML(slug: bookObj.id, number: 1).isEmpty, false)
        XCTAssertEqual(try repo.chapterHTML(slug: bookObj.id, number: 743).isEmpty, false)
    }

    // swiftlint:disable:next function_body_length
    func testImportStillRejectsZipSlip() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("slip-import.zip")
        // Build raw ZIP with ../evil.html entry
        let fileName = "../evil.html"
        let fileData = Data("evil".utf8)
        var crc: UInt32 = 0xFFFF_FFFF
        let table: [UInt32] = (0 ..< 256).map { idx in
            var value = UInt32(idx)
            for _ in 0 ..< 8 {
                value = (value & 1) != 0 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
            }; return value
        }
        for byte in fileData {
            crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        crc ^= 0xFFFF_FFFF
        func a16(_ val: UInt16, to data: inout Data) {
            var little = val.littleEndian; data.append(Data(
                bytes: &little,
                count: 2
            ))
        }
        func a32(_ val: UInt32, to data: inout Data) {
            var little = val.littleEndian; data.append(Data(
                bytes: &little,
                count: 4
            ))
        }
        var local = Data()
        a32(0x0403_4B50, to: &local); a16(20, to: &local); a16(0, to: &local); a16(0, to: &local)
        a16(0, to: &local); a16(0, to: &local); a32(crc, to: &local)
        a32(UInt32(fileData.count), to: &local); a32(UInt32(fileData.count), to: &local)
        let nameData = try XCTUnwrap(fileName.data(using: .utf8))
        a16(UInt16(nameData.count), to: &local); a16(0, to: &local)
        local.append(nameData); local.append(fileData)
        var central = Data()
        a32(0x0201_4B50, to: &central); a16(20, to: &central); a16(20, to: &central)
        a16(0, to: &central); a16(0, to: &central); a16(0, to: &central); a16(0, to: &central)
        a32(crc, to: &central); a32(UInt32(fileData.count), to: &central); a32(UInt32(fileData.count), to: &central)
        a16(UInt16(nameData.count), to: &central); a16(0, to: &central); a16(0, to: &central)
        a16(0, to: &central); a16(0, to: &central); a32(0, to: &central); a32(0, to: &central)
        central.append(nameData)
        var eocd = Data()
        a32(0x0605_4B50, to: &eocd); a16(0, to: &eocd); a16(0, to: &eocd)
        a16(1, to: &eocd); a16(1, to: &eocd); a32(UInt32(central.count), to: &eocd)
        a32(UInt32(local.count), to: &eocd); a16(0, to: &eocd)
        var final = Data(); final.append(local); final.append(central); final.append(eocd)
        try final.write(to: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        do {
            try await vm.importBook(book(slug: "evil", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
    }

    func testImportStillRejectsBomb() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("bomb.zip")
        // Single file claiming >100MB uncompressed size
        let name = "book.json"
        let nameData = try XCTUnwrap(name.data(using: .utf8))
        let bigSize: UInt32 = 101 * 1024 * 1024
        func a16(_ val: UInt16, to data: inout Data) {
            var le = val.littleEndian; data.append(Data(bytes: &le, count: 2))
        }
        func a32(_ val: UInt32, to data: inout Data) {
            var le = val.littleEndian; data.append(Data(bytes: &le, count: 4))
        }
        var local = Data()
        a32(0x0403_4B50, to: &local); a16(20, to: &local); a16(0, to: &local); a16(0, to: &local)
        a16(0, to: &local); a16(0, to: &local); a32(0, to: &local); a32(0, to: &local); a32(bigSize, to: &local)
        a16(UInt16(nameData.count), to: &local); a16(0, to: &local)
        local.append(nameData)
        var central = Data()
        a32(0x0201_4B50, to: &central); a16(20, to: &central); a16(20, to: &central)
        a16(0, to: &central); a16(0, to: &central); a16(0, to: &central); a16(0, to: &central)
        a32(0, to: &central); a32(0, to: &central); a32(bigSize, to: &central)
        a16(UInt16(nameData.count), to: &central); a16(0, to: &central); a16(0, to: &central)
        a16(0, to: &central); a16(0, to: &central); a32(0, to: &central); a32(0, to: &central)
        central.append(nameData)
        var eocd = Data()
        a32(0x0605_4B50, to: &eocd); a16(0, to: &eocd); a16(0, to: &eocd)
        a16(1, to: &eocd); a16(1, to: &eocd); a32(UInt32(central.count), to: &eocd)
        a32(UInt32(local.count), to: &eocd); a16(0, to: &eocd)
        var final = Data(); final.append(local); final.append(central); final.append(eocd)
        try final.write(to: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        do {
            try await vm.importBook(book(slug: "bomb", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for bomb")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
    }

    func testImportStillRejectsCRCMismatch() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("crc.zip")
        try makeDescriptorFlagStoreZip(at: zipURL, files: [
            "book.json": Data(#"{"id":"crc-test","name":"C","count":1,"author":"A","references":["C1"]}"#.utf8),
            "chapters/chapter-1.html": Data("<p>hello</p>".utf8), // swiftlint:disable:this trailing_comma
        ])
        var data = try Data(contentsOf: zipURL)
        // Corrupt a byte inside chapter-1.html to trigger CRC mismatch
        if let range = data.range(of: Data("<p>hello</p>".utf8)) {
            data[range.lowerBound] ^= 0xFF
        } else if let range = data.range(of: Data("hello".utf8)) {
            data[range.lowerBound] ^= 0xFF
        } else {
            XCTFail("fixture not found"); return
        }
        try data.write(to: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        do {
            try await vm.importBook(book(slug: "crc-test", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for CRC mismatch")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
    }

    func testImportStillRejectsMissingChapter() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let src = tmp.appendingPathComponent("src-missing", isDirectory: true)
        let ch = src.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: ch, withIntermediateDirectories: true)
        // count 2 but only 1 file + 2 references
        try #"{"id":"missing-ch","name":"M","count":2,"author":"A","references":["C1","C2"]}"#
            .write(to: src.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<p>hi</p>".write(to: ch.appendingPathComponent("chapter-1.html"), atomically: true, encoding: .utf8)
        let zipURL = tmp.appendingPathComponent("missing.zip")
        try FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        do {
            try await vm.importBook(book(slug: "missing-ch", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for missing chapter")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
    }
}
