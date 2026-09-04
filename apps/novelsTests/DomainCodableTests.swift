@testable import novels
import XCTest

final class DomainCodableTests: XCTestCase {
    func testBookCodableRoundTrip() throws {
        let json = #"{"id":"test-slug","name":"Test","count":2,"author":"A","references":["Ch 1","Ch 2"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let book = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(book.id, "test-slug")
        XCTAssertEqual(book.count, 2)
        XCTAssertEqual(book.references.count, 2)
        XCTAssertEqual(book.references, ["Ch 1", "Ch 2"])
        XCTAssertEqual(book.author, "A")
        XCTAssertEqual(book.name, "Test")
        let encoded = try JSONEncoder().encode(book)
        let decoded2 = try JSONDecoder().decode(Book.self, from: encoded)
        XCTAssertEqual(decoded2, book)
    }

    func testBookIdDoesNotCoerceNumber() throws {
        let json = #"{"id":123,"name":"Test","count":2,"references":["Ch 1","Ch 2"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(Book.self, from: data))
    }

    func testReferenceTypealias() {
        let ref: Reference = "Ch 1"
        XCTAssertEqual(ref, "Ch 1")
        let book = Book(
            id: "slug",
            name: "N",
            author: nil,
            count: 1,
            references: [ref]
        )
        XCTAssertEqual(book.references.first, "Ch 1")
    }

    func testAIModeRawValues() {
        XCTAssertEqual(AIMode.none.rawValue, "none")
        XCTAssertEqual(AIMode.rewrite.rawValue, "rewrite")
    }

    func testAIModeCodableRoundTrip() throws {
        for mode in AIMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AIMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testProcessedChapterHashStable() {
        let hash = SHA256.hex("hi")
        let now = Date()
        let chapter = ProcessedChapter(
            bookId: "s",
            chapterNumber: 1,
            mode: .rewrite,
            content: "hi",
            contentHash: SHA256.hex("hi"),
            createdAt: now,
            updatedAt: now
        )
        XCTAssertEqual(chapter.contentHash, hash)
        XCTAssertEqual(chapter.contentHash, SHA256.hex("hi"))
        XCTAssertNotEqual(SHA256.hex("hi"), SHA256.hex("hello"))
    }

    func testSHA256HexKnownValue() {
        // SHA256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        XCTAssertEqual(
            SHA256.hex("hello"),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
        XCTAssertEqual(SHA256.hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testReadingSessionCodableRoundTrip() throws {
        let session = ReadingSession(
            bookId: "test-slug",
            onScreen: true,
            offset: 123.45,
            chapterNumber: 2
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(ReadingSession.self, from: data)
        XCTAssertEqual(decoded, session)
        // JSON keys round-trip
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("test-slug"))
    }

    func testTypographySettingCodableRoundTrip() throws {
        let setting = TypographySetting(
            font: "System",
            fontSize: 16,
            lineHeight: 1.5,
            letterSpacing: 0
        )
        let data = try JSONEncoder().encode(setting)
        let decoded = try JSONDecoder().decode(TypographySetting.self, from: data)
        XCTAssertEqual(decoded, setting)
    }

    func testTypographyDefaults() {
        let defaults = TypographySetting.default
        XCTAssertEqual(defaults.font, "System")
        XCTAssertEqual(defaults.fontSize, 16)
        XCTAssertEqual(defaults.lineHeight, 1.5)
        XCTAssertEqual(defaults.letterSpacing, 0)
    }

    func testSettingsDefaultsPrompt() {
        XCTAssertFalse(SettingsDefaults.defaultPrompt.isEmpty)
        XCTAssertTrue(SettingsDefaults.defaultPrompt.contains("tiếng Việt"))
    }

    func testBookAuthorOptionalMissing() throws {
        let json = #"{"id":"slug","name":"Test","count":1,"references":["Ch 1"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let book = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertNil(book.author)
    }

    func testBookDecodeFallsBackWhenIdMissing() throws {
        let json = #"{"name":"Vạn Giới","count":1,"author":"A","references":["C1"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let book = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(book.id, "van-gioi")
        XCTAssertEqual(book.name, "Vạn Giới")
    }

    func testBookDecodeEmptyIdFallsBack() throws {
        let json = #"{"id":"","name":"Vạn Giới Chi Rút Thưởng Hệ Thống","count":1,"author":"A","references":["C1"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let book = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(book.id, "van-gioi-chi-rut-thuong-he-thong")
    }
}
