import Foundation
@testable import novels
import XCTest

@MainActor
final class EnglishLearningTests: XCTestCase {
    func testDerivedFontSizeUsesReadableMinimum() {
        XCTAssertEqual(EnglishLearning.fontSize(primary: 12), 12)
        XCTAssertEqual(EnglishLearning.fontSize(primary: 16), 14)
        XCTAssertEqual(EnglishLearning.fontSize(primary: 40), 38)
    }

    func testSentenceExtractionPreservesQuotesNamesAndPunctuation() {
        let text = "Tần Dương turned around. \"Do you look down on us?\""
        let sentences = EnglishLearning.sentences(in: text)
        XCTAssertEqual(sentences.map(\.text), ["Tần Dương turned around.", "\"Do you look down on us?\""])
        XCTAssertEqual(sentences.map(\.id), [0, 1])
        XCTAssertEqual(EnglishLearning.sentences(in: "One line without punctuation").map(\.text),
                       ["One line without punctuation"])
        XCTAssertTrue(EnglishLearning.sentences(in: " \n\r ").isEmpty)
    }

    func testTokenizerKeepsAbbreviationAndInteriorText() {
        let text = "Mr. Smith saw Lý Khải.\nHe said hello!"
        let sentences = EnglishLearning.sentences(in: text)
        XCTAssertEqual(sentences.map(\.text), ["Mr. Smith saw Lý Khải.", "He said hello!"])
    }

    func testGoogleQueryIsExplicitAndSafelyEncoded() throws {
        let sentence = "Tần Dương said: \"A+B & C?\"\n100% sure / yes #1"
        let url = try XCTUnwrap(EnglishLearning.googleURL(for: sentence))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/search")
        XCTAssertNil(components.fragment)
        XCTAssertTrue(url.absoluteString.contains("A%2BB"))
        XCTAssertFalse(url.absoluteString.contains("A+B"))
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first { $0.name == "hl" }?.value, "vi")
        let query = try XCTUnwrap(items.first { $0.name == "q" }?.value)
        XCTAssertTrue(query.hasPrefix("Giải thích bằng tiếng Việt"))
        XCTAssertTrue(query.hasSuffix(sentence))
        XCTAssertNil(EnglishLearning.googleURL(for: " \n "))
    }
}
