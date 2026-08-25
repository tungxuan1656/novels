import XCTest

final class FixtureTests: XCTestCase {
    func testFixturesExist() throws {
        let bundle = Bundle(for: Self.self)
        let resourceURL = try XCTUnwrap(bundle.resourceURL)
        let fixtureURL = resourceURL.appendingPathComponent("Fixtures/book.json")
        let flatURL = resourceURL.appendingPathComponent("book.json")
        // Fallback: also check bundle path with subdir resource
        // Xcode bundles Fixtures via Folder Reference — test both
        let existsFixture = FileManager.default.fileExists(atPath: fixtureURL.path)
        let existsFlat = FileManager.default.fileExists(atPath: flatURL.path)
        let altFixture = Bundle(for: Self.self).url(
            forResource: "book",
            withExtension: "json",
            subdirectory: "Fixtures"
        )
        let altFlat = Bundle(for: Self.self).url(forResource: "book", withExtension: "json")
        XCTAssertTrue(
            existsFixture || existsFlat || altFixture != nil || altFlat != nil,
            "Fixtures/book.json missing"
        )
        let candidate = altFixture ?? altFlat ?? (existsFixture ? fixtureURL : existsFlat ? flatURL : nil)
        if let url = candidate {
            let data = try Data(contentsOf: url)
            XCTAssertFalse(data.isEmpty)
        }
    }
}
