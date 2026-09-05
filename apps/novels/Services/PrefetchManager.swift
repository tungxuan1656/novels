import Foundation

// swiftlint:disable:next type_body_length
actor PrefetchManager {
    static let perChapterBudget: TimeInterval = 600
    static let globalBudget: TimeInterval = 1800
    /// Runtime window cap (feat-023 Phase 5, default 10): bounds the worst-case
    /// per-batch cost. The public 0...1000-else-3 policy is unchanged.
    static var hardCap = 10 // test-overridable; production default 10

    private var task: Task<Void, Never>?
    private var generation = 0
    private var statusValue: PrefetchStatus = .idle

    /// Sliding-window queue for the running batch (feat-023 Phase 4): same
    /// book+mode starts with non-empty overlap top up instead of restarting.
    private var activeBookId: String?
    private var activeMode: AIMode?
    private var pending: [Int] = []
    private var pendingSet: Set<Int> = []
    private var inFlight: Int?
    private var batchFinished = true
    private var bookEndRemaining: Int? // Window size when it reaches the book end (end-of-book message).
    /// Last finished batch's failures (same book+mode), first in next window.
    private var failedChapters: [Int] = []
    private var failedBookId: String?
    private var failedMode: AIMode?

    func currentStatus() -> PrefetchStatus {
        statusValue
    }

    func cancel(reason: String = "manual") async {
        generation += 1
        task?.cancel()
        task = nil
        resetWindowState()
        batchFinished = true
        statusValue.isRunning = false
        statusValue.message = "Đã hủy"
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: UUID(),
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            event: "prefetch.cancel",
            detail: "reason=\(reason)"
        ))
    }

    private func logPrefetch(
        event: String,
        bookId: String,
        chapterNumber: Int,
        mode: String,
        detail: String,
        runId: UUID? = nil
    ) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: UUID(),
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode,
            event: event,
            detail: detail,
            runId: runId
        ))
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    func start(
        bookId: String,
        currentChapter: Int,
        totalChapters: Int,
        mode: AIMode,
        settings: SettingsStore,
        cache: ProcessedChapterCaching,
        aiService: AIReadingService,
        repository: BookRepository
    ) async {
        guard mode != .none else {
            await skipAsIdle(bookId: bookId, chapterNumber: currentChapter, mode: mode, reason: "modeNone")
            return
        }
        guard totalChapters > 0, currentChapter >= 1, currentChapter <= totalChapters else {
            await skipAsIdle(bookId: bookId, chapterNumber: currentChapter, mode: mode, reason: "invalidRange")
            return
        }
        let effectiveN: Int = await MainActor.run { settings.effectivePrefetchCount() }
        let appliedN = min(effectiveN, Self.hardCap)
        let range = windowRange(currentChapter: currentChapter, effectiveN: appliedN, totalChapters: totalChapters)
        guard !range.isEmpty else {
            invalidateActiveBatch()
            statusValue = PrefetchStatus(
                isRunning: false, currentBookId: bookId, totalChapters: 0,
                processedChapters: 0, message: "Đã hoàn tất", errors: []
            )
            await logPrefetch(
                event: "prefetch.skip",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: "reason=emptyRange"
            )
            return
        }
        let misses: [Int]
        do {
            misses = try missList(cache: cache, bookId: bookId, mode: mode, range: range)
        } catch {
            // Query failure keeps prior state (never miss-all): log on the
            // existing error-continue event and return without touching the
            // running batch or status.
            await logPrefetch(
                event: "prefetch.error-continue",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: "reason=cacheQueryFailed"
            )
            return
        }
        // P-Important-1: assign AFTER the query succeeds — the early return
        // above must not mutate shared window state read by finish().
        bookEndRemaining = bookEndCount(range: range, totalChapters: totalChapters)
        // Log-only transparency fields (feat-023 Phase 3): storedN is raw stored,
        // effectiveN consumed, appliedCap runtime-bounded. No policy change.
        let storedN: Int = await MainActor.run { settings.prefetchCount }
        // Overlap-preserving top-up (feat-023 Phase 4): same book+mode with
        // non-empty overlap keeps the running batch; only new-tail misses append.
        if let topUp = topUpIfOverlapping(bookId: bookId, mode: mode, range: range, misses: misses) {
            statusValue.totalChapters += topUp.topUpAdded
            statusValue.currentBookId = bookId
            await logPrefetch(
                event: "prefetch.batchCheck",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: batchCheckDetail(
                    range: range,
                    misses: misses,
                    counts: "storedN=\(storedN) effectiveN=\(effectiveN) appliedCap=\(appliedN)",
                    extra: "reason=topUp overlapKept=\(topUp.overlapKept) topUpAdded=\(topUp.topUpAdded)"
                )
            )
            return
        }
        // Clean restart (new book/mode or far jump): bump + cancel so the
        // stale batch can no longer publish (testCancellationStopsRemaining).
        let failedFirst = takeFailedFirst(bookId: bookId, mode: mode, misses: misses)
        // Read BEFORE invalidating (it resets the failed store).
        invalidateActiveBatch()
        let currentGeneration = generation
        // Failed-first (feat-023 Phase 4); retry bound (<=1) comes from the
        // per-chunk attempt loop in AIClient — the manager never re-issues.
        let failedFirstSet = Set(failedFirst)
        let ordered = failedFirst + misses.filter { !failedFirstSet.contains($0) }
        pending = ordered
        pendingSet = Set(ordered)
        inFlight = nil
        activeBookId = bookId
        activeMode = mode
        batchFinished = false
        resetFailedState()
        failedBookId = bookId
        failedMode = mode
        await logPrefetch(
            event: "prefetch.batchCheck",
            bookId: bookId,
            chapterNumber: currentChapter,
            mode: mode.rawValue,
            detail: batchCheckDetail(
                range: range,
                misses: misses,
                counts: "storedN=\(storedN) effectiveN=\(effectiveN) appliedCap=\(appliedN)",
                extra: retryEnqueueExtra(failedFirst)
            )
        )
        guard !misses.isEmpty else {
            // P-Minor-a: no batch spawned here — mark finished so a stale task
            // can never satisfy the top-up keep invariant (task != nil).
            batchFinished = true
            statusValue = PrefetchStatus(
                isRunning: false, currentBookId: bookId, totalChapters: range.count,
                processedChapters: 0, message: "Đã hoàn tất (đã có cache)", errors: []
            )
            await logPrefetch(
                event: "prefetch.skip",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: "reason=allCached hit=\(range.count)"
            )
            return
        }
        statusValue = PrefetchStatus(
            isRunning: true, currentBookId: bookId, totalChapters: misses.count,
            processedChapters: 0, message: "Đang tải trước...", errors: []
        )
        var createdTask: Task<Void, Never>!
        createdTask = Task {
            let batchStart = Date()
            var processed = 0
            var errors: [String] = []
            var failedThisBatch: [Int] = []
            // Chapter-sequential: shared queue so top-ups can append mid-run.
            while let number = await self.nextChapter(generation: currentGeneration) {
                if Task.isCancelled {
                    await self.logCancel(
                        bookId: bookId,
                        chapterNumber: currentChapter,
                        mode: mode,
                        currentGeneration: currentGeneration,
                        reason: "chapterChange"
                    )
                    break
                }
                let bookExists = await self.bookStillExists(bookId: bookId, repository: repository)
                if !bookExists {
                    await self.logPrefetch(
                        event: "prefetch.cancel",
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode.rawValue,
                        detail: "reason=bookDeleted"
                    )
                    break
                }
                if Date().timeIntervalSince(batchStart) > Self.globalBudget {
                    await self.logPrefetch(
                        event: "prefetch.cancel",
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode.rawValue,
                        detail: "reason=budgetExhausted scope=global"
                    )
                    break
                }
                let itemStart = Date()
                let runId = UUID()
                let htmlResult: String? = try? repository.chapterHTML(slug: bookId, number: number)
                guard let html = htmlResult else {
                    errors.append("Chương \(number): Không tìm thấy chương")
                    failedThisBatch.append(number)
                    await self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
                    await self.logPrefetch(
                        event: "prefetch.error-continue",
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode.rawValue,
                        detail: "reason=missingChapter",
                        runId: runId
                    )
                    continue
                }
                let parsed: [TextBlock] = HtmlParser.parse(html: html)
                let joined = parsed.map { $0.spans.map { $0.text }.joined() }.joined(separator: "\n\n")
                var normalized = joined.replacingOccurrences(
                    of: "[ \\t]*\\n[ \\t]*",
                    with: "\n",
                    options: .regularExpression
                )
                normalized = normalized.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
                let raw = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else {
                    errors.append("Chương \(number): Nội dung rỗng")
                    failedThisBatch.append(number)
                    await self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
                    await self.logPrefetch(
                        event: "prefetch.error-continue",
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode.rawValue,
                        detail: "reason=emptyContent",
                        runId: runId
                    )
                    continue
                }
                // No extra cancel check here: a cancelled task throws
                // CancellationError from processedContent below (same
                // logCancel + break), and the loop-top check stops the rest.
                do {
                    _ = try await aiService.processedContent(
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode,
                        rawText: raw,
                        runId: runId
                    )
                    if Date().timeIntervalSince(itemStart) > Self.perChapterBudget {
                        await self.logPrefetch(
                            event: "prefetch.cancel",
                            bookId: bookId,
                            chapterNumber: number,
                            mode: mode.rawValue,
                            detail: "reason=budgetExhausted scope=perChapter"
                        )
                        break
                    }
                    processed += 1
                    await self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
                } catch is CancellationError {
                    await self.logCancel(
                        bookId: bookId,
                        chapterNumber: currentChapter,
                        mode: mode,
                        currentGeneration: currentGeneration,
                        reason: "chapterChange"
                    )
                    break
                } catch {
                    // No Task.isCancelled fork here: a stale batch cannot
                    // publish (finish/updateStatus are generation-guarded) and
                    // the loop-top check breaks next iteration. The failure is
                    // recorded once for failed-first in the next window.
                    errors.append("Chương \(number): \(error.localizedDescription)")
                    failedThisBatch.append(number)
                    await self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
                    await self.logPrefetch(
                        event: "prefetch.error-continue",
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode.rawValue,
                        detail: "reason=aiError",
                        runId: runId
                    )
                    continue
                }
            }
            await self.finish(
                processed: processed,
                errors: errors,
                failed: failedThisBatch,
                bookId: bookId,
                generation: currentGeneration
            )
            await self.clearTaskIfCurrent(generation: currentGeneration)
        }
        task = createdTask
    }

    private func logCancel(
        bookId: String,
        chapterNumber: Int,
        mode: AIMode,
        currentGeneration: Int,
        reason: String
    ) async {
        _ = currentGeneration
        await logPrefetch(
            event: "prefetch.cancel",
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode.rawValue,
            detail: "reason=\(reason)"
        )
    }

    private func bookStillExists(bookId: String, repository: BookRepository) -> Bool {
        (try? repository.book(slug: bookId)) != nil
    }

    private func resetWindowState() {
        pending = []
        pendingSet = []
        inFlight = nil
        activeBookId = nil
        activeMode = nil
    }

    private func resetFailedState() {
        failedChapters = []
        failedBookId = nil
        failedMode = nil
    }

    /// Shared idle-skip exit (mode none / invalid range): invalidate, publish idle, log skip.
    private func skipAsIdle(bookId: String, chapterNumber: Int, mode: AIMode, reason: String) async {
        invalidateActiveBatch()
        statusValue = .idle
        await logPrefetch(
            event: "prefetch.skip",
            bookId: bookId,
            chapterNumber: chapterNumber,
            mode: mode.rawValue,
            detail: "reason=\(reason)"
        )
    }

    /// Window of chapters after the current one, bounded by the book end.
    private func windowRange(currentChapter: Int, effectiveN: Int, totalChapters: Int) -> [Int] {
        let end = min(currentChapter + effectiveN, totalChapters)
        return (end > currentChapter) ? Array((currentChapter + 1) ... end) : []
    }

    /// Window size when it reaches the book end, for the end-of-book message.
    private func bookEndCount(range: [Int], totalChapters: Int) -> Int? {
        range.last == totalChapters ? range.count : nil
    }

    /// Cache-backed miss list; on query failure logs and returns nil so the
    /// caller keeps prior state instead of refetching as miss-all.
    private func missList(cache: ProcessedChapterCaching, bookId: String, mode: AIMode, range: [Int]) throws -> [Int] {
        let cached = try cache.batchStatus(bookId: bookId, mode: mode, numbers: range)
        return range.filter { !cached.contains($0) }
    }

    /// Cancels any running batch and invalidates its window state, so a stale
    /// batch can no longer publish. Used on restart and on early exits.
    private func invalidateActiveBatch() {
        task?.cancel()
        task = nil
        generation += 1
        resetWindowState()
        resetFailedState()
        batchFinished = true
    }

    /// Overlap top-up (Phase 4): running batch + overlap keeps task; nil to restart.
    private func topUpIfOverlapping(
        bookId: String,
        mode: AIMode,
        range: [Int],
        misses: [Int]
    ) -> (overlapKept: Int, topUpAdded: Int)? {
        guard task != nil, !batchFinished else { return nil }
        guard activeBookId == bookId, activeMode == mode else { return nil }
        var windowSet = pendingSet
        if let running = inFlight {
            windowSet.insert(running)
        }
        let overlap = range.filter { windowSet.contains($0) }
        guard !overlap.isEmpty else { return nil }
        let freshTail = misses.filter { !windowSet.contains($0) }
        pending.append(contentsOf: freshTail)
        pendingSet.formUnion(freshTail)
        return (overlap.count, freshTail.count)
    }

    /// Failed chapters of the last finished batch for this book+mode, restricted to the new misses.
    private func takeFailedFirst(bookId: String, mode: AIMode, misses: [Int]) -> [Int] {
        guard failedBookId == bookId, failedMode == mode else { return [] }
        return failedChapters.filter { misses.contains($0) }
    }

    /// retry-enqueue fragment for batchCheck when failed-first applies.
    private func retryEnqueueExtra(_ failedFirst: [Int]) -> String {
        guard !failedFirst.isEmpty else { return "" }
        return "failedFirst=\(failedFirst.count) retry-enqueue=\(failedFirst)"
    }

    /// Shared detail shape for the existing `prefetch.batchCheck` event.
    private func batchCheckDetail(range: [Int], misses: [Int], counts: String, extra: String) -> String {
        let base = "rangeFrom=\(range.first ?? 0) rangeTo=\(range.last ?? 0) hit=\(range.count - misses.count) miss=\(misses.count) \(counts)"
        return extra.isEmpty ? base : "\(base) \(extra)"
    }

    /// Pops the next queued chapter (nil when drained/superseded); popped = in flight.
    private func nextChapter(generation targetGeneration: Int) -> Int? {
        guard generation == targetGeneration, !pending.isEmpty else { return nil }
        let number = pending.removeFirst()
        pendingSet.remove(number)
        inFlight = number
        return number
    }

    private func updateStatus(processed: Int, errors: [String], generation targetGeneration: Int) {
        guard generation == targetGeneration else { return }
        statusValue.processedChapters = processed
        statusValue.errors = errors
        statusValue.message = "Đang tải trước \(processed)/\(statusValue.totalChapters)"
    }

    private func finish(
        processed: Int,
        errors: [String],
        failed: [Int],
        bookId: String,
        generation targetGeneration: Int
    ) {
        guard generation == targetGeneration else { return }
        failedChapters = failed
        batchFinished = true
        resetWindowState()
        statusValue.isRunning = false
        statusValue.currentBookId = bookId
        statusValue.processedChapters = processed
        statusValue.errors = errors
        let tailMark = bookEndRemaining.map { " (còn \($0) chương cuối)" } ?? ""
        statusValue.message = (errors.isEmpty ? "Đã hoàn tất" : "Hoàn tất với \(errors.count) lỗi") + tailMark
    }

    private func clearTaskIfCurrent(generation targetGeneration: Int) {
        if generation == targetGeneration {
            task = nil
        }
    }
}
