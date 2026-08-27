import Foundation

actor PrefetchManager {
    private var task: Task<Void, Never>?
    private var generation = 0
    private var statusValue: PrefetchStatus = .idle

    func currentStatus() -> PrefetchStatus {
        statusValue
    }

    func cancel() {
        task?.cancel()
        task = nil
        statusValue.isRunning = false
        statusValue.message = "Đã hủy"
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
            return
        }
        guard totalChapters > 0, currentChapter >= 1, currentChapter <= totalChapters else {
            statusValue = .idle
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
            return
        }
        let cached: Set<Int> = (try? cache.batchStatus(bookId: bookId, mode: mode, numbers: range)) ?? []
        let misses = range.filter { !cached.contains($0) }
        guard !misses.isEmpty else {
            statusValue = PrefetchStatus(
                isRunning: false,
                currentBookId: bookId,
                totalChapters: range.count,
                processedChapters: 0,
                message: "Đã hoàn tất (đã có cache)",
                errors: []
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
            var processed = 0
            var errors: [String] = []
            for number in misses {
                if Task.isCancelled {
                    break
                }
                let exists = await self.bookStillExists(bookId: bookId, repository: repository)
                if !exists {
                    break
                }
                if Task.isCancelled {
                    break
                }
                let htmlResult: String? = try? repository.chapterHTML(slug: bookId, number: number)
                guard let html = htmlResult else {
                    // distinguish book deleted vs missing chapter
                    let bookExists = await self.bookStillExists(bookId: bookId, repository: repository)
                    if !bookExists {
                        break
                    }
                    errors.append("Chương \(number): Không tìm thấy chương")
                    await self.updateStatus(processed: processed, errors: errors)
                    continue
                }
                let parsed: [TextBlock] = HtmlParser.parse(html: html)
                let raw = parsed.flatMap { $0.spans.map { $0.text } }.joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else {
                    errors.append("Chương \(number): Nội dung rỗng")
                    await self.updateStatus(processed: processed, errors: errors)
                    continue
                }
                if Task.isCancelled {
                    break
                }
                do {
                    _ = try await aiService.processedContent(
                        bookId: bookId,
                        chapterNumber: number,
                        mode: mode,
                        rawText: raw
                    )
                    processed += 1
                    await self.updateStatus(processed: processed, errors: errors)
                } catch is CancellationError {
                    break
                } catch {
                    if Task.isCancelled {
                        break
                    }
                    errors.append("Chương \(number): \(error.localizedDescription)")
                    await self.updateStatus(processed: processed, errors: errors)
                    continue
                }
            }
            await self.finish(processed: processed, errors: errors, bookId: bookId)
            await self.clearTaskIfCurrent(generation: currentGeneration)
        }
        task = createdTask
    }

    private func bookStillExists(bookId: String, repository: BookRepository) -> Bool {
        (try? repository.book(slug: bookId)) != nil
    }

    private func updateStatus(processed: Int, errors: [String]) {
        statusValue.processedChapters = processed
        statusValue.errors = errors
        statusValue.message = "Đang tải trước \(processed)/\(statusValue.totalChapters)"
    }

    private func finish(processed: Int, errors: [String], bookId: String) {
        statusValue.isRunning = false
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
