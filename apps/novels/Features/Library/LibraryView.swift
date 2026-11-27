import SwiftUI

struct LibraryView: View {
    @Bindable var router: Router
    @State private var viewModel: LibraryViewModel

    init(router: Router, viewModel: LibraryViewModel? = nil) {
        self.router = router
        _viewModel = State(wrappedValue: viewModel ?? LibraryViewModel(toastCenter: router.toast))
    }

    var body: some View {
        Group {
            if viewModel.books.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label("Chưa có sách", systemImage: "books.vertical")
                } description: {
                    Text("Nhấn + để thêm sách")
                } actions: {
                    Button("Thêm sách") {
                        router.push(.addBook(UUID()))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.backgroundWhite)
                .accessibilityIdentifier("library.empty")
            } else {
                List {
                    Section {
                        ForEach(viewModel.books, id: \.id) { book in
                            BookRowButton(accessory: .open) {
                                router.push(.reading(bookId: book.id))
                            } label: {
                                VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                                    Text(book.name)
                                        .font(DesignTokens.Typography.subheadline.weight(.semibold))
                                        .foregroundStyle(DesignTokens.text)
                                        .lineLimit(2)
                                    HStack(spacing: DesignTokens.spacing8) {
                                        if let author = book.author {
                                            Text(author)
                                                .font(DesignTokens.Typography.footnote)
                                                .foregroundStyle(DesignTokens.muted)
                                        }
                                        Text("\(book.count) chương")
                                            .font(DesignTokens.Typography.footnote)
                                            .foregroundStyle(DesignTokens.muted)
                                    }
                                }
                            }
                            #if os(iOS)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.confirmDelete(book)
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                                .tint(DesignTokens.error)
                                Button {
                                    viewModel.selected = book
                                    viewModel.showInfo = true
                                } label: {
                                    Label("Thông tin", systemImage: "info.circle")
                                }
                                .tint(DesignTokens.accent)
                            }
                            #else
                            .contextMenu { bookContextMenu(for: book) }
                            #endif
                            .accessibilityIdentifier("library.row.\(book.id)")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(DesignTokens.backgroundWhite)
                .refreshable {
                    await viewModel.load(force: true)
                }
            }
        }
        .navigationTitle("Thư viện")
        #if os(iOS)
            .toolbarTitleDisplayMode(.large)
        #endif
            .toolbar {
                if router.path.isEmpty {
                    PrimaryToolbarItem {
                        Button("Thêm sách", systemImage: "plus") {
                            router.push(.addBook(UUID()))
                        }
                        .labelStyle(.iconOnly)
                    }
                    PrimaryToolbarItem {
                        Button("Cài đặt", systemImage: "gearshape") {
                            router.push(.settings)
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("settingsButton")
                    }
                }
            }
            .loadingOverlay(isLoading: viewModel.isLoading)
            .sheet(isPresented: $viewModel.showInfo) {
                if let book = viewModel.selected {
                    BookInfoSheet(book: book)
                }
            }
            // Delete confirmation uses a single boolean-driven alert, so presentation
            // does not depend on row identity. Duplicate book ids are removed
            // upstream by first-wins dedupe in FileBookRepository.listBooks(),
            // keeping List(id: \.id) diffing stable.
            .alert(
                "Xóa sách?",
                isPresented: Binding(
                    get: { viewModel.showDeleteConfirm != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.showDeleteConfirm = nil
                        }
                    }
                ),
                actions: {
                    Button("Xóa", role: .destructive) {
                        viewModel.deleteConfirmed()
                    }
                    Button("Hủy", role: .cancel) {
                        viewModel.showDeleteConfirm = nil
                    }
                },
                message: {
                    if let book = viewModel.showDeleteConfirm {
                        Text("Bạn có chắc muốn xóa “\(book.name)” không?")
                    }
                }
            )
            .task {
                await viewModel.load()
            }
    }

    #if os(macOS)
    @ViewBuilder
    private func bookContextMenu(for book: Book) -> some View {
        Button("Thông tin", systemImage: "info.circle") {
            viewModel.selected = book
            viewModel.showInfo = true
        }
        Button("Xóa", systemImage: "trash", role: .destructive) {
            viewModel.confirmDelete(book)
        }
    }
    #endif
}
