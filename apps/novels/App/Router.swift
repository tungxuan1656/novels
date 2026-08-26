import Observation
import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    var toast = ToastCenter()
    private let settingsStore: SettingsStore
    let repository: BookRepository
    private var isPushing = false

    init(settingsStore: SettingsStore = .shared, repository: BookRepository? = nil) {
        self.settingsStore = settingsStore
        if let repository {
            self.repository = repository
        } else {
            let root = AppPaths.booksRoot()
            self.repository = FileBookRepository(root: root, fileManager: .default)
        }
    }

    enum Route: Hashable {
        case reading(bookId: String)
        case references(bookId: String)
        case addBook
    }

    func restoreInitialRoute() {
        settingsStore.load()
        settingsStore.sanitize()
        guard let session = settingsStore.session, session.onScreen else { return }
        guard (try? repository.book(slug: session.bookId)) != nil else {
            toast.show("Không tìm thấy sách", type: .error)
            settingsStore.session = nil
            settingsStore.save()
            return
        }
        push(.reading(bookId: session.bookId))
    }

    func push(_ route: Route) {
        guard !isPushing else { return }
        isPushing = true
        path.append(route)
        if case let .reading(bookId) = route {
            let isSameBook = settingsStore.session?.bookId == bookId
            let offset = isSameBook ? (settingsStore.session?.offset ?? 0) : 0
            let chapter = isSameBook ? (settingsStore.session?.chapterNumber ?? 1) : 1
            settingsStore.session = ReadingSession(
                bookId: bookId,
                onScreen: true,
                offset: offset,
                chapterNumber: chapter
            )
            settingsStore.save()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            isPushing = false
        }
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
        isPushing = false
    }

    func popReading() {
        didPopFromReading()
        pop()
    }

    func didPopFromReading() {
        settingsStore.session?.onScreen = false
        settingsStore.save()
    }
}
