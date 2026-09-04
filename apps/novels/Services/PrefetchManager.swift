import Foundation

// swiftlint:disable:next type_body_length
actor PrefetchManager {
    static let perChapterBudget: TimeInterval = 600
    static let globalBudget: TimeInterval = 1800

    private var task: Task<Void, Never>?
    private var generation = 0
    private var statusValue: PrefetchStatus = .idle

    func currentStatus() -> PrefetchStatus {
        statusValue
    }

    func cancel(reason: String = "manual") async {
        generation += 1
        task?.cancel()
        task = nil
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
        task?.cancel()
        task = nil
        guard mode != .none else {
            statusValue = .idle
            await logPrefetch(
                event: "prefetch.skip",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: "reason=modeNone"
            )
            return
        }
        guard totalChapters > 0, currentChapter >= 1, currentChapter <= totalChapters else {
            statusValue = .idle
            await logPrefetch(
                event: "prefetch.skip",
                bookId: bookId,
                chapterNumber: currentChapter,
                mode: mode.rawValue,
                detail: "reason=invalidRange"
            )
            return
        }
        let effectiveN: Int = await MainActor.run { settings.effectivePrefetchCount() }
        let end = min(currentChapter + effectiveN, totalChapters)
        let range: [Int] = (end > currentChapter) ? Array((currentChapter + 1) ... end) : []
        guard !range.isEmpty else {
            statusValue = PrefetchStatus(
                isRunning: false,
                currentBookId: bookId,
                totalChapters: 0,
                processedChapters: 0,
                message: "Đã hoàn tất",
                errors: []
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
        let cached: Set<Int> = (try? cache.batchStatus(bookId: bookId, mode: mode, numbers: range)) ?? []
        let misses = range.filter { !cached.contains($0) }
        await logPrefetch(
            event: "prefetch.batchCheck",
            bookId: bookId,
            chapterNumber: currentChapter,
            mode: mode.rawValue,
            detail: "rangeFrom=\(range.first ?? 0) rangeTo=\(range.last ?? 0) hit=\(range.count - misses.count) miss=\(misses.count)"
        )
        guard !misses.isEmpty else {
            statusValue = PrefetchStatus(
                isRunning: false,
                currentBookId: bookId,
                totalChapters: range.count,
                processedChapters: 0,
                message: "Đã hoàn tất (đã có cache)",
                errors: []
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
            isRunning: true,
            currentBookId: bookId,
            totalChapters: misses.count,
            processedChapters: 0,
            message: "Đang tải trước...",
            errors: []
        )
        generation += 1
        let currentGeneration = generation
        var createdTask: Task<Void, Never>!
        createdTask = Task {
            let batchStart = Date()
            var processed = 0
            var errors: [String] = []
            for number in misses {
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
                let raw = parsed.flatMap { $0.spans.map { $0.text } }.joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else {
                    errors.append("Chương \(number): Nội dung rỗng")
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
                    errors.append("Chương \(number): \(error.localizedDescription)")
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
            await self.finish(processed: processed, errors: errors, bookId: bookId, generation: currentGeneration)
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

    private func updateStatus(processed: Int, errors: [String], generation targetGeneration: Int) {
        guard generation == targetGeneration else { return }
        statusValue.processedChapters = processed
        statusValue.errors = errors
        statusValue.message = "Đang tải trước \(processed)/\(statusValue.totalChapters)"
    }

    private func finish(processed: Int, errors: [String], bookId: String, generation targetGeneration: Int) {
        guard generation == targetGeneration else { return }
        statusValue.isRunning = false
        statusValue.currentBookId = bookId
        statusValue.processedChapters = processed
        statusValue.errors = errors
        statusValue.message = errors.isEmpty ? "Đã hoàn tất" : "Hoàn tất với \(errors.count) lỗi"
    }

    private func clearTaskIfCurrent(generation targetGeneration: Int) {
        if generation == targetGeneration {
            task = nil
        }
    }
}
