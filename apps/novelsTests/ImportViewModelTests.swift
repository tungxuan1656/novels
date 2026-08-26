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

    func testImportInvalidWrapperNoFolder() async throws {
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
        do {
            try await vm.importBook(book(slug: "bad", exportUrl: zip.absoluteString))
            XCTFail("expected invalidPackage")
        } catch {}
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tmp.appendingPathComponent("books/bad").path)
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
        do {
            try await vm.importBook(book(slug: "macosx-test", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage due to __MACOSX")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        } catch {
            // Any error is acceptable as invalidPackage mapping
            XCTAssertTrue(error is ImportError || (error as NSError).domain == NSCocoaErrorDomain)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("books/macosx-test").path))
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
}
