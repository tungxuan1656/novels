import Foundation
import Observation

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
    var isLoading = false
    var errorMessage: String?
    var aiMode: AIMode = .none
    var processedContent: String?
    var isAIProcessing = false
    var aiError: String?
    private var aiService: AIReadingService?
    private var aiTask: Task<Void, Never>?
    var prefetchStatus: PrefetchStatus = .idle
    private let prefetchManager: PrefetchManager
    private var prefetchPollTask: Task<Void, Never>?
    private let processedCache: ProcessedChapterCaching
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

    func load() async {
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
        if aiMode != .none {
            aiTask?.cancel()
            aiTask = Task { await loadAIContent(isReprocess: false) }
        }
        if aiMode != .none, errorMessage == nil {
            await triggerPrefetchIfEligible()
        } else {
            await cancelPrefetch()
        }
    }

    func goNext() async {
        guard canGoNext else { return }
        await cancelPrefetch()
        chapterNumber += 1
        await load()
        persistChapter()
    }

    func goPrev() async {
        guard canGoPrev else { return }
        await cancelPrefetch()
        chapterNumber -= 1
        await load()
        persistChapter()
    }

    func goToChapter(_ number: Int) async {
        await cancelPrefetch()
        if let count = book?.count {
            chapterNumber = min(max(1, number), count)
        } else {
            chapterNumber = max(1, number)
        }
        await load()
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
        settingsStore.session?.onScreen = false
        settingsStore.save()
        prefetchPollTask?.cancel()
        prefetchPollTask = nil
        if aiMode == .none {
            prefetchStatus = .idle
        } else {
            prefetchStatus.isRunning = false
            prefetchStatus.message = "Đã hủy"
        }
        Task { await prefetchManager.cancel() }
    }

    func setAIMode(_ mode: AIMode) async {
        await cancelPrefetch()
        aiMode = mode
        aiError = nil
        if mode == .none {
            processedContent = nil
            if let html = readChapterHTML(number: chapterNumber) {
                blocks = HtmlParser.parse(html: html)
            }
            return
        }
        await loadAIContent(isReprocess: false)
        if errorMessage == nil {
            await triggerPrefetchIfEligible()
        }
    }

    func reprocess() async {
        guard aiMode != .none else { return }
        await loadAIContent(isReprocess: true)
        if errorMessage == nil {
            await triggerPrefetchIfEligible()
        }
    }

    private func loadAIContent(isReprocess: Bool) async {
        guard let raw = readRawTextForAI() else {
            aiError = "Không tìm thấy chương"
            return
        }
        isAIProcessing = true
        defer { isAIProcessing = false }
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
            processedContent = result
        } catch {
            aiError = error.localizedDescription
            toastCenter?.show(aiError ?? "AI processing failed.", type: .error)
        }
    }

    private func readRawTextForAI() -> String? {
        guard let html = readChapterHTML(number: chapterNumber) else { return nil }
        let parsed = HtmlParser.parse(html: html)
        let text = parsed.flatMap { $0.spans.map { $0.text } }.joined(separator: " ")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard aiMode != .none else {
            await cancelPrefetch()
            return
        }
        guard errorMessage == nil else {
            await cancelPrefetch()
            return
        }
        guard let total = book?.count, total > 0 else {
            await cancelPrefetch()
            return
        }
        guard let service = aiService else {
            await cancelPrefetch()
            return
        }
        prefetchPollTask?.cancel()
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
        prefetchPollTask?.cancel()
        prefetchPollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let status = await manager.currentStatus()
                await MainActor.run { self.prefetchStatus = status }
                if !status.isRunning {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            guard !Task.isCancelled else { return }
            let status = await manager.currentStatus()
            await MainActor.run { self.prefetchStatus = status }
        }
    }

    private func cancelPrefetch() async {
        await prefetchManager.cancel()
        prefetchPollTask?.cancel()
        prefetchPollTask = nil
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
