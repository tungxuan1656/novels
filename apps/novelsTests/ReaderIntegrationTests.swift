@testable import novels
import XCTest

@MainActor
final class ReaderIntegrationTests: XCTestCase {
    private struct Fixture {
        let viewModel: ReaderViewModel
        let tempRoot: URL
        let store: SettingsStore
    }

    private func makeFixture(slug: String = "test-slug", htmls: [String]) -> Fixture {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let bookDir = tempRoot.appendingPathComponent(slug)
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("chapters"),
                withIntermediateDirectories: true
            )
            let book = Book(
                id: slug,
                name: "Test",
                author: "A",
                count: htmls.count,
                references: (1 ... htmls.count).map { "C\($0)" }
            )
            let data = try JSONEncoder().encode(book)
            try data.write(to: bookDir.appendingPathComponent("book.json"))
            for (idx, html) in htmls.enumerated() {
                let number = idx + 1
                try html.write(
                    to: bookDir.appendingPathComponent("chapters/chapter-\(number).html"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        } catch {
            XCTFail("Setup failed: \(error)")
        }
        let defaults = UserDefaults(suiteName: "test.integration.\(UUID().uuidString)") ?? UserDefaults.standard
        let store = SettingsStore(userDefaults: defaults)
        let repo = FileBookRepository(root: tempRoot, fileManager: .default)
        let viewModel = ReaderViewModel(bookId: slug, repository: repo, settingsStore: store)
        return Fixture(viewModel: viewModel, tempRoot: tempRoot, store: store)
    }

    func testReaderEndToEndFromFixtures() async {
        let fixture = makeFixture(htmls: [
            "<h1>T1</h1><p>Hello</p>",
            "<p><b>Bold</b> <i>Italic</i></p>",
            "", // swiftlint:disable:this trailing_comma
        ])
        defer { try? FileManager.default.removeItem(at: fixture.tempRoot) }
        let viewModel = fixture.viewModel
        await viewModel.load()
        XCTAssertEqual(viewModel.blocks.first?.spans.first?.text, "T1")
        XCTAssertEqual(viewModel.blocks.first?.isHeading, true)
        XCTAssertEqual(viewModel.blocks.first?.headingLevel, 1)

        await viewModel.goToChapter(2)
        XCTAssertEqual(viewModel.blocks.first?.spans[0].kind, .bold)
        XCTAssertEqual(viewModel.blocks.first?.spans[0].text, "Bold")
        XCTAssertEqual(viewModel.blocks.first?.spans[1].kind, .italic)
        XCTAssertEqual(viewModel.blocks.first?.spans[1].text, "Italic")

        await viewModel.goToChapter(99)
        XCTAssertEqual(viewModel.chapterNumber, 3)

        await viewModel.goToChapter(0)
        XCTAssertEqual(viewModel.chapterNumber, 1)
    }

    func testHeadingAndClampIntegration() async {
        let fixture = makeFixture(slug: "clamp-slug", htmls: [
            "<p>One</p>",
            "<p>Two</p>",
            "<p>Three</p>", // swiftlint:disable:this trailing_comma
        ])
        defer { try? FileManager.default.removeItem(at: fixture.tempRoot) }
        let viewModel = fixture.viewModel
        await viewModel.load()
        XCTAssertEqual(viewModel.chapterNumber, 1)
        await viewModel.goToChapter(99)
        XCTAssertEqual(viewModel.chapterNumber, 3)
        XCTAssertFalse(viewModel.canGoNext)
        XCTAssertTrue(viewModel.canGoPrev)
        await viewModel.goToChapter(0)
        XCTAssertEqual(viewModel.chapterNumber, 1)
        XCTAssertFalse(viewModel.canGoPrev)
        XCTAssertTrue(viewModel.canGoNext)
    }
}
