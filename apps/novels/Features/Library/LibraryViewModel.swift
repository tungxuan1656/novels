import Foundation
import Observation

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
    let toast: ToastCenter

    init(
        repository: BookRepository? = nil,
        toastCenter: ToastCenter? = nil,
        settingsStore: SettingsStore? = nil
    ) {
        if let repository {
            self.repository = repository
        } else {
            self.repository = FileBookRepository(root: AppPaths.booksRoot(), fileManager: .default)
        }
        toast = toastCenter ?? ToastCenter()
        self.settingsStore = settingsStore ?? SettingsStore.shared
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
            toast.show("Đã xóa “\(book.name)”", type: .success)
            showDeleteConfirm = nil
            load()
        } catch {
            toast.show("Không thể xóa sách", type: .error)
        }
    }
}
