import SwiftUI

struct AppRoot: View {
    @State private var router: Router
    @State private var libraryViewModel: LibraryViewModel
    @State private var settingsStore: SettingsStore

    init() {
        let router = Router()
        _router = State(initialValue: router)
        _libraryViewModel = State(initialValue: LibraryViewModel(toastCenter: router.toast))
        _settingsStore = State(initialValue: SettingsStore.shared)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            LibraryView(router: router, viewModel: libraryViewModel)
                .navigationDestination(for: Router.Route.self) { route in
                    // swiftlint:disable switch_case_alignment
                    switch route {
                        case let .reading(bookId):
                            ReaderView(bookId: bookId, router: router)
                                .toolbar(.hidden, for: .navigationBar)
                        case let .references(bookId):
                            let repo = router.repository
                            if let book = try? repo.book(slug: bookId) {
                                ReferencesView(
                                    book: book,
                                    current: settingsStore.session?.chapterNumber ?? 1,
                                    onSelect: { number in
                                        settingsStore.session?.chapterNumber = number
                                        settingsStore.save()
                                    },
                                    router: router
                                )
                            } else {
                                Text("Không tìm thấy chương")
                            }
                        case .addBook:
                            AddBookView(viewModel: makeImportViewModel())
                        case .settings:
                            SettingsView()
                        case .cacheManager:
                            CacheManagerView()
                        case let .settingEditor(settingKey):
                            SettingEditorView(settingKey: settingKey)
                    }
                    // swiftlint:enable switch_case_alignment
                }
        }
        .environment(router)
        .environment(router.toast)
        .environment(settingsStore)
        .toast(center: router.toast)
        .task {
            router.restoreInitialRoute()
        }
    }

    private func makeImportViewModel() -> ImportViewModel {
        let viewModel = ImportViewModel(
            catalogService: CatalogService(settingsStore: settingsStore),
            repository: FileBookRepository(root: AppPaths.booksRoot()),
            downloader: URLSessionDownloader()
        )
        viewModel.onImportSuccess = { _ in
            libraryViewModel.load()
        }
        return viewModel
    }
}
