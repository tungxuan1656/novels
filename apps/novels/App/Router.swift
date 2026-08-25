import Observation
import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    var toast = ToastCenter()
    private let settingsStore: SettingsStore
    private let repository: BookRepository
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
        case references
    }

    func restoreInitialRoute() {
        let pending = settingsStore.session
        settingsStore.load()
        settingsStore.sanitize()
        if settingsStore.session == nil, let pending, pending.onScreen {
            settingsStore.session = pending
        }
        guard let session = settingsStore.session, session.onScreen else { return }
        guard (try? repository.book(slug: session.bookId)) != nil else {
            toast.show("Không tìm thấy sách", type: .error)
            return
        }
        push(.reading(bookId: session.bookId))
    }

    func push(_ route: Route) {
        guard !isPushing else { return }
        isPushing = true
        path.append(route)
        if case let .reading(bookId) = route {
            let offset = settingsStore.session?.offset ?? 0
            let chapter = settingsStore.session?.chapterNumber ?? 1
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
    }

    func didPopFromReading() {
        settingsStore.session?.onScreen = false
        settingsStore.save()
    }
}
