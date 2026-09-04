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

private func makeVersion45Zip(at zipURL: URL) throws {
    // Single stored entry advertising version-needed 45 (ZIP64 signature).
    let content = Data("{\"id\":\"z64\",\"name\":\"Z\",\"count\":0,\"author\":null,\"references\":[]}".utf8)
    var crc: UInt32 = 0xFFFF_FFFF
    var table = [UInt32](repeating: 0, count: 256)
    for idx in 0 ..< 256 {
        var value = UInt32(idx)
        for _ in 0 ..< 8 {
            value = (value & 1) != 0 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
        }
        table[idx] = value
    }
    for byte in content {
        crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
    }
    crc ^= 0xFFFF_FFFF
    func append16(_ value: UInt16, to data: inout Data) {
        var little = value.littleEndian
        data.append(Data(bytes: &little, count: 2))
    }
    func append32(_ value: UInt32, to data: inout Data) {
        var little = value.littleEndian
        data.append(Data(bytes: &little, count: 4))
    }
    let nameData = Data("book.json".utf8)
    var local = Data()
    append32(0x0403_4B50, to: &local)
    append16(45, to: &local)
    append16(0, to: &local)
    append16(0, to: &local)
    append16(0, to: &local)
    append16(0, to: &local)
    append32(crc, to: &local)
    append32(UInt32(content.count), to: &local)
    append32(UInt32(content.count), to: &local)
    append16(UInt16(nameData.count), to: &local)
    append16(0, to: &local)
    local.append(nameData)
    local.append(content)
    try local.write(to: zipURL)
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

    // MARK: - Device-parity hardening: legacy filenames, deep wrappers, raw deflate

    func testImportLegacyCP437FilenameWrapperSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("legacy-name.zip")
        // "café/" in Latin-1 bytes (0xE9 invalid alone in UTF-8), UTF8-flag=0:
        // Files/Windows ZIPs with VI names. Old code threw on decode.
        try TolerantFixtures.makeLegacyFilenameWrapperZip(
            at: zipURL,
            id: "legacy-vi",
            outerNameBytes: Data([0x63, 0x61, 0x66, 0xE9, 0x2F]),
            flag: 0x0000
        )
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "legacy-vi", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/legacy-vi/book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/legacy-vi/chapters/chapter-1.html").path))
    }

    func testImportUTF8BytesWithFlagZeroWrapperSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("utf8-flag0.zip")
        // VI folder name in real UTF-8 bytes but UTF8-flag=0 (common producer).
        var outer = Data("truyện-".utf8)
        outer.append(0x2F) // "/"
        try TolerantFixtures.makeLegacyFilenameWrapperZip(
            at: zipURL,
            id: "utf8-flag0",
            outerNameBytes: outer,
            flag: 0x0000
        )
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "utf8-flag0", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/utf8-flag0/book.json").path))
    }

    func testImportDeepWrapperWithStraysSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("deep-strays.zip")
        try TolerantFixtures.makeDeepWrapperWithStraysZip(at: zipURL, id: "deep-book", depth: 2)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "deep-book", exportUrl: zipURL.absoluteString))
        let dest = tmp.appendingPathComponent("books/deep-book")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: dest.appendingPathComponent("chapters/chapter-1.html").path))
        for stray in ["__macosx", ".Spotlight-V100", ".Trashes", "Thumbs.db", ".LSOverride", ".DS_Store"] {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: dest.appendingPathComponent(stray).path),
                "stray \(stray) must not be imported"
            )
        }
    }

    func testImportTooDeepWrapperRejectedAndLogged() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("too-deep.zip")
        try TolerantFixtures.makeDeepWrapperWithStraysZip(at: zipURL, id: "too-deep", depth: 4)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "too-deep", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage beyond flatten depth")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        XCTAssertTrue(
            entries.contains { $0.event == "import.fail" && ($0.detail?.contains("stage=validate") ?? false) },
            "validator cause must be visible in Log viewer"
        )
        // Reason must be human-readable Vietnamese, never a bare "invalidPackage:0".
        let fail = entries.first { $0.event == "import.fail" }
        let detail = try XCTUnwrap(fail?.detail)
        XCTAssertTrue(detail.contains("reason="), "import.fail must carry a reason, got: \(detail)")
        XCTAssertTrue(detail.contains("book.json"), "validate reason must name book.json, got: \(detail)")
        XCTAssertFalse(detail.contains("invalidPackage:0"), "must not surface bare error, got: \(detail)")
        // start -> fail share one requestId for correlation.
        let start = entries.first { $0.event == "import.start" }
        XCTAssertEqual(start?.requestId, fail?.requestId, "start/fail must correlate by requestId")
    }

    func testImportCorruptZipFailsAtUnzipWithReason() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = makeValidZip(at: tmp, slug: "corrupt-unzip", count: 1)
        // Flip a content byte so the stored CRC no longer matches -> unzip throws.
        var data = try Data(contentsOf: zipURL)
        if let range = data.range(of: Data("<html>c1</html>".utf8)) {
            data[range.lowerBound] ^= 0xFF
        } else {
            XCTFail("fixture content not found"); return
        }
        try data.write(to: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "corrupt-unzip", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for corrupt zip")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=unzip"), "corrupt zip must fail at unzip, got: \(detail)")
        XCTAssertTrue(detail.contains("reason="), "import.fail must carry a reason, got: \(detail)")
        XCTAssertTrue(detail.contains("cắt xén"), "crc reason must hint truncated download, got: \(detail)")
    }

    func testImportDownloadTimeoutFailsWithReason() async throws {
        let repo = makeMockRepository()
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(error: URLError(.timedOut))
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "timeout-book", exportUrl: "https://cdn.example.com/b.zip"))
            XCTFail("expected downloadFailed")
        } catch let err as ImportError {
            XCTAssertEqual(err, .downloadFailed)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        XCTAssertEqual(fail.host, "cdn.example.com", "must log host without token/query")
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=download"), "got: \(detail)")
        XCTAssertTrue(detail.contains("hết thời gian"), "timeout reason must be Vietnamese, got: \(detail)")
    }

    func testImportSuccessLogsStartAndSuccessWithSharedRequestId() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zip = makeValidZip(at: tmp, slug: "logged-book", count: 2)
        let repo = FileBookRepository(
            root: tmp.appendingPathComponent("books", isDirectory: true),
            fileManager: .default
        )
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zip)
        )
        await DiagnosticsLog.shared.clear()
        try await vm.importBook(book(slug: "logged-book", exportUrl: zip.absoluteString))
        let entries = await DiagnosticsLog.shared.snapshot()
        let start = try XCTUnwrap(entries.first { $0.event == "import.start" })
        let success = try XCTUnwrap(entries.first { $0.event == "import.success" })
        XCTAssertEqual(start.requestId, success.requestId, "start/success must correlate by requestId")
        XCTAssertEqual(success.bookId, "logged-book")
        XCTAssertTrue(
            success.detail?.contains("chapters=2") ?? false,
            "success must carry chapter count, got: \(success.detail ?? "-")"
        )
        XCTAssertFalse(entries.contains { $0.event == "import.fail" }, "no failure expected")
    }

    func testImportRawDeflateSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("raw-deflate.zip")
        try TolerantFixtures.makeRawDeflateZip(at: zipURL, id: "deflate-book", count: 2)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "deflate-book", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/deflate-book/book.json").path))
        let html = try String(
            contentsOf: tmp.appendingPathComponent("books/deflate-book/chapters/chapter-1.html"),
            encoding: .utf8
        )
        XCTAssertTrue(html.contains("Nội dung chương 1"))
    }

    func testImportUppercaseNamesNormalized() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Device ZIPs with Book.JSON / CHAPTERS / CHAPTER-01.HTML casing must
        // import on case-sensitive filesystems via canonical-root normalisation.
        let src = tmp.appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        let chapters = src.appendingPathComponent("CHAPTERS", isDirectory: true)
        try FileManager.default.createDirectory(at: chapters, withIntermediateDirectories: true)
        try #"{"id":"upper-book","name":"U","count":2,"author":"A","references":["C1","C2"]}"#
            .write(to: src.appendingPathComponent("Book.JSON"), atomically: true, encoding: .utf8)
        try "<p>one</p>".write(
            to: chapters.appendingPathComponent("CHAPTER-01.HTML"),
            atomically: true,
            encoding: .utf8
        )
        try "<p>two</p>".write(
            to: chapters.appendingPathComponent("Chapter-2.html"),
            atomically: true,
            encoding: .utf8
        )
        let zipURL = tmp.appendingPathComponent("upper.zip")
        try FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: src)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "upper-book", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/upper-book/book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/upper-book/chapters/chapter-1.html").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/upper-book/chapters/chapter-2.html").path))
    }

    func testImportFailDetailCarriesDiag() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let src = tmp.appendingPathComponent("src", isDirectory: true)
        let chapters = src.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chapters, withIntermediateDirectories: true)
        try "{\"id\":\"diag-import\",\"name\":\"D\",\"count\":1,\"author\":\"A\",\"references\":[\"C1\"]}".write(
            to: src.appendingPathComponent("book.json"),
            atomically: true,
            encoding: .utf8
        )
        try "<p>1</p>".write(
            to: chapters.appendingPathComponent("chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        try "cover".write(to: src.appendingPathComponent("cover.jpg"), atomically: true, encoding: .utf8)
        let zipURL = tmp.appendingPathComponent("extra.zip")
        try FileManager.default.zipItem(at: src, to: zipURL, shouldKeepParent: false)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "diag-import", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for extra file")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=validate"), "got: \(detail)")
        XCTAssertTrue(detail.contains("diag="), "got: \(detail)")
        XCTAssertTrue(detail.contains("depth=0"), "got: \(detail)")
        XCTAssertTrue(detail.contains("extra=[cover.jpg]"), "got: \(detail)")
        XCTAssertTrue(detail.contains("thừa file"), "reason must name extra-file cause, got: \(detail)")
    }

    func testImportFailCarriesMethodSite() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Synthetic method-12 entry: reader only accepts 0/8.
        let content = Data("{\"id\":\"m\",\"name\":\"M\",\"count\":0,\"author\":null,\"references\":[]}".utf8)
        let zipURL = tmp.appendingPathComponent("method12.zip")
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("book.json".utf8),
                content: content,
                storedBytes: content,
                method: 12,
                flag: 0x0800
            ), // swiftlint:disable:this trailing_comma
        ])
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "m", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for method 12")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=unzip"), "got: \(detail)")
        XCTAssertTrue(detail.contains("uz="), "got: \(detail)")
        XCTAssertTrue(detail.contains("site=method"), "got: \(detail)")
        XCTAssertTrue(detail.contains("method=12"), "got: \(detail)")
        XCTAssertTrue(detail.contains("không hỗ trợ"), "reason must name unsupported method, got: \(detail)")
    }

    func testImportFailCarriesCrcSite() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = makeValidZip(at: tmp, slug: "crc-uz", count: 1)
        // Flip one chapter content byte so stored CRC no longer matches.
        var data = try Data(contentsOf: zipURL)
        if let range = data.range(of: Data("<html>c1</html>".utf8)) {
            data[range.lowerBound] ^= 0xFF
        } else {
            XCTFail("fixture content not found"); return
        }
        try data.write(to: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "crc-uz", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for CRC mismatch")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=unzip"), "got: \(detail)")
        XCTAssertTrue(detail.contains("site=crc"), "got: \(detail)")
        XCTAssertTrue(detail.contains("cắt xén"), "reason must hint truncated download, got: \(detail)")
    }

    func testImportFailCarriesDescriptorSite() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let zipURL = tmp.appendingPathComponent("truncated-desc.zip")
        try makeDescriptorFlagStoreZip(at: zipURL, files: [
            "book.json": Data("{\"id\":\"d\",\"name\":\"D\",\"count\":0,\"author\":null,\"references\":[]}".utf8),
            "chapters/chapter-1.html": Data("<p>hi</p>".utf8), // swiftlint:disable:this trailing_comma
        ])
        // Truncate inside the first entry's payload so no next header exists
        // for the descriptor scan.
        var data = try Data(contentsOf: zipURL)
        let firstNameLen = Int(UInt16(data[26]) | UInt16(data[27]) << 8)
        let firstExtraLen = Int(UInt16(data[28]) | UInt16(data[29]) << 8)
        data = data.prefix(30 + firstNameLen + firstExtraLen + 5)
        try data.write(to: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "d", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for truncated descriptor zip")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=unzip"), "got: \(detail)")
        XCTAssertTrue(detail.contains("site=descriptor"), "got: \(detail)")
        XCTAssertTrue(detail.contains("mở rộng"), "reason must name descriptor format, got: \(detail)")
    }

    func testImportAbsolutePathWrapperSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Device shape: ZIP packed with absolute paths (`/cao-vo-…/book.json`).
        // Relativized under the destination, then flattened like any wrapper.
        let wrapper = "/cao-vo-toan-lop-lieu"
        let bookData = Data("{\"id\":\"abs-book\",\"name\":\"A\",\"count\":1,\"author\":null,\"references\":[\"C1\"]}"
            .utf8)
        let chapterData = Data("<p>hi</p>".utf8)
        func stored(_ name: String, _ content: Data) -> TolerantFixtures.RawZipEntry {
            TolerantFixtures.RawZipEntry(
                nameBytes: Data(name.utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: 0x0800
            )
        }
        let zipURL = tmp.appendingPathComponent("absolute.zip")
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            stored("\(wrapper)/book.json", bookData),
            stored("\(wrapper)/chapters/chapter-1.html", chapterData), // swiftlint:disable:this trailing_comma
        ])
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "abs-book", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/abs-book/book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/abs-book/chapters/chapter-1.html").path))
    }

    func testImportBackslashSeparatorsSucceed() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Windows-packed separators normalize to subdirectories.
        let bookData = Data("{\"id\":\"bs-book\",\"name\":\"B\",\"count\":1,\"author\":null,\"references\":[\"C1\"]}"
            .utf8)
        let chapterData = Data("<p>hi</p>".utf8)
        let zipURL = tmp.appendingPathComponent("backslash.zip")
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("bs-pkg\\book.json".utf8),
                content: bookData,
                storedBytes: bookData,
                method: 0,
                flag: 0x0000
            ),
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("bs-pkg\\chapters\\chapter-1.html".utf8),
                content: chapterData,
                storedBytes: chapterData,
                method: 0,
                flag: 0x0000
            ), // swiftlint:disable:this trailing_comma
        ])
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "bs-book", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/bs-book/chapters/chapter-1.html").path))
    }

    func testEscapingPathsStillRejected() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Each shape must still fail closed after normalization.
        let shapes: [(String, [String])] = [
            ("dotdot", ["pkg/../../evil.html"]),
            ("abs-dotdot", ["/../evil.html"]),
            ("backslash-dotdot", ["..\\evil.html"]),
            ("drive", ["C:\\evil.html"]), // swiftlint:disable:this trailing_comma
        ]
        for (label, names) in shapes {
            let zipURL = tmp.appendingPathComponent("\(label).zip")
            let content = Data("x".utf8)
            try TolerantFixtures.makeRawZip(at: zipURL, entries: names.map {
                TolerantFixtures.RawZipEntry(
                    nameBytes: Data($0.utf8),
                    content: content,
                    storedBytes: content,
                    method: 0,
                    flag: 0x0000
                )
            })
            let out = tmp.appendingPathComponent("out-\(label)", isDirectory: true)
            do {
                try FileManager.default.unzipItem(at: zipURL, to: out)
                XCTFail("\(label) must be rejected")
            } catch {
                let token = UnzipFailure.token(from: error) ?? "<no-uz>"
                XCTAssertTrue(token.contains("site=traversal"), "\(label) got: \(token)")
                let ns = error as NSError
                XCTAssertEqual(ns.domain, NSCocoaErrorDomain)
                XCTAssertEqual(ns.code, NSFileReadCorruptFileError)
            }
        }
        // Nothing escaped the destinations.
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("evil.html").path))
    }

    // MARK: - Group 1: BOM, encrypted, HTTP status, ZIP64

    func testImportBOMBookJsonSucceeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Windows editors prepend EF BB BF; decoder must skip it.
        var bookData = Data([0xEF, 0xBB, 0xBF])
        let bomJSON = "{\"id\":\"bom-book\",\"name\":\"B\",\"count\":1,\"author\":null,\"references\":[\"C1\"]}"
        bookData.append(contentsOf: Data(bomJSON.utf8))
        let chapterData = Data("<p>hi</p>".utf8)
        let zipURL = tmp.appendingPathComponent("bom.zip")
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("book.json".utf8),
                content: bookData,
                storedBytes: bookData,
                method: 0,
                flag: 0x0800
            ),
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("chapters/chapter-1.html".utf8),
                content: chapterData,
                storedBytes: chapterData,
                method: 0,
                flag: 0x0800
            ), // swiftlint:disable:this trailing_comma
        ])
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "bom-book", exportUrl: zipURL.absoluteString))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/bom-book/book.json").path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: tmp.appendingPathComponent("books/bom-book/chapters/chapter-1.html").path))
    }

    func testImportEncryptedEntryFails() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let content = Data("secret".utf8)
        let zipURL = tmp.appendingPathComponent("encrypted.zip")
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("book.json".utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: 0x0001
            ), // swiftlint:disable:this trailing_comma
        ])
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "enc", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for encrypted entry")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=unzip"), "got: \(detail)")
        XCTAssertTrue(detail.contains("site=encrypted"), "got: \(detail)")
        XCTAssertTrue(detail.contains("mã hoá"), "reason must name encryption, got: \(detail)")
    }

    func testDownloaderStatusMapping() throws {
        let url = try XCTUnwrap(URL(string: "https://cdn.example.com/a.zip"))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for code in [200, 201, 299] {
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            ))
            XCTAssertEqual(try URLSessionDownloader.validatedDownloadURL(fileURL: file, response: response), file)
        }
        for code in [199, 300, 404, 500] {
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            ))
            XCTAssertThrowsError(try URLSessionDownloader.validatedDownloadURL(
                fileURL: file,
                response: response
            )) { error in
                XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
            }
        }
        let plain = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(try URLSessionDownloader.validatedDownloadURL(fileURL: file, response: plain), file)
    }

    func testBadServerResponseRoutesToDownloadStage() async throws {
        let repo = makeMockRepository()
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(error: URLError(.badServerResponse))
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "gone", exportUrl: "https://cdn.example.com/gone.zip"))
            XCTFail("expected downloadFailed")
        } catch let err as ImportError {
            XCTAssertEqual(err, .downloadFailed)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        XCTAssertTrue(fail.detail?.contains("stage=download") ?? false, "got: \(fail.detail ?? "-")")
    }

    func testImportZIP64SignaturedEntryFails() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Hand-rolled local header advertising version-needed 45 (ZIP64).
        let zipURL = tmp.appendingPathComponent("zip64.zip")
        try makeVersion45Zip(at: zipURL)
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        await DiagnosticsLog.shared.clear()
        do {
            try await vm.importBook(book(slug: "z64", exportUrl: zipURL.absoluteString))
            XCTFail("expected invalidPackage for ZIP64")
        } catch let err as ImportError {
            XCTAssertEqual(err, .invalidPackage)
        }
        let entries = await DiagnosticsLog.shared.snapshot()
        let fail = try XCTUnwrap(entries.first { $0.event == "import.fail" })
        let detail = try XCTUnwrap(fail.detail)
        XCTAssertTrue(detail.contains("stage=unzip"), "got: \(detail)")
        XCTAssertTrue(detail.contains("site=zip64"), "got: \(detail)")
        XCTAssertTrue(detail.contains("ZIP64"), "reason must name ZIP64, got: \(detail)")
    }

    func testImportLargeMappedReadParity() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // ~4MB stored payload forces real multi-page mapped reads; bytes must
        // round-trip identically through the memory-mapped parser.
        var seed: UInt64 = 0x1234_5678
        func pseudoRandom(_ count: Int, marker: String) -> Data {
            var out = Data(marker.utf8)
            out.reserveCapacity(count)
            while out.count < count {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                out.append(UInt8((seed >> 33) & 0xFF))
            }
            return out
        }
        let chapter1 = pseudoRandom(2 * 1024 * 1024, marker: "<html>CH1:")
        let chapter2 = pseudoRandom(2 * 1024 * 1024, marker: "<html>CH2:")
        let bigBookJSON = "{\"id\":\"big-book\",\"name\":\"B\",\"count\":2,\"author\":null,"
            + "\"references\":[\"C1\",\"C2\"]}"
        let bookData = Data(bigBookJSON.utf8)
        func stored(_ name: String, _ content: Data) -> TolerantFixtures.RawZipEntry {
            TolerantFixtures.RawZipEntry(
                nameBytes: Data(name.utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: 0x0800
            )
        }
        let zipURL = tmp.appendingPathComponent("big.zip")
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            stored("book.json", bookData),
            stored("chapters/chapter-1.html", chapter1),
            stored("chapters/chapter-2.html", chapter2), // swiftlint:disable:this trailing_comma
        ])
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let vm = ImportViewModel(
            catalogService: MockCatalog(books: []),
            repository: repo,
            downloader: MockDownloader(zipURL: zipURL)
        )
        try await vm.importBook(book(slug: "big-book", exportUrl: zipURL.absoluteString))
        let saved1 = try Data(contentsOf: tmp.appendingPathComponent("books/big-book/chapters/chapter-1.html"))
        let saved2 = try Data(contentsOf: tmp.appendingPathComponent("books/big-book/chapters/chapter-2.html"))
        XCTAssertEqual(saved1, chapter1)
        XCTAssertEqual(saved2, chapter2)
    }

    func testTraversalShowsFullNamePast40Chars() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Escape hidden past the old 40-char truncation must stay visible.
        let longWrapper = String(repeating: "a", count: 50)
        let zipURL = tmp.appendingPathComponent("hidden-tail.zip")
        let content = Data("x".utf8)
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("\(longWrapper)/../../evil.html".utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: 0x0000
            ), // swiftlint:disable:this trailing_comma
        ])
        let out = tmp.appendingPathComponent("out", isDirectory: true)
        do {
            try FileManager.default.unzipItem(at: zipURL, to: out)
            XCTFail("hidden escape must be rejected")
        } catch {
            let token = try XCTUnwrap(UnzipFailure.token(from: error))
            XCTAssertTrue(token.contains("site=traversal"), "got: \(token)")
            XCTAssertTrue(token.contains("/../../evil.html"), "tail must stay visible, got: \(token)")
            let ns = error as NSError
            XCTAssertEqual(ns.domain, NSCocoaErrorDomain)
            XCTAssertEqual(ns.code, NSFileReadCorruptFileError)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("evil.html").path))
    }

    func testBackslashDeepEscapeStillRejected() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Prime suspect for the device prefix hit: long wrapper + backslash
        // `..` tail. Normalized before the check, so it stays rejected.
        let longWrapper = String(repeating: "b", count: 50)
        let zipURL = tmp.appendingPathComponent("backslash-deep.zip")
        let content = Data("x".utf8)
        try TolerantFixtures.makeRawZip(at: zipURL, entries: [
            TolerantFixtures.RawZipEntry(
                nameBytes: Data("\(longWrapper)\\..\\..\\evil.html".utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: 0x0000
            ), // swiftlint:disable:this trailing_comma
        ])
        let out = tmp.appendingPathComponent("out", isDirectory: true)
        do {
            try FileManager.default.unzipItem(at: zipURL, to: out)
            XCTFail("backslash escape must be rejected")
        } catch {
            let token = try XCTUnwrap(UnzipFailure.token(from: error))
            XCTAssertTrue(token.contains("site=traversal"), "got: \(token)")
            XCTAssertTrue(token.contains(".."), "normalized tail must stay visible, got: \(token)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("evil.html").path))
    }

    func testUnzipTokenTailsAndCaps() {
        let longName = String(repeating: "n", count: 100) + "/chapter-1.html"
        let prefix = UnzipFailure(
            site: "prefix",
            entryIndex: 0,
            method: 0,
            compSize: 0,
            isDescriptor: false,
            uncompSize: 0,
            entriesExtracted: 0,
            entryName: String(longName.prefix(160)),
            note: "base=\(String(repeating: "b", count: 70)) dest=\(String(repeating: "d", count: 70))"
        ).token()
        XCTAssertTrue(prefix.contains("name=\(longName)"), "prefix keeps full name, got: \(prefix)")
        XCTAssertTrue(prefix.contains("base="), "got: \(prefix)")
        XCTAssertTrue(prefix.contains("dest="), "got: \(prefix)")
        let crc = UnzipFailure(
            site: "crc",
            entryIndex: 1,
            method: 0,
            compSize: 15,
            isDescriptor: false,
            uncompSize: 15,
            entriesExtracted: 1,
            entryName: String(longName.prefix(160))
        ).token()
        XCTAssertTrue(crc.contains("name=\(String(longName.prefix(40)))"), "other sites keep 40-cap, got: \(crc)")
        XCTAssertFalse(crc.contains(longName), "got: \(crc)")
        XCTAssertFalse(crc.contains("base="), "got: \(crc)")
        // Method parse survives trailing free-form segments. Key literal mirrors
        // the private unzipFailureUserInfoKey; a key change fails loudly here.
        let parsed = UnzipFailure.siteAndMethod(from: NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadCorruptFileError,
            userInfo: ["com.novels.unzipFailure": prefix]
        ))
        XCTAssertEqual(parsed?.site, "prefix")
        XCTAssertEqual(parsed?.method, 0)
    }
}
