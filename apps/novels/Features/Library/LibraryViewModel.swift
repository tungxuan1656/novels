import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class LibraryViewModel {
    var books: [Book] = []
    var isLoading = false
    var selected: Book?
    var showInfo = false
    var showDeleteConfirm: Book?
    private let repository: BookRepository
    private let settingsStore: SettingsStore
    private let chapterCache: ProcessedChapterCaching?
    let toast: ToastCenter
    private let logger = Logger(
        subsystem: "com.tungxuan.novels.library",
        category: "library"
    )

    init(
        repository: BookRepository? = nil,
        toastCenter: ToastCenter? = nil,
        settingsStore: SettingsStore? = nil,
        chapterCache: ProcessedChapterCaching? = nil
    ) {
        if let repository {
            self.repository = repository
        } else {
            self.repository = FileBookRepository(root: AppPaths.booksRoot(), fileManager: .default)
        }
        toast = toastCenter ?? ToastCenter()
        self.settingsStore = settingsStore ?? SettingsStore.shared
        self.chapterCache = chapterCache
    }

    func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            books = try repository.listBooks()
        } catch {
            books = []
            toast.show("Không thể tải thư viện", type: .error)
        }
    }

    func confirmDelete(_ book: Book) {
        showDeleteConfirm = book
    }

    func deleteConfirmed() {
        guard let book = showDeleteConfirm else { return }
        do {
            try repository.deleteBook(slug: book.id)
            if settingsStore.session?.bookId == book.id {
                settingsStore.session = nil
                settingsStore.save()
            }
            logDelete(bookId: book.id, result: "success")
            toast.show("Đã xóa “\(book.name)”", type: .success)
            showDeleteConfirm = nil
            clearProcessedCache(bookId: book.id)
            load()
        } catch {
            logger
                .error(
                    "Không thể xóa sách \(book.id, privacy: .private): \(String(describing: error), privacy: .private)"
                )
            logDelete(bookId: book.id, result: "error: \(String(describing: error))")
            showDeleteConfirm = nil
            load()
            toast.show("Không thể xóa sách", type: .error)
        }
    }

    /// Clears cached processed chapters for a deleted book. Cache failure must
    /// never break the delete success path — log and keep the success toast.
    private func clearProcessedCache(bookId: String) {
        let cache = chapterCache ?? (try? SQLiteProcessedChapterCache())
        guard let cache else { return }
        do {
            try cache.clear(bookId: bookId)
        } catch {
            logger
                .error(
                    "Không thể xóa cache \(bookId, privacy: .private): \(String(describing: error), privacy: .private)"
                )
        }
    }

    /// Emits a `library.delete` event to the DiagnosticsLog ring (visible in the
    /// Log viewer) so a silent UI failure can be traced to repo vs. wiring.
    /// Book id only — no secrets, prompts, or chapter text.
    private func logDelete(bookId: String, result: String) {
        Task { [bookId, result] in
            await DiagnosticsLog.shared.append(LogEntry(
                sessionId: DiagnosticsLog.sessionId,
                kind: .event,
                bookId: bookId,
                event: "library.delete",
                detail: result
            ))
        }
    }
}
