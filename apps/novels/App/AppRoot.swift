import SwiftUI

struct AppRoot: View {
    @State private var router = Router()
    @State private var libraryViewModel: LibraryViewModel
    @State private var settingsStore = SettingsStore.shared

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
                            ReadingShellView(bookId: bookId, router: router)
                        case .references:
                            Text("Tài liệu tham khảo")
                                .navigationTitle("Tham khảo")
                        case .addBook:
                            AddBookView(viewModel: makeImportViewModel())
                    }
                    // swiftlint:enable switch_case_alignment
                }
        }
        .environment(router)
        .environment(router.toast)
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
