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
                .accessibilityIdentifier("library.empty")
            } else {
                List(viewModel.books, id: \.id) { book in
                    Button {
                        router.push(.reading(bookId: book.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.name)
                                .font(.headline)
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
                    }
                    .listRowSeparator(.hidden)
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
                .refreshable {
                    viewModel.load()
                }
            }
        }
        .navigationTitle("Thư viện")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.addBook)
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Thêm sách")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Cài đặt")
                }
                .accessibilityIdentifier("settingsButton")
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading)
        .sheet(isPresented: $viewModel.showInfo) {
            if let book = viewModel.selected {
                BookInfoSheet(book: book)
            }
        }
        .alert(item: $viewModel.showDeleteConfirm) { book in
            Alert(
                title: Text("Xóa sách?"),
                message: Text("Bạn có chắc muốn xóa “\(book.name)” không?"),
                primaryButton: .destructive(Text("Xóa")) {
                    viewModel.deleteConfirmed()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .task {
            viewModel.load()
        }
    }
}

extension Book: Identifiable {}
