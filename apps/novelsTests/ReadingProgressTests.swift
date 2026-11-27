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

    func testIncompatibleNewerCloudCheckpointKeepsLocalProgressWithoutRetry() {
        let date = Date(timeIntervalSince1970: 100)
        let local = ReadingProgress(chapter: 2, anchor: nil, updatedAt: date)
        let pending = ReadingProgressStore.Entry(progress: local, isLocal: true, pending: true)
        let remote = ReadingProgress(chapter: 8, anchor: nil, updatedAt: date.addingTimeInterval(1))

        let kept = pending.resolving(remote, chapterCount: 7)
        XCTAssertEqual(kept.progress, local)
        XCTAssertTrue(kept.isLocal)
        XCTAssertFalse(kept.pending)

        let imported = pending.resolving(remote, chapterCount: 8)
        XCTAssertEqual(imported.progress, remote)
        XCTAssertFalse(imported.isLocal)
        XCTAssertFalse(imported.pending)
    }

    func testLegacyUnownedCheckpointsAreNeverPendingAfterMigration() throws {
        let progress = ReadingProgress(chapter: 2, anchor: nil, updatedAt: .now)
        let local = ReadingProgressStore.Entry(progress: progress, isLocal: true, pending: true)
        let remote = ReadingProgressStore.Entry(progress: progress, isLocal: false, pending: false)
        let legacy = ["on-device": local, "downloaded": remote]
        let result = try ReadingProgressStore.localEntries(from: JSONEncoder().encode(legacy))

        XCTAssertEqual(
            result,
            ["on-device": ReadingProgressStore.Entry(progress: progress, isLocal: true, pending: false)]
        )
    }

    @MainActor
    func testPixelRestoreBelongsToTheSameBookAndChapter() {
        var session = ReadingSession(bookId: "book-a", onScreen: true, offset: 120, chapterNumber: 3)
        let restore = ReaderScrollRestore.local(session: session, bookId: "book-a", chapter: 3)
        guard case let .offset(chapter, offset)? = restore else { return XCTFail("Expected a pixel restore") }
        XCTAssertEqual(chapter, 3)
        XCTAssertEqual(offset, 120)
        XCTAssertNil(ReaderScrollRestore.local(session: session, bookId: "book-b", chapter: 3))
        XCTAssertNil(ReaderScrollRestore.local(session: session, bookId: "book-a", chapter: 4))
        session.offset = 0
        XCTAssertNil(ReaderScrollRestore.local(session: session, bookId: "book-a", chapter: 3))
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
