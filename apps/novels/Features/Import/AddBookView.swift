import SwiftUI

struct AddBookView: View {
    @State var viewModel: ImportViewModel
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toast

    var body: some View {
        @Bindable var bindable = viewModel
        VStack(spacing: 0) {
            HStack {
                Button("Thư viện") {
                    router.pop()
                }
                .foregroundStyle(DesignTokens.accent)
                .accessibilityLabel("Thư viện")
                Spacer()
                Text("Thêm sách")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.text)
                Spacer()
                Picker("Sắp xếp", selection: $bindable.sortOption) {
                    Text("Tên A→Z").tag(ImportViewModel.SortOption.nameAZ)
                    Text("Mới nhất").tag(ImportViewModel.SortOption.updatedNewest)
                }
                .pickerStyle(.menu)
                .tint(DesignTokens.text)
                .accessibilityLabel("Sắp xếp")
            }
            .padding(.horizontal, DesignTokens.sidePadding)
            .padding(.vertical, DesignTokens.spacing12)
            .background(DesignTokens.backgroundWhite)

            Divider()
                .background(DesignTokens.border)

            contentView
                .background(DesignTokens.backgroundWhite)
        }
        .background(DesignTokens.backgroundWhite)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if viewModel.importState != .idle {
                LoadingView(
                    message: viewModel.importState == .downloading
                        ? "Đang tải..." : "Đang giải nén...",
                    isBlocking: true
                )
            }
        }
        .disabled(viewModel.importState != .idle)
        .task {
            await viewModel.loadCatalog()
        }
        .refreshable {
            await viewModel.loadCatalog()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        // swiftlint:disable switch_case_alignment
        switch viewModel.catalogState {
            case .idle, .loading:
                VStack {
                    Spacer()
                    LoadingView(message: "Đang tải...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.backgroundWhite)
            case .empty:
                VStack(spacing: DesignTokens.spacing16) {
                    ContentUnavailableView(
                        "Chưa có sách",
                        systemImage: "books.vertical",
                        description: Text("Danh mục trống")
                    )
                    Button("Thử lại") {
                        Task { await viewModel.loadCatalog() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .accessibilityLabel("Thử lại")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.backgroundWhite)
                .padding(DesignTokens.sidePadding)
            case let .error(message):
                VStack(spacing: DesignTokens.spacing16) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.sidePadding)
                    Button("Thử lại") {
                        Task { await viewModel.loadCatalog() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .accessibilityLabel("Thử lại")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.backgroundWhite)
                .padding(DesignTokens.sidePadding)
            case .loaded:
                List(viewModel.sortedBooks, id: \.id) { exp in
                    Button {
                        Task {
                            do {
                                try await viewModel.importBook(exp)
                                toast.show("Đã nhập sách", type: .success)
                                router.pop()
                            } catch let error as ImportError {
                                switch error {
                                    case .downloadFailed:
                                        toast.show("Không tải được gói sách, thử lại", type: .error)
                                    case .invalidPackage:
                                        toast.show("Gói sách không hợp lệ, không thể nhập", type: .error)
                                }
                            } catch is CancellationError {
                                // cancelled, no toast
                            } catch {
                                if let urlError = error as? URLError, urlError.code == .timedOut {
                                    toast.show("Không tải được gói sách, thử lại", type: .error)
                                } else {
                                    toast.show("Gói sách không hợp lệ, không thể nhập", type: .error)
                                }
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                            Text(exp.book.name)
                                .font(.headline)
                                .foregroundStyle(DesignTokens.text)
                                .lineLimit(2)
                            Text(exp.book.author ?? "Không rõ")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.muted)
                                .lineLimit(1)
                            Text(
                                "\(exp.book.chapterCount ?? 0) chương • \(ByteCountFormatter.string(fromByteCount: Int64(exp.fileSize), countStyle: .file))"
                            )
                            .font(.caption)
                            .foregroundStyle(DesignTokens.muted)
                            if let syn = exp.book.synopsis, !syn.isEmpty {
                                Text(syn)
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.muted)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, DesignTokens.spacing8)
                        .frame(minHeight: DesignTokens.rowMinHeight, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.white)
                    .listRowInsets(
                        EdgeInsets(
                            top: 4,
                            leading: DesignTokens.sidePadding,
                            bottom: 4,
                            trailing: DesignTokens.sidePadding
                        )
                    )
                    .background(Color.white)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    )
                    .accessibilityIdentifier("addbook.row.\(exp.book.slug)")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(DesignTokens.backgroundWhite)
        }
        // swiftlint:enable switch_case_alignment
    }
}
