@testable import novels
import XCTest

@MainActor
final class ReaderViewFixTests: XCTestCase {
    // MARK: - Overscroll only at bottom

    func testOverscrollNotFiringAtTop() {
        // Scrolled 40pt from top should not trigger bottom logic
        let offsetY: CGFloat = -40
        let contentHeight: CGFloat = 2000
        let viewportHeight: CGFloat = 800
        XCTAssertFalse(ReaderOverscrollLogic.isNearBottom(
            offsetY: offsetY,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        ))
    }

    func testOverscrollNotFiringMidContent() {
        // Mid scroll not near bottom
        let offsetY: CGFloat = -600
        let contentHeight: CGFloat = 2000
        let viewportHeight: CGFloat = 800
        // content - viewport = 1200, threshold 40 => near bottom when y < -(1200-40)= -1160
        XCTAssertFalse(ReaderOverscrollLogic.isNearBottom(
            offsetY: offsetY,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        ))
    }

    func testOverscrollFiresNearBottom() {
        let contentHeight: CGFloat = 2000
        let viewportHeight: CGFloat = 800
        // Just before bottom (within 40) should be near bottom
        let nearBottomY: CGFloat = -(contentHeight - viewportHeight - 20) // -1180
        XCTAssertTrue(ReaderOverscrollLogic.isNearBottom(
            offsetY: nearBottomY,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        ))
    }

    func testOverscrollBeyondBottomRequiresGeometry() {
        // Need both heights >0 and content > viewport
        XCTAssertFalse(ReaderOverscrollLogic.isNearBottom(offsetY: -2000, contentHeight: 0, viewportHeight: 800))
        XCTAssertFalse(ReaderOverscrollLogic.isNearBottom(offsetY: -2000, contentHeight: 500, viewportHeight: 800))
        XCTAssertFalse(ReaderOverscrollLogic.isNearBottom(offsetY: -2000, contentHeight: 800, viewportHeight: 800))
    }

    func testOverscrolledBeyondBottomThreshold() {
        let contentHeight: CGFloat = 2000
        let viewportHeight: CGFloat = 800
        // True overscroll beyond bottom +40
        let beyondY: CGFloat = -(contentHeight - viewportHeight + 50) // -1250
        XCTAssertTrue(ReaderOverscrollLogic.isOverscrolledBeyondBottom(
            offsetY: beyondY,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        ))
        let notBeyond: CGFloat = -(contentHeight - viewportHeight + 20)
        XCTAssertFalse(ReaderOverscrollLogic.isOverscrolledBeyondBottom(
            offsetY: notBeyond,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        ))
    }

    // MARK: - Offset restore per-book

    func testOffsetRestorePerBookMatch() {
        let offset = ReaderOffsetRestore.offsetToRestore(
            sessionBookId: "book-a",
            sessionOffset: 123.4,
            currentBookId: "book-a"
        )
        XCTAssertEqual(offset, 123.4)
    }

    func testOffsetRestorePerBookMismatch() {
        let offset = ReaderOffsetRestore.offsetToRestore(
            sessionBookId: "book-a",
            sessionOffset: 123.4,
            currentBookId: "book-b"
        )
        XCTAssertNil(offset)
    }

    func testOffsetRestoreZeroOrNil() {
        XCTAssertNil(ReaderOffsetRestore.offsetToRestore(
            sessionBookId: "book-a",
            sessionOffset: 0,
            currentBookId: "book-a"
        ))
        XCTAssertNil(ReaderOffsetRestore.offsetToRestore(
            sessionBookId: nil,
            sessionOffset: 42,
            currentBookId: "book-a"
        ))
        XCTAssertNil(ReaderOffsetRestore.offsetToRestore(
            sessionBookId: "book-a",
            sessionOffset: nil,
            currentBookId: "book-a"
        ))
    }

    // MARK: - Font picker visual effect

    func testFontDesignMapping() {
        XCTAssertEqual(ReaderFontDesign.design(for: "System"), .default)
        XCTAssertEqual(ReaderFontDesign.design(for: "Serif"), .serif)
        XCTAssertEqual(ReaderFontDesign.design(for: "Mono"), .monospaced)
        // Unknown falls back to default
        XCTAssertEqual(ReaderFontDesign.design(for: "Unknown"), .default)
        XCTAssertEqual(ReaderFontDesign.design(for: ""), .default)
    }

    // MARK: - Debounce saveOffset

    func testDebounceCoalescesCalls() async {
        // Simulate debounceTask pattern used in ReaderView
        final class Counter: @unchecked Sendable {
            var count = 0
            var lastValue: Double = 0
            func save(_ value: Double) {
                count += 1
                lastValue = value
            }
        }
        let counter = Counter()
        var task: Task<Void, Never>?
        func debouncedSave(_ offset: Double) {
            task?.cancel()
            task = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { counter.save(offset) }
            }
        }
        debouncedSave(1)
        debouncedSave(2)
        debouncedSave(3)
        // Before debounce interval, no save yet
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(counter.count, 0)
        // After interval, only last value saved once
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(counter.lastValue, 3)
        task?.cancel()
    }

    func testDebounceCancelOnDisappear() async {
        final class Counter: @unchecked Sendable {
            var count = 0
            func save(_ value: Double) {
                count += 1
            }
        }
        let counter = Counter()
        var task: Task<Void, Never>?
        func debouncedSave(_ offset: Double) {
            task?.cancel()
            task = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { counter.save(offset) }
            }
        }
        debouncedSave(42)
        task?.cancel()
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(counter.count, 0)
    }
}
