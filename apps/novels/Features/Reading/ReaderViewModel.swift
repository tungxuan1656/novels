import Foundation
import Observation

@MainActor
@Observable
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
    var canGoPrev: Bool {
        chapterNumber > 1
    }

    var canGoNext: Bool {
        (book?.count ?? 1) > chapterNumber
    }

    init(bookId: String, repository: BookRepository, settingsStore: SettingsStore, toastCenter: ToastCenter? = nil) {
        self.bookId = bookId
        self.repository = repository
        self.settingsStore = settingsStore
        self.toastCenter = toastCenter
        if let session = settingsStore.session, session.bookId == bookId {
            chapterNumber = max(1, session.chapterNumber)
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
        if book == nil {
            book = loadBookFallback()
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
    }

    func goNext() async {
        guard canGoNext else { return }
        chapterNumber += 1
        await load()
        persistChapter()
    }

    func goPrev() async {
        guard canGoPrev else { return }
        chapterNumber -= 1
        await load()
        persistChapter()
    }

    func goToChapter(_ number: Int) async {
        let maxCount = book?.count ?? number
        chapterNumber = min(max(1, number), maxCount)
        if let count = book?.count {
            chapterNumber = min(max(1, number), count)
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
        let existingOffset = settingsStore.session?.offset ?? 0
        let existingOnScreen = settingsStore.session?.onScreen ?? false
        // Keep offset if same book, else reset
        let offsetToKeep: Double
        if let session = settingsStore.session, session.bookId == bookId {
            offsetToKeep = session.offset
        } else {
            offsetToKeep = 0
        }
        _ = existingOffset
        _ = existingOnScreen
        settingsStore.session = ReadingSession(
            bookId: bookId,
            onScreen: true,
            offset: offsetToKeep,
            chapterNumber: chapterNumber
        )
        settingsStore.save()
    }

    func onDisappear() {
        settingsStore.session?.onScreen = false
        settingsStore.save()
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

    private func loadBookFallback() -> Book? {
        let fm: FileManager
        let rootURL: URL
        if let fileRepo = repository as? FileBookRepository {
            fm = fileRepo.fileManager
            rootURL = fileRepo.root
        } else {
            fm = FileManager.default
            rootURL = AppPaths.booksRoot()
        }
        let bookURL = rootURL.appendingPathComponent(bookId).appendingPathComponent("book.json")
        guard fm.fileExists(atPath: bookURL.path) else { return nil }
        guard let data = try? Data(contentsOf: bookURL) else { return nil }
        return try? JSONDecoder().decode(Book.self, from: data)
    }

    private func readChapterHTML(number: Int) -> String? {
        if let fileRepo = repository as? FileBookRepository {
            let url = fileRepo.root
                .appendingPathComponent(bookId, isDirectory: true)
                .appendingPathComponent("chapters/chapter-\(number).html", isDirectory: false)
            if fileRepo.fileManager.fileExists(atPath: url.path) {
                return try? String(contentsOf: url, encoding: .utf8)
            }
            // Fallback to repository helper (may throw missing)
            if let html = try? fileRepo.chapterHTML(slug: bookId, number: number) {
                return html
            }
            // Also try AppPaths for completeness
            let fallback = AppPaths.booksRoot()
                .appendingPathComponent(bookId, isDirectory: true)
                .appendingPathComponent("chapters/chapter-\(number).html", isDirectory: false)
            if FileManager.default.fileExists(atPath: fallback.path) {
                return try? String(contentsOf: fallback, encoding: .utf8)
            }
            return nil
        }
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

extension ToastCenter {
    var lastMessage: String? {
        current?.message
    }
}
