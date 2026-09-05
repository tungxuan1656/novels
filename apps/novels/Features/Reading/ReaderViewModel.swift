import Foundation
import Observation

/// Load trigger: `.chapterChange` may start current-chapter AI + prefetch.
/// `.returnFromLog` (back from Log) makes zero current-chapter API calls but
/// resyncs prefetch status once and resumes background prefetch on misses.
enum LoadSource {
    case chapterChange
    case returnFromLog
}

@MainActor
@Observable
// swiftlint:disable:next type_body_length
final class ReaderViewModel {
    let bookId: String
    private let repository: BookRepository
    private let settingsStore: SettingsStore
    private let toastCenter: ToastCenter?
    var book: Book?
    var chapterNumber: Int = 1
    var blocks: [TextBlock] = []
    // Start as loading so the first frame shows an indicator instead of
    // flashing "Không tìm thấy chương" before load() runs.
    var isLoading = true
    var errorMessage: String?
    var aiMode: AIMode = .none
    var processedContent: String?
    var isAIProcessing = false
    var aiError: String?
    private var aiService: AIReadingService?
    private var aiTask: Task<Void, Never>?
    /// Stale-write guard: bumped synchronously on every entry that changes the
    /// displayed chapter/mode. Post-await AI writes must match it or drop.
    private var aiGeneration = 0
    /// Identity of the currently held AI text (nil when none/failed).
    /// The view renders `processedContent` only when it matches the visible
    /// chapter + mode (see `isProcessedContentCurrent()`).
    private var processedChapterNumber: Int?
    private var processedAIMode: AIMode?
    /// Debug mirror of manager batch state — do NOT bind Reader UI to this
    /// (header stays on `isAIProcessing`). Deletion deferred to roadmap.
    var prefetchStatus: PrefetchStatus = .idle
    private let prefetchManager: PrefetchManager
    /// Ordered disappear-cancel joined by the next `.returnFromLog` resync.
    private var disappearCancelTask: Task<Void, Never>?
    private let processedCache: ProcessedChapterCaching
    private(set) var lastVisibleChapter: Int?
    private(set) var lastVisibleMode: AIMode?
    var canGoPrev: Bool {
        chapterNumber > 1
    }

    var canGoNext: Bool {
        (book?.count ?? 1) > chapterNumber
    }

    init(
        bookId: String,
        repository: BookRepository,
        settingsStore: SettingsStore,
        toastCenter: ToastCenter? = nil,
        cache: ProcessedChapterCaching? = nil,
        aiService: AIReadingService? = nil,
        prefetchManager: PrefetchManager? = nil
    ) {
        self.bookId = bookId
        self.repository = repository
        self.settingsStore = settingsStore
        self.toastCenter = toastCenter
        self.prefetchManager = prefetchManager ?? PrefetchManager()
        let resolvedCache: ProcessedChapterCaching = cache ?? {
            if let fileCache = try? SQLiteProcessedChapterCache() {
                return fileCache
            }
            if let mem = try? SQLiteProcessedChapterCache.inMemory() {
                return mem
            }
            fatalError("Unable to create ProcessedChapter cache")
        }()
        processedCache = resolvedCache
        aiMode = settingsStore.aiMode
        if let session = settingsStore.session, session.bookId == bookId {
            chapterNumber = max(1, session.chapterNumber)
        }
        if let service = aiService {
            self.aiService = service
        } else {
            let client = AIClient(settings: settingsStore)
            self.aiService = AIReadingService(cache: resolvedCache, client: client, settings: settingsStore)
        }
    }

    func load(source: LoadSource = .chapterChange) async {
        if source == .chapterChange {
            // Invalidate in-flight AI work. Nil out only when the held text
            // does not already belong here: same-chapter reloads (reselect)
            // keep showing current content instead of flashing empty.
            aiGeneration += 1
            if processedChapterNumber != chapterNumber || processedAIMode != aiMode {
                processedContent = nil
                processedChapterNumber = nil
                processedAIMode = nil
            }
        }
        isLoading = true
        errorMessage = nil
        do {
            book = try repository.book(slug: bookId)
        } catch {
            book = nil
        }
        if let count = book?.count, count > 0 {
            chapterNumber = min(max(1, chapterNumber), count)
        } else if chapterNumber < 1 {
            chapterNumber = 1
        }
        let html = readChapterHTML(number: chapterNumber)
        if let html {
            blocks = HtmlParser.parse(html: html)
        } else {
            errorMessage = "Không tìm thấy chương"
            toastCenter?.show("Không tìm thấy chương", type: .error)
            blocks = []
        }
        isLoading = false
        if source == .returnFromLog {
            // Back from Log: zero current-chapter API. Join the ordered
            // disappear-cancel, resync once, then resume on window misses
            // (covers running batches via the ordered trigger path too).
            if let pendingCancel = disappearCancelTask {
                disappearCancelTask = nil
                await pendingCancel.value
            }
            prefetchStatus = await prefetchManager.currentStatus()
            await resumePrefetchIfMissesRemain()
            return
        }
        if aiMode != .none {
            aiTask?.cancel()
            aiTask = Task { await loadAIContent(isReprocess: false) }
        }
        // feat-024 Phase 2: same-book+mode navigates never cancel — the FIFO
        // queue reconciles (keep ∩ + append tail). Cancel only on mode .none;
        // other ineligibility (error) keeps the running queue untouched.
        if aiMode != .none, errorMessage == nil {
            await triggerPrefetchIfEligible()
        } else if aiMode == .none {
            await cancelPrefetch()
        }
    }

    func goNext() async {
        guard canGoNext else { return }
        // Double-bump with load(.chapterChange) below is intentional: the
        // guard is equality-based so magnitude is harmless, and this closes
        // the gap before chapterNumber changes. No prefetch cancel here:
        // the queue keeps the running task across same-book navigates.
        aiGeneration += 1
        chapterNumber += 1
        await load(source: .chapterChange)
        persistChapter()
    }

    func goPrev() async {
        guard canGoPrev else { return }
        // Double-bump with load(.chapterChange) below is intentional: the
        // guard is equality-based so magnitude is harmless, and this closes
        // the gap before chapterNumber changes. No prefetch cancel here.
        aiGeneration += 1
        chapterNumber -= 1
        await load(source: .chapterChange)
        persistChapter()
    }

    func goToChapter(_ number: Int) async {
        // Double-bump with load(.chapterChange) below is intentional: the
        // guard is equality-based so magnitude is harmless, and this closes
        // the gap before chapterNumber changes. Same-chapter targets still
        // bump (invalidates in-flight refresh races); load() skips the
        // nil-out when the held content already belongs to this chapter.
        // No prefetch cancel here: same-book navigate keeps the queue.
        aiGeneration += 1
        if let count = book?.count {
            chapterNumber = min(max(1, number), count)
        } else {
            chapterNumber = max(1, number)
        }
        await load(source: .chapterChange)
        persistChapter()
    }

    func saveOffset(_ offset: Double) {
        if settingsStore.session == nil {
            settingsStore.session = ReadingSession(
                bookId: bookId,
                onScreen: true,
                offset: offset,
                chapterNumber: chapterNumber
            )
        } else {
            settingsStore.session?.offset = offset
            settingsStore.session?.bookId = bookId
            settingsStore.session?.chapterNumber = chapterNumber
        }
        settingsStore.save()
    }

    func onAppear() {
        let existing = settingsStore.session
        let offsetToKeep = (existing?.bookId == bookId) ? existing?.offset ?? 0 : 0
        let chapterToKeep: Int
        if let session = existing, session.bookId == bookId {
            chapterToKeep = session.chapterNumber
            chapterNumber = chapterToKeep
        } else {
            chapterToKeep = chapterNumber
        }
        settingsStore.session = ReadingSession(
            bookId: bookId,
            onScreen: true,
            offset: offsetToKeep,
            chapterNumber: chapterToKeep
        )
        settingsStore.save()
    }

    func onDisappear() {
        lastVisibleChapter = chapterNumber
        lastVisibleMode = aiMode
        // Seamless restore: do NOT clear session.onScreen here. onDisappear also
        // fires when References/TOC/Log cover Reader (push, not pop); clearing it
        // would strand relaunch on Library. Only Router.popReading /
        // didPopFromReading (true back) clears onScreen.
        aiTask?.cancel()
        aiGeneration += 1
        isAIProcessing = false
        // Single ordered cancel path: cancel any previous disappear-cancel
        // before overwrite, then run cancelPrefetch() once (it writes the
        // terminal state). Joined by the next .returnFromLog resync.
        disappearCancelTask?.cancel()
        disappearCancelTask = Task { await cancelPrefetch() }
    }

    func setAIMode(_ mode: AIMode) async {
        aiTask?.cancel()
        aiGeneration += 1
        await cancelPrefetch()
        aiMode = mode
        settingsStore.aiMode = mode
        settingsStore.save()
        aiError = nil
        if mode == .none {
            processedContent = nil
            processedChapterNumber = nil
            processedAIMode = nil
            if let html = readChapterHTML(number: chapterNumber) {
                blocks = HtmlParser.parse(html: html)
            }
            return
        }
        // Tracked in aiTask so outside cancellation (disappear/nav) hits it.
        aiTask?.cancel()
        aiTask = Task { await loadAIContent(isReprocess: false) }
        await aiTask?.value
        if errorMessage == nil {
            await triggerPrefetchIfEligible()
        }
    }

    func reprocess() async {
        guard aiMode != .none else { return }
        aiGeneration += 1
        // Tracked in aiTask so a newer generation cancels this one.
        aiTask?.cancel()
        aiTask = Task { await loadAIContent(isReprocess: true) }
        await aiTask?.value
        if errorMessage == nil {
            await triggerPrefetchIfEligible()
        }
    }

    /// Identity gate for the AI section: processed text renders only when it
    /// was produced for the currently visible chapter + mode.
    func isProcessedContentCurrent() -> Bool {
        guard aiMode != .none else { return false }
        guard let content = processedContent, !content.isEmpty else { return false }
        return processedChapterNumber == chapterNumber && processedAIMode == aiMode
    }

    /// Processed text for the visible chapter + mode; nil when there is no
    /// current content (not loaded yet, cleared, or superseded) or while its
    /// generation is still in flight.
    var currentProcessedContent: String? {
        guard !isAIProcessing, isProcessedContentCurrent() else { return nil }
        return processedContent
    }

    private func loadAIContent(isReprocess: Bool) async {
        // Snapshot generation + identity before the await. Only the latest
        // generation may publish; superseded tasks (nav/mode-switch/reprocess,
        // disappear) return silently even when their await still resolves.
        let generation = aiGeneration
        let chapter = chapterNumber
        let mode = aiMode
        guard let raw = readRawTextForAI() else {
            guard generation == aiGeneration, chapter == chapterNumber, mode == aiMode else { return }
            aiError = "Không tìm thấy chương"
            return
        }
        isAIProcessing = true
        // Clear only while this generation is still current: a stale task must
        // never switch off a newer generation's spinner (raw-blocks flicker).
        defer {
            if generation == aiGeneration {
                isAIProcessing = false
            }
        }
        do {
            let result: String
            if isReprocess {
                result = try await aiService?.reprocess(
                    bookId: bookId,
                    chapterNumber: chapterNumber,
                    mode: aiMode,
                    rawText: raw
                ) ?? raw
            } else {
                result = try await aiService?.processedContent(
                    bookId: bookId,
                    chapterNumber: chapterNumber,
                    mode: aiMode,
                    rawText: raw
                ) ?? raw
            }
            guard generation == aiGeneration, chapter == chapterNumber, mode == aiMode else { return }
            processedContent = result
            processedChapterNumber = chapter
            processedAIMode = mode
        } catch is CancellationError {
            // Cancelled (nav/disappear/mode switch): no aiError/toast, defer clears flag.
        } catch {
            guard generation == aiGeneration, chapter == chapterNumber, mode == aiMode else { return }
            aiError = error.localizedDescription
            toastCenter?.show(aiError ?? "AI processing failed.", type: .error)
        }
    }

    private func readRawTextForAI() -> String? {
        guard let html = readChapterHTML(number: chapterNumber) else { return nil }
        let parsed = HtmlParser.parse(html: html)
        let joined = parsed.map { $0.spans.map { $0.text }.joined() }.joined(separator: "\n\n")
        var normalized = joined.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persistChapter() {
        if settingsStore.session == nil {
            settingsStore.session = ReadingSession(
                bookId: bookId,
                onScreen: true,
                offset: 0,
                chapterNumber: chapterNumber
            )
        } else {
            settingsStore.session?.chapterNumber = chapterNumber
            settingsStore.session?.offset = 0
            settingsStore.session?.bookId = bookId
        }
        settingsStore.save()
    }

    private func triggerPrefetchIfEligible() async {
        // feat-024 Phase 2: no debounce — the FIFO queue absorbs rapid
        // navigates (keep ∩ + append tail), so start synchronously right
        // after the eligibility guards. Only mode .none cancels; other
        // ineligibility keeps the running queue untouched.
        guard aiMode != .none else {
            await cancelPrefetch()
            return
        }
        guard errorMessage == nil else { return }
        guard let total = book?.count, total > 0 else { return }
        guard let service = aiService else { return }
        let mode = aiMode
        let current = chapterNumber
        let slug = bookId
        let manager = prefetchManager
        let cache = processedCache
        let repo = repository
        let store = settingsStore
        await manager.start(
            bookId: slug,
            currentChapter: current,
            totalChapters: total,
            mode: mode,
            settings: store,
            cache: cache,
            aiService: service,
            repository: repo
        )
        // One-shot mirror so steady reading shows running synchronously;
        // terminal states arrive via cancelPrefetch or the next
        // returnFromLog resync (no poll task).
        prefetchStatus = await manager.currentStatus()
    }

    /// Log-return resume on remaining window misses. Cache reads only — zero
    /// network unless the manager itself starts a batch.
    private func resumePrefetchIfMissesRemain() async {
        guard aiMode != .none, errorMessage == nil else { return }
        guard let total = book?.count, total > 0 else { return }
        guard aiService != nil else { return }
        let end = min(chapterNumber + settingsStore.effectivePrefetchCount(), total)
        guard end > chapterNumber else { return }
        let range = Array((chapterNumber + 1) ... end)
        // Query failure keeps prior state (never miss-all): no resume and no
        // VM-side log (prefetch logging belongs to the manager; no new events).
        guard let cached = try? processedCache.batchStatus(bookId: bookId, mode: aiMode, numbers: range) else { return }
        guard cached.count < range.count else { return }
        await triggerPrefetchIfEligible()
    }

    private func cancelPrefetch() async {
        // Single cancel path (book/mode change, .none, disappear, explicit):
        // manager cancel + terminal write once (no poll, no epoch).
        await prefetchManager.cancel()
        // NOTE (pre-existing semantics): cancel runs before setAIMode assigns
        // .none, so a .none switch lands here on not-running/"Đã hủy", not
        // .idle. The idle-vs-cancelled contract is undefined; don't rely on it.
        if aiMode == .none {
            prefetchStatus = .idle
        } else {
            prefetchStatus.isRunning = false
            prefetchStatus.message = "Đã hủy"
        }
    }

    private func readChapterHTML(number: Int) -> String? {
        do {
            return try repository.chapterHTML(slug: bookId, number: number)
        } catch {
            let url = AppPaths.booksRoot()
                .appendingPathComponent(bookId, isDirectory: true)
                .appendingPathComponent("chapters/chapter-\(number).html", isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path) {
                return try? String(contentsOf: url, encoding: .utf8)
            }
            return nil
        }
    }
}
