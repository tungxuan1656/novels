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
                List(viewModel.books, id: \.id) { book in
                    Button {
                        router.push(.reading(bookId: book.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DesignTokens.text)
                                .lineLimit(2)
                            HStack(spacing: 8) {
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
                        .padding(.vertical, 4)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(DesignTokens.backgroundWhite)
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
                    .accessibilityIdentifier("library.row.\(book.id)")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(DesignTokens.backgroundWhite)
                .refreshable {
                    viewModel.load()
                }
            }
        }
        .navigationTitle("Thư viện")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if router.path.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.push(.addBook)
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Thêm sách")
                    }
                    .a11yHitTarget()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.push(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Cài đặt")
                    }
                    .accessibilityIdentifier("settingsButton")
                    .a11yHitTarget()
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
            viewModel.load()
        }
    }
}
