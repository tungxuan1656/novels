import Foundation

// swiftlint:disable:next type_body_length
actor PrefetchManager {
    static let perChapterBudget: TimeInterval = 600
    static let globalBudget: TimeInterval = 1800

    private var task: Task<Void, Never>?
    private var generation = 0
    private var statusValue: PrefetchStatus = .idle

    /// Durable FIFO queue for the running batch (feat-024 Phase 1): same
    /// book+mode starts keep the running task (keep ∩ + append tail); cancel
    /// happens only on book/mode change, explicit cancel, or deletion.
    private var activeBookId: String?
    private var activeMode: AIMode?
    private var pending: [Int] = []
    private var inFlight: Int?
    private var batchFinished = true
    private var bookEndRemaining: Int? // Window size when it reaches the book end (end-of-book message).
    /// Per-chapter tail-requeue attempts in the live queue (default 0);
    /// a chapter is requeued at most once, then recorded and dropped.
    private var attempts: [Int: Int] = [:]
    /// Reconciled-window counts for the existing batchCheck log detail.
    typealias WindowKept = (overlapKept: Int, topUpAdded: Int)

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
        // feat-024 Phase 3 (single N): no runtime hardCap; the public
        // 0...1000-else-3 policy is the only bound, paced sequentially.
        let appliedN = effectiveN
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
        // Log-only transparency fields (feat-024 Phase 3 single N): storedN is
        // raw stored, effectiveN is the single consumed N. No runtime cap.
        let storedN: Int = await MainActor.run { settings.prefetchCount }
        // Overlap-preserving top-up (feat-024 Phase 1 queue): same book+mode
        // with a running batch keeps the task; the window is reconciled
        // (keep ∩ + append tail) instead of restarting.
        if activeBookId == bookId, activeMode == mode, task != nil, !batchFinished {
            let kept = ensureWindow(cur: currentChapter, appliedN: appliedN, total: totalChapters, misses: misses)
            statusValue.totalChapters += kept.topUpAdded
            statusValue.currentBookId = bookId
            await logPrefetch(
                event: "prefetch.batchCheck",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: batchCheckDetail(
                    range: range,
                    misses: misses,
                    counts: "storedN=\(storedN) effectiveN=\(effectiveN)",
                    extra: "reason=topUp overlapKept=\(kept.overlapKept) topUpAdded=\(kept.topUpAdded)"
                )
            )
            return
        }
        // Clean restart (new book/mode): cancel + bump so the stale batch
        // can no longer publish (testCancellationStopsRemaining).
        invalidateActiveBatch()
        let currentGeneration = generation
        pending = misses
        inFlight = nil
        activeBookId = bookId
        activeMode = mode
        batchFinished = false
        await logPrefetch(
            event: "prefetch.batchCheck",
            bookId: bookId,
            chapterNumber: currentChapter,
            mode: mode.rawValue,
            detail: batchCheckDetail(
                range: range,
                misses: misses,
                counts: "storedN=\(storedN) effectiveN=\(effectiveN)",
                extra: ""
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
            // Chapter-sequential: shared queue so navigates can reconcile mid-run.
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
                    await self.requeueOrRecord(
                        number: number,
                        message: "Chương \(number): Không tìm thấy chương",
                        errors: &errors
                    )
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
                    await self.requeueOrRecord(
                        number: number,
                        message: "Chương \(number): Nội dung rỗng",
                        errors: &errors
                    )
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
                    // requeued at the tail at most once, then recorded.
                    await self.requeueOrRecord(
                        number: number,
                        message: "Chương \(number): \(error.localizedDescription)",
                        errors: &errors
                    )
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
        inFlight = nil
        activeBookId = nil
        activeMode = nil
        attempts = [:]
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
        batchFinished = true
    }

    /// FIFO window reconcile (feat-024 Phase 1): keep queued chapters inside
    /// the new window, append only new-tail misses. Membership is rebuilt
    /// from `pending` plus `inFlight` (no separate stored set to drift).
    /// Returns kept/added counts for the existing batchCheck log detail.
    private func ensureWindow(cur: Int, appliedN: Int, total: Int, misses: [Int]) -> WindowKept {
        let range = windowRange(currentChapter: cur, effectiveN: appliedN, totalChapters: total)
        let window = Set(range)
        var kept = Set(pending)
        if let running = inFlight {
            kept.insert(running)
        }
        let overlapKept = range.filter { kept.contains($0) }.count
        let freshTail = misses.filter { !kept.contains($0) && $0 != inFlight }
        pending = pending.filter { window.contains($0) } + freshTail
        return (overlapKept, freshTail.count)
    }

    /// Tail-requeue bound (feat-024 Phase 1): a failed chapter returns to the
    /// queue tail at most once; afterwards it is recorded in errors[] and
    /// dropped so the worker keeps draining FIFO.
    private func requeueOrRecord(number: Int, message: String, errors: inout [String]) {
        if attempts[number, default: 0] < 1 {
            attempts[number, default: 0] += 1
            pending.append(number)
        } else {
            errors.append(message)
        }
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
        bookId: String,
        generation targetGeneration: Int
    ) {
        guard generation == targetGeneration else { return }
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
