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
                        router.push(.addBook)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.backgroundWhite)
                .accessibilityIdentifier("library.empty")
            } else {
                List {
                    Section {
                        ForEach(viewModel.books, id: \.id) { book in
                            Button {
                                router.push(.reading(bookId: book.id))
                            } label: {
                                VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                                    Text(book.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(DesignTokens.text)
                                        .lineLimit(2)
                                    HStack(spacing: DesignTokens.spacing8) {
                                        if let author = book.author {
                                            Text(author)
                                                .font(.footnote)
                                                .foregroundStyle(DesignTokens.muted)
                                        }
                                        Text("\(book.count) chương")
                                            .font(.footnote)
                                            .foregroundStyle(DesignTokens.muted)
                                    }
                                }
                                .frame(minHeight: DesignTokens.rowMinHeight)
                                #if os(macOS)
                                    .padding(.trailing, DesignTokens.spacing24)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .trailing) {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(DesignTokens.muted)
                                            .accessibilityHidden(true)
                                    }
                                #endif
                                    .contentShape(Rectangle())
                            }
                            .listRowBackground(DesignTokens.surface)
                            .listRowSeparatorTint(DesignTokens.border)
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
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Thông tin", systemImage: "info.circle") {
                                        viewModel.selected = book
                                        viewModel.showInfo = true
                                    }
                                    Button("Xóa", systemImage: "trash", role: .destructive) {
                                        viewModel.confirmDelete(book)
                                    }
                                }
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
                    ToolbarItem(placement: .primaryAction) {
                        Button("Thêm sách", systemImage: "plus") {
                            router.push(.addBook)
                        }
                        .labelStyle(.iconOnly)
                        #if os(iOS)
                            .a11yHitTarget()
                        #endif
                    }
                    #if os(macOS)
                    .sharedBackgroundVisibility(.hidden)
                    #endif
                    ToolbarItem(placement: .primaryAction) {
                        Button("Cài đặt", systemImage: "gearshape") {
                            router.push(.settings)
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("settingsButton")
                        #if os(iOS)
                            .a11yHitTarget()
                        #endif
                    }
                    #if os(macOS)
                    .sharedBackgroundVisibility(.hidden)
                    #endif
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
}
