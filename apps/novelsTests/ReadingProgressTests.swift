import Foundation
@testable import novels
import XCTest

final class ReadingProgressTests: XCTestCase {
    func testNewerOfflineProgressIsNotOverwrittenByOlderCloudProgress() {
        let date = Date(timeIntervalSince1970: 100)
        let local = ReadingProgress(chapter: 2, anchor: nil, updatedAt: date)
        let olderCloud = ReadingProgress(chapter: 9, anchor: nil, updatedAt: date.addingTimeInterval(-1))
        let newerCloud = ReadingProgress(chapter: 1, anchor: nil, updatedAt: date.addingTimeInterval(1))

        XCTAssertFalse(olderCloud.supersedesLocal(local))
        XCTAssertTrue(newerCloud.supersedesLocal(local))
        XCTAssertTrue(local.supersedesLocal(local))
        XCTAssertTrue(olderCloud.supersedesLocal(nil))
    }

    func testNewerCloudChapterMustFitTheInstalledCopy() {
        let progress = ReadingProgress(chapter: 8, anchor: nil, updatedAt: .now)

        XCTAssertFalse(progress.fits(chapterCount: 7))
        XCTAssertFalse(progress.fits(chapterCount: 0))
        XCTAssertTrue(progress.fits(chapterCount: 8))
    }

    func testAnchorIsOnlyRestoredInTheSameRenditionAndBounds() {
        let anchor = ReadingProgress.Anchor(rendition: "raw-edition-a", paragraph: 4)
        XCTAssertEqual(anchor.index(in: "raw-edition-a", count: 5), 4)
        XCTAssertNil(anchor.index(in: "raw-edition-b", count: 5))
        XCTAssertNil(anchor.index(in: "raw-edition-a", count: 4))
    }

    func testCloudCheckpointRejectsInvalidChapterAndParagraph() throws {
        let invalidChapter = ReadingProgress(chapter: 0, anchor: nil, updatedAt: .now)
        let invalidAnchor = ReadingProgress.Anchor(rendition: "raw-edition-a", paragraph: -1)
        let invalidParagraph = ReadingProgress(chapter: 1, anchor: invalidAnchor, updatedAt: .now)
        let valid = ReadingProgress(chapter: 1, anchor: nil, updatedAt: .now)

        XCTAssertNil(try ReadingProgress.decode(JSONEncoder().encode(invalidChapter)))
        XCTAssertNil(try ReadingProgress.decode(JSONEncoder().encode(invalidParagraph)))
        XCTAssertEqual(try ReadingProgress.decode(JSONEncoder().encode(valid)), valid)
    }
}
