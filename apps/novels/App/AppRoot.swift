import SwiftUI

struct AppRoot: View {
    @Environment(\.scenePhase) private var scenePhase
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
                    #if os(macOS)
                    if case .reading = route {
                        destination(for: route)
                    } else {
                        destination(for: route)
                            .navigationBarBackButtonHidden(true)
                            .toolbar {
                                ToolbarItem(placement: .navigation) {
                                    Button("Quay lại", systemImage: "chevron.left") { router.pop() }
                                        .labelStyle(.iconOnly)
                                        .help("Quay lại")
                                }
                            }
                    }
                    #else
                    destination(for: route)
                    #endif
                }
        }
        .environment(router)
        .environment(router.toast)
        .environment(settingsStore)
        .toast(center: router.toast)
        .onChange(of: scenePhase) { _, newPhase in
            // Seamless restore: flush the in-memory session to disk when leaving
            // the foreground, so kill-after-background relaunches into the same
            // book/chapter/offset. Save is idempotent; ReaderView also flushes
            // its pending scroll offset on background and disappear.
            if newPhase == .background || newPhase == .inactive {
                settingsStore.save()
            }
            if newPhase == .active {
                ReadingProgressStore.shared.retryPending()
            }
            #if os(iOS)
            BackgroundAIExecution.shared.sceneChanged(isBackground: newPhase == .background)
            #endif
        }
        .task {
            router.restoreInitialRoute()
        }
    }

    @ViewBuilder
    private func destination(for route: Router.Route) -> some View {
        // swiftlint:disable switch_case_alignment
        switch route {
            case let .reading(bookId):
                ReaderView(bookId: bookId, router: router)
            case let .references(bookId):
                let repo = router.repository
                if let book = try? repo.book(slug: bookId) {
                    ReferencesView(
                        book: book,
                        current: settingsStore.session?.chapterNumber ?? 1,
                        onSelect: { number in
                            router.chapterSelectedInContents = true
                            settingsStore.session?.chapterNumber = number
                            settingsStore.session?.offset = 0
                            settingsStore.session?.bookId = bookId
                            settingsStore.save()
                            ReadingProgressStore.shared.save(bookId: bookId, chapter: number, anchor: nil)
                        },
                        router: router
                    )
                } else {
                    Text("Không tìm thấy chương")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.muted)
                }
            case .addBook:
                AddBookView(viewModel: makeImportViewModel())
            case .settings:
                SettingsView()
            case .cacheManager:
                CacheManagerView()
            case let .settingEditor(settingKey):
                SettingEditorView(settingKey: settingKey)
            case let .apiLog(bookId, initialFilter):
                LogScreen(bookId: bookId, initialFilter: initialFilter)
        }
        // swiftlint:enable switch_case_alignment
    }

    private func makeImportViewModel() -> ImportViewModel {
        let viewModel = ImportViewModel(
            catalogService: CatalogService(settingsStore: settingsStore),
            repository: FileBookRepository(root: AppPaths.booksRoot()),
            downloader: URLSessionDownloader()
        )
        viewModel.onImportSuccess = { _ in
            libraryViewModel.invalidate()
            Task { await libraryViewModel.load() }
        }
        return viewModel
    }
}
