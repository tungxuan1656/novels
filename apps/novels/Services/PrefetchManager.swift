import Foundation

// swiftlint:disable:next type_body_length
actor PrefetchManager {
    static let shared = PrefetchManager()
    static let perChapterBudget: TimeInterval = 600
    static let globalBudget: TimeInterval = 1800

    private var task: Task<Void, Never>?
    private var generation = 0
    private var statusValue: PrefetchStatus = .idle
    private var continuedUpdates: AsyncStream<PrefetchStatus>.Continuation?

    struct ContinuedBatch {
        let generation: Int
        let updates: AsyncStream<PrefetchStatus>
    }

    func protectCurrentBatch() -> ContinuedBatch? {
        guard statusValue.isRunning, task != nil, continuedUpdates == nil else { return nil }
        let (updates, continuation) = AsyncStream<PrefetchStatus>.makeStream()
        continuedUpdates = continuation
        continuation.yield(statusValue)
        return ContinuedBatch(generation: generation, updates: updates)
    }

    func releaseProtection(generation expectedGeneration: Int) {
        guard generation == expectedGeneration else { return }
        continuedUpdates?.finish()
        continuedUpdates = nil
    }

    /// FIFO per book/mode, reconciled across chapter navigation.
    private var activeBookId: String?
    private var activeMode: AIMode?
    private var pending: [Int] = []
    private var inFlight: Int?
    private var batchFinished = true
    private var bookEndRemaining: Int? // Window size when it reaches the book end (end-of-book message).
    /// At most one tail-requeue per chapter.
    private var attempts: [Int: Int] = [:]
    /// Reconciled-window counts for the existing batchCheck log detail.
    typealias WindowKept = (overlapKept: Int, topUpAdded: Int)

    func currentStatus() -> PrefetchStatus {
        statusValue
    }

    func cancel(
        reason: String = "manual", generation expectedGeneration: Int? = nil,
        unlessContinued: Bool = false
    ) async {
        guard expectedGeneration == nil || expectedGeneration == generation else { return }
        guard !unlessContinued || continuedUpdates == nil else { return }
        invalidateActiveBatch()
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

    // swiftlint:disable:next function_parameter_count function_body_length cyclomatic_complexity
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
        let requestedGeneration = generation
        let effectiveN: Int = await MainActor.run { settings.effectivePrefetchCount() }
        guard generation == requestedGeneration, !Task.isCancelled else { return }
        // N is validated by SettingsStore; the worker is sequential.
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
            // Do not turn a failed cache query into a bulk refetch.
            await logPrefetch(
                event: "prefetch.error-continue",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: "reason=cacheQueryFailed"
            )
            return
        }
        let storedN: Int = await MainActor.run { settings.prefetchCount }
        guard generation == requestedGeneration, !Task.isCancelled else { return }
        bookEndRemaining = bookEndCount(range: range, totalChapters: totalChapters)
        // Same book/mode: preserve overlap and append only missing tail.
        if activeBookId == bookId, activeMode == mode, task != nil, !batchFinished {
            let kept = ensureWindow(cur: currentChapter, appliedN: appliedN, total: totalChapters, misses: misses)
            // Recompute after reconcile; do not accumulate stale counts.
            statusValue.totalChapters = statusValue.processedChapters + pending.count + (inFlight == nil ? 0 : 1)
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
        // A new book/mode invalidates the old worker before publishing.
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
        guard generation == currentGeneration, !Task.isCancelled else { return }
        guard !misses.isEmpty else {
            // No worker exists for an all-cached window.
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
        task = Task {
            let batchStart = Date()
            var processed = 0
            var errors: [Int: String] = [:]
            var stoppedEarly = false
            // Chapter-sequential: shared queue so navigates can reconcile mid-run.
            while let number = self.nextChapter(generation: currentGeneration) {
                if Task.isCancelled {
                    await self.logCancel(
                        bookId: bookId,
                        chapterNumber: currentChapter,
                        mode: mode,
                        currentGeneration: currentGeneration,
                        reason: "chapterChange"
                    )
                    stoppedEarly = true
                    break
                }
                let bookExists = self.bookStillExists(bookId: bookId, repository: repository)
                if !bookExists {
                    await self.logPrefetch(
                        event: "prefetch.cancel",
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode.rawValue,
                        detail: "reason=bookDeleted"
                    )
                    stoppedEarly = true
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
                    stoppedEarly = true
                    break
                }
                let itemStart = Date()
                let runId = UUID()
                let htmlResult: String? = try? repository.chapterHTML(slug: bookId, number: number)
                guard let html = htmlResult else {
                    self.requeueOrRecord(
                        number: number,
                        message: "Chương \(number): Không tìm thấy chương",
                        errors: &errors,
                        generation: currentGeneration
                    )
                    self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
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
                let chapter = HtmlParser.parseChapter(html: html)
                let raw = chapter.body
                if raw.isEmpty, let parsedTitle = chapter.title, !parsedTitle.isEmpty {
                    errors[number] = nil
                    processed += 1
                    self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
                    continue
                }
                guard !raw.isEmpty else {
                    self.requeueOrRecord(
                        number: number,
                        message: "Chương \(number): Nội dung rỗng",
                        errors: &errors,
                        generation: currentGeneration
                    )
                    self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
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
                // processedContent checks cancellation before starting AI work.
                do {
                    _ = try await aiService.processedContent(
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode,
                        rawText: raw,
                        runId: runId,
                        source: "prefetch"
                    )
                    errors[number] = nil
                    if Date().timeIntervalSince(itemStart) > Self.perChapterBudget {
                        await self.logPrefetch(
                            event: "prefetch.cancel",
                            bookId: bookId,
                            chapterNumber: number,
                            mode: mode.rawValue,
                            detail: "reason=budgetExhausted scope=perChapter"
                        )
                        stoppedEarly = true
                        break
                    }
                    processed += 1
                    self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
                } catch is CancellationError {
                    await self.logCancel(
                        bookId: bookId,
                        chapterNumber: currentChapter,
                        mode: mode,
                        currentGeneration: currentGeneration,
                        reason: "chapterChange"
                    )
                    stoppedEarly = true
                    break
                } catch {
                    // Generation guards reject stale writes; retry once at the tail.
                    self.requeueOrRecord(
                        number: number,
                        message: "Chương \(number): \(error.localizedDescription)",
                        errors: &errors,
                        generation: currentGeneration
                    )
                    self.updateStatus(processed: processed, errors: errors, generation: currentGeneration)
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
            self.finish(
                processed: processed,
                errors: errors,
                bookId: bookId,
                generation: currentGeneration,
                stoppedEarly: stoppedEarly
            )
        }
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

    /// Throw on cache failure; never turn it into a bulk refetch.
    private func missList(cache: ProcessedChapterCaching, bookId: String, mode: AIMode, range: [Int]) throws -> [Int] {
        let cached = try cache.batchStatus(bookId: bookId, mode: mode, numbers: range)
        return range.filter { !cached.contains($0) }
    }

    /// End protection immediately, even if a shared AI request is still running.
    private func invalidateActiveBatch() {
        continuedUpdates?.finish()
        continuedUpdates = nil
        task?.cancel()
        task = nil
        generation += 1
        resetWindowState()
        batchFinished = true
    }

    /// Keep FIFO overlap and append only new misses, excluding the in-flight chapter.
    func ensureWindow(cur: Int, appliedN: Int, total: Int, misses: [Int]) -> WindowKept {
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

    /// Retry once at the tail, then record the failure and keep draining.
    func requeueOrRecord(number: Int, message: String, errors: inout [Int: String], generation targetGeneration: Int) {
        guard generation == targetGeneration, inFlight == number else { return }
        // Settle before logging can suspend and navigation reconciles the window.
        inFlight = nil
        if attempts[number, default: 0] < 1 {
            attempts[number, default: 0] += 1
            pending.append(number)
        } else {
            errors[number] = message
        }
    }

    /// Shared detail shape for the existing `prefetch.batchCheck` event.
    private func batchCheckDetail(range: [Int], misses: [Int], counts: String, extra: String) -> String {
        let base = "rangeFrom=\(range.first ?? 0) rangeTo=\(range.last ?? 0) hit=\(range.count - misses.count) miss=\(misses.count) \(counts)"
        return extra.isEmpty ? base : "\(base) \(extra)"
    }

    /// Pops the next queued chapter (nil when drained/superseded); popped = in flight.
    func nextChapter(generation targetGeneration: Int) -> Int? {
        guard generation == targetGeneration, !pending.isEmpty else { return nil }
        let number = pending.removeFirst()
        inFlight = number
        return number
    }

    private func updateStatus(processed: Int, errors: [Int: String], generation targetGeneration: Int) {
        guard generation == targetGeneration else { return }
        inFlight = nil
        statusValue.processedChapters = processed
        statusValue.errors = errors.sorted { $0.key < $1.key }.map(\.value)
        statusValue.message = "Đang tải trước \(processed)/\(statusValue.totalChapters)"
        continuedUpdates?.yield(statusValue)
    }

    private func finish(
        processed: Int,
        errors: [Int: String],
        bookId: String,
        generation targetGeneration: Int,
        stoppedEarly: Bool
    ) {
        guard generation == targetGeneration else { return }
        batchFinished = true
        task = nil
        resetWindowState()
        statusValue.isRunning = false
        statusValue.currentBookId = bookId
        statusValue.processedChapters = processed
        statusValue.errors = errors.sorted { $0.key < $1.key }.map(\.value)
        let tailMark = bookEndRemaining.map { " (còn \($0) chương cuối)" } ?? ""
        statusValue.message = stoppedEarly
            ? "Đã tạm dừng"
            : (errors.isEmpty ? "Đã hoàn tất" : "Hoàn tất với \(errors.count) lỗi") + tailMark
        continuedUpdates?.yield(statusValue)
        releaseProtection(generation: targetGeneration)
    }
}
