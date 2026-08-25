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
    let toast = ToastCenter()

    init(repository: BookRepository? = nil) {
        if let repository {
            self.repository = repository
        } else {
            self.repository = FileBookRepository(root: AppPaths.booksRoot(), fileManager: .default)
        }
    }

    func load() {
        isLoading = true
        defer { isLoading = false }
        books = (try? repository.listBooks()) ?? []
    }

    func confirmDelete(_ book: Book) {
        showDeleteConfirm = book
    }

    func deleteConfirmed() {
        guard let book = showDeleteConfirm else { return }
        do {
            try repository.deleteBook(slug: book.id)
            toast.show("Đã xóa “\(book.name)”", type: .success)
            showDeleteConfirm = nil
            load()
        } catch {
            toast.show("Không thể xóa sách", type: .error)
        }
    }
}
