@testable import novels
import XCTest

@MainActor
final class ReaderViewFixTests: XCTestCase {
    private let width: CGFloat = 400

    // MARK: - Edge swipe: happy paths (screen thirds)

    func testLeftEdgeSwipeRightGoesPrev() {
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: 10, width: width, dx: 80, dy: 10),
            .prev
        )
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: 100, width: width, dx: 60, dy: 0),
            .prev
        )
        // Boundary: exactly one third still counts as left third
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: width / 3, width: width, dx: 60, dy: 0),
            .prev
        )
    }

    func testRightEdgeSwipeLeftGoesNext() {
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: 390, width: width, dx: -80, dy: -10),
            .next
        )
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: 300, width: width, dx: -60, dy: 0),
            .next
        )
        // Boundary: exactly two thirds still counts as right third
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: width * 2 / 3, width: width, dx: -60, dy: 0),
            .next
        )
    }

    func testEdgeConstants() {
        XCTAssertEqual(EdgeSwipeDecision.minimumDistance, 60)
        XCTAssertEqual(EdgeSwipeDecision.directionRatio, 2)
        XCTAssertEqual(EdgeSwipeDecision.throttleInterval, 0.6, accuracy: 0.001)
    }

    // MARK: - Edge swipe: ignored gestures

    func testWrongDirectionInEdgeIgnored() {
        // Left third but swiping left is not prev
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: width, dx: -80, dy: 0))
        // Right third but swiping right is not next
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 390, width: width, dx: 80, dy: 0))
    }

    func testDiagonalIgnored() {
        // |dx| must be strictly greater than 2*|dy|
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: width, dx: 70, dy: 40))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 390, width: width, dx: -70, dy: 40))
        // Boundary: 60 is not > 2*30
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: width, dx: 60, dy: 30))
        // Just over the ratio fires
        XCTAssertEqual(
            EdgeSwipeDecision.decision(startX: 10, width: width, dx: 61, dy: 30),
            .prev
        )
    }

    func testShortSwipeIgnored() {
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: width, dx: 59, dy: 0))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 390, width: width, dx: -59, dy: 0))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: width, dx: 0, dy: 0))
    }

    func testMiddleSwipeIgnored() {
        // Middle third ignores both directions
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 200, width: width, dx: 120, dy: 0))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 200, width: width, dx: -120, dy: 0))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 140, width: width, dx: 120, dy: 0))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 260, width: width, dx: -120, dy: 0))
    }

    func testJustOutsideThirdIgnored() {
        // Just past the left third is middle: swipe right ignored
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 140, width: width, dx: 80, dy: 0))
        // Just before the right third is middle: swipe left ignored
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 260, width: width, dx: -80, dy: 0))
    }

    func testVerticalSwipeIgnored() {
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: width, dx: 10, dy: 200))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 390, width: width, dx: -10, dy: -200))
    }

    func testInvalidWidthIgnored() {
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: 0, dx: 80, dy: 0))
        XCTAssertNil(EdgeSwipeDecision.decision(startX: 10, width: -100, dx: 80, dy: 0))
    }

    // MARK: - Throttle (bound against double-fire)

    func testThrottleBlocksRapidSwitch() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertTrue(EdgeSwipeDecision.isThrottleOk(
            now: now,
            lastSwitch: Date(timeIntervalSinceReferenceDate: 999.3)
        ))
        XCTAssertFalse(EdgeSwipeDecision.isThrottleOk(
            now: now,
            lastSwitch: Date(timeIntervalSinceReferenceDate: 999.5)
        ))
        XCTAssertTrue(EdgeSwipeDecision.isThrottleOk(now: now, lastSwitch: .distantPast))
    }

    func testThrottleDefaultIntervalIs600ms() {
        let now = Date(timeIntervalSinceReferenceDate: 2000)
        // Just under 600ms ago -> blocked (margin avoids binary floating-point boundary flake)
        XCTAssertFalse(EdgeSwipeDecision.isThrottleOk(
            now: now,
            lastSwitch: now.addingTimeInterval(-0.59)
        ))
        // Just over 600ms ago -> allowed
        XCTAssertTrue(EdgeSwipeDecision.isThrottleOk(
            now: now,
            lastSwitch: now.addingTimeInterval(-0.61)
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

// MARK: - feat-018 Tasks 4-5: header-only spinner, sheet no spinner

final class ReaderHeaderSpinnerTests: XCTestCase {
    private func repoRoot() -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        var current = fileURL.deletingLastPathComponent()
        for _ in 0 ..< 6 {
            let candidate = current.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return fileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        let root = repoRoot()
        let candidate = root.appendingPathComponent(relative)
        let path = FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : relative
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    private func stripped(_ text: String) -> String {
        var result = text
        if let regex = try? NSRegularExpression(
            pattern: "/\\*.*?\\*/",
            options: [.dotMatchesLineSeparators]
        ) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        let lines = result.components(separatedBy: "\n")
        let withoutLineComments = lines.map { line -> String in
            if let range = line.range(of: "//") {
                return String(line[..<range.lowerBound])
            }
            return line
        }
        return withoutLineComments.joined(separator: "\n")
    }

    func testHeaderSpinnerOnlyForCurrentChapter() throws {
        let src = try source("apps/novels/Features/Reading/ReaderView.swift")
        let code = stripped(src)
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"aiProgressHeader\")"))
        XCTAssertTrue(code.contains("accessibilityLabel(\"Đang xử lý\")"))
        XCTAssertTrue(code.contains("scaleEffect(0.7)"))
        XCTAssertTrue(code.contains("frame(width: 22, height: 28)"))
        XCTAssertTrue(code.contains("if viewModel.isAIProcessing"))
        XCTAssertTrue(code.contains("Text(\"Đang xử lý\")"))
        XCTAssertTrue(code.contains(".font(.caption)"))
        XCTAssertTrue(code.contains(".lineLimit(1)"))
        XCTAssertTrue(code.contains(".frame(height: 28)"))
        XCTAssertFalse(code.contains("accessibilityIdentifier(\"aiProgress\")"))
        XCTAssertFalse(code.contains("accessibilityIdentifier(\"prefetchStatus\")"))
        XCTAssertFalse(code.contains("accessibilityIdentifier(\"prefetchStatusError\")"))
        XCTAssertTrue(code.contains("Không tìm thấy chương"))
    }

    func testHeaderProcessingTextGatedByCurrentChapter() throws {
        let src = try source("apps/novels/Features/Reading/ReaderView.swift")
        let code = stripped(src)
        XCTAssertEqual(code.components(separatedBy: "Text(\"Đang xử lý\")").count - 1, 1)
        XCTAssertEqual(code.components(separatedBy: "aiProgressHeader").count - 1, 1)
        guard let gate = code.range(of: "if viewModel.isAIProcessing"),
              let text = code.range(of: "Text(\"Đang xử lý\")"),
              let capsule = code.range(of: "accessibilityIdentifier(\"prevButton\")")
        else {
            XCTFail("missing gate/text/capsule ordering markers")
            return
        }
        XCTAssertTrue(gate.lowerBound < text.lowerBound && text.lowerBound < capsule.lowerBound)
    }

    func testPrefetchRunningShowsNoSpinner() throws {
        let src = try source("apps/novels/Features/Reading/ReaderView.swift")
        let code = stripped(src)
        XCTAssertFalse(code.contains("prefetchStatus"))
        XCTAssertFalse(code.contains("Đang tải trước"))
        XCTAssertFalse(code.contains("Tải trước:"))
    }

    func testBottomSheetHasNoLoadingIndicator() throws {
        let src = try source("apps/novels/Features/Reading/ReaderBottomSheet.swift")
        let code = stripped(src)
        XCTAssertFalse(code.contains("accessibilityIdentifier(\"aiProgress\")"))
        XCTAssertFalse(code.contains("ProgressView()"))
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"aiModePicker\")"))
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"reprocessButton\")"))
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"apiLogButton\")"))
        XCTAssertTrue(code.contains("disabled(viewModel.aiMode == .none || viewModel.isAIProcessing)"))
        XCTAssertTrue(code.contains("Button(\"Xử lý lại\")"))
    }
}
