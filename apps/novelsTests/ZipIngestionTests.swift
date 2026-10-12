import Foundation
@testable import novels
import XCTest

@MainActor
final class ZipIngestionTests: XCTestCase {
    func testValidPackageAndExactRootValidation() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        let source = temp.appendingPathComponent("source")
        let chapters = source.appendingPathComponent("chapters")
        try FileManager.default.createDirectory(at: chapters, withIntermediateDirectories: true)
        let book = Book(id: "sample", name: "Sample", author: nil, count: 1, references: ["https://example.com/1"])
        try JSONEncoder().encode(book).write(to: source.appendingPathComponent("book.json"))
        try Data("<p>Chapter one</p>".utf8).write(to: chapters.appendingPathComponent("chapter-1.html"))
        try Data().write(to: source.appendingPathComponent(".DS_Store"))
        let archive = temp.appendingPathComponent("book.zip")
        let extracted = temp.appendingPathComponent("extracted")
        try FileManager.default.zipItem(at: source, to: archive)
        try FileManager.default.unzipItem(at: archive, to: extracted)
        XCTAssertTrue(ZipValidator.isValidRoot(at: extracted))
        XCTAssertEqual(
            try String(contentsOf: extracted.appendingPathComponent("chapters/chapter-1.html"), encoding: .utf8),
            "<p>Chapter one</p>"
        )
        try Data().write(to: extracted.appendingPathComponent("extra.txt"))
        XCTAssertFalse(ZipValidator.isValidRoot(at: extracted))
        try FileManager.default.removeItem(at: extracted.appendingPathComponent("extra.txt"))
        try FileManager.default.removeItem(at: extracted.appendingPathComponent("chapters/chapter-1.html"))
        XCTAssertFalse(ZipValidator.isValidRoot(at: extracted))
    }

    func testTraversalCannotWriteOutsideDestination() throws {
        try assertRejected(header(name: "../escape"), site: "traversal")
    }

    func testCorruptCRCIsRejected() throws {
        try assertRejected(header(name: "book.json", payload: Data([1])), site: "crc")
    }

    func testExpansionAbove100MiBIsRejectedBeforeAllocation() throws {
        try assertRejected(header(name: "book.json", size: 100 * 1024 * 1024 + 1), site: "bomb")
    }

    /// Malformed local headers exercise rejection before a central directory is needed.
    private func header(name: String, payload: Data = Data(), size: UInt32 = 0) -> Data {
        var data = Data([0x50, 0x4B, 0x03, 0x04, 20, 0] + Array(repeating: 0, count: 24))
        for offset in 0 ..< 4 {
            data[18 + offset] = UInt8(truncatingIfNeeded: UInt32(payload.count) >> (8 * offset))
            data[22 + offset] = UInt8(truncatingIfNeeded: size >> (8 * offset))
        }
        data[26] = UInt8(name.utf8.count)
        data.append(contentsOf: name.utf8)
        data.append(payload)
        return data
    }

    private func assertRejected(_ data: Data, site: String) throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let archive = temp.appendingPathComponent("bad.zip")
        let extracted = temp.appendingPathComponent("extracted")
        try data.write(to: archive)
        XCTAssertThrowsError(try FileManager.default.unzipItem(at: archive, to: extracted)) { error in
            XCTAssertEqual((error as NSError).code, CocoaError.fileReadCorruptFile.rawValue)
            XCTAssertTrue(String(describing: (error as NSError).userInfo).contains("site=\(site)"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.appendingPathComponent("escape").path))
        if FileManager.default.fileExists(atPath: extracted.path) {
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: extracted.path).isEmpty)
        }
    }
}
