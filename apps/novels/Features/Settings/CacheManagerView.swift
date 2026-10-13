import SwiftUI

// swiftlint:disable:next type_body_length
struct CacheManagerView: View {
    @Environment(Router.self) private var router

    @State private var viewModel: CacheManagerViewModel
    @State private var expandedBookIds: Set<String> = []
    @State private var showClearAllConfirm = false
    @State private var showClearBookConfirm: CacheManagerViewModel.BookCacheRow?

    init(cache: ProcessedChapterCaching? = nil, bookRepository: BookRepository? = nil) {
        _viewModel = State(initialValue: CacheManagerViewModel(cache: cache, bookRepository: bookRepository))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm dd/MM/yyyy"
        return formatter
    }()

    private static let clearWarning =
        "Xử lý AI và tải trước không bị dừng; bản dịch có thể được lưu lại sau khi xóa."

    var body: some View {
        Group {
            if viewModel.isUnavailable {
                unusableCacheView
            } else {
                List {
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }
                    if viewModel.errorMessage == nil {
                        countCard
                        bookSection
                    }
                }
                .listSectionSpacing(DesignTokens.spacing8)
                .scrollContentBackground(.hidden)
                .background(DesignTokens.backgroundWhite)
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Quản lý bộ nhớ đệm")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog(
            "Xác nhận xóa tất cả?",
            isPresented: $showClearAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Xóa tất cả", role: .destructive) {
                Task { await clearAll() }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Hành động không thể hoàn tác. " + Self.clearWarning)
        }
        .confirmationDialog(
            "Xóa cache cho \(showClearBookConfirm?.title ?? "")?",
            isPresented: Binding(
                get: { showClearBookConfirm != nil },
                set: {
                    if !$0 {
                        showClearBookConfirm = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Xóa", role: .destructive) {
                if let row = showClearBookConfirm {
                    Task { await clearBook(row) }
                }
            }
            Button("Hủy", role: .cancel) {
                showClearBookConfirm = nil
            }
        } message: {
            Text("Hành động không thể hoàn tác. " + Self.clearWarning)
        }
        .overlay {
            if viewModel.isLoading || viewModel.isClearing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            }
        }
    }

    private var unusableCacheView: some View {
        VStack(spacing: 16) {
            Text(viewModel.errorMessage ?? "Bộ nhớ đệm không khả dụng")
                .foregroundStyle(DesignTokens.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacing16)
            Text("Quay lại và mở lại màn hình để thử kết nối bộ nhớ đệm.")
                .font(.footnote)
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.backgroundWhite)
    }

    private func errorBanner(_ message: String) -> some View {
        Section {
            HStack(spacing: DesignTokens.spacing12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.error)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.error)
            }
            .padding(.vertical, DesignTokens.spacing8)
            .listRowBackground(DesignTokens.surface)
            .listRowSeparator(.hidden)
        }
    }

    private var countCard: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignTokens.spacing16) {
                HStack(alignment: .center, spacing: DesignTokens.spacing12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .fill(DesignTokens.error.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "archivebox.fill")
                            .font(.title3)
                            .foregroundStyle(DesignTokens.error)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                        Text(viewModel
                            .totalVersions == 0 ? "Chưa lưu bản dịch nào" :
                            "\(viewModel.totalVersions) bản dịch đã lưu")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Text(viewModel.distinctChapters == 0
                            ? "Máy giữ sẵn để mở lại nhanh hơn."
                            : "Trên \(viewModel.distinctChapters) chương khác nhau.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                Text("Xóa để giải phóng dung lượng, truyện gốc không bị ảnh hưởng. " + Self.clearWarning)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer(minLength: 0)
                    Button(role: .destructive) {
                        showClearAllConfirm = true
                    } label: {
                        Label("Xóa tất cả", systemImage: "trash")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignTokens.spacing16)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.error)
                    .disabled(viewModel.totalVersions == 0 || viewModel.isLoading || viewModel.isClearing)
                    .opacity(viewModel.totalVersions == 0 ? 0.4 : 1)
                    .accessibilityIdentifier("clearAllButton")
                    .accessibilityLabel("Xóa tất cả")
                }
            }
            .padding(.vertical, DesignTokens.spacing16)
            .listRowBackground(DesignTokens.surface)
            .listRowSeparator(.hidden)
        }
    }

    private var bookSection: some View {
        Section {
            if viewModel.books.isEmpty {
                emptySection
            } else {
                ForEach(viewModel.books) { row in
                    bookRow(row)
                }
            }
        } header: {
            Text("Theo sách")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.text)
                .textCase(nil)
        }
    }

    private var emptySection: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(spacing: DesignTokens.spacing8) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.muted)
                    .accessibilityHidden(true)
                Text("Chưa có dữ liệu đệm")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.muted)
                Text("Các chương đã xử lý sẽ hiện ở đây.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, DesignTokens.spacing16)
            Spacer(minLength: 0)
        }
        .listRowBackground(DesignTokens.surface)
        .listRowSeparator(.hidden)
    }

    private func bookRow(_ row: CacheManagerViewModel.BookCacheRow) -> some View {
        let isExpanded = expandedBookIds.contains(row.slug)

        return VStack(alignment: .leading, spacing: 0) {
            bookHeader(row: row, isExpanded: isExpanded)
            if isExpanded {
                expandedDetails(slug: row.slug)
                    .task(id: viewModel.metadataRevision) {
                        await viewModel.loadMetadata(slug: row.slug)
                    }
            }
        }
        .accessibilityIdentifier("cache-\(row.slug)")
        .listRowBackground(DesignTokens.surface)
        .listRowSeparatorTint(DesignTokens.border)
    }

    private func bookHeader(row: CacheManagerViewModel.BookCacheRow, isExpanded: Bool) -> some View {
        HStack(spacing: DesignTokens.spacing8) {
            Button {
                toggleExpanded(slug: row.slug)
            } label: {
                HStack(spacing: DesignTokens.spacing8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignTokens.muted)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if row.title != row.slug {
                            Text(row.slug)
                                .font(.caption2)
                                .foregroundStyle(DesignTokens.muted)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .a11yHitTarget()
            .accessibilityLabel("\(row.title), \(row.versionCount) bản lưu")
            .accessibilityHint(isExpanded ? "Thu gọn chi tiết chương" : "Xem các chương đã lưu")

            Spacer(minLength: DesignTokens.spacing8)

            Text("\(row.versionCount) bản")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.muted)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DesignTokens.muted.opacity(0.15), in: Capsule())
                .accessibilityLabel("\(row.versionCount) bản lưu")

            Button(role: .destructive) {
                showClearBookConfirm = row
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(DesignTokens.error)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(DesignTokens.error.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(DesignTokens.error.opacity(0.5), lineWidth: 1))
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading || viewModel.isClearing)
            .accessibilityIdentifier("clear-\(row.slug)")
            .accessibilityLabel("Xóa \(row.title)")
            .a11yHitTarget()
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func expandedDetails(slug: String) -> some View {
        if let message = viewModel.metadataErrors[slug] {
            Text(message)
                .font(.footnote)
                .foregroundStyle(DesignTokens.error)
        } else if let items = viewModel.bookMetadata[slug], !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                ForEach(items) { item in
                    metadataItemRow(slug: slug, item: item)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, DesignTokens.spacing8)
        } else if viewModel.bookMetadata[slug] == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacing8)
        } else {
            Text("Không có chi tiết")
                .font(.footnote)
                .foregroundStyle(DesignTokens.muted)
                .padding(.leading, 24)
                .padding(.vertical, 4)
        }
    }

    private func metadataItemRow(slug: String, item: ProcessedChapterMetadata) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.spacing8) {
            Text("Chương \(item.chapterNumber)")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.text)
            Text(item.mode.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignTokens.accent.opacity(0.12), in: Capsule())
            Spacer()
            Text(Self.dateFormatter.string(from: item.updatedAt))
                .font(.caption2)
                .foregroundStyle(DesignTokens.muted)
        }
        .padding(.vertical, 4)
        .padding(.leading, 24)
        .accessibilityIdentifier("item-\(slug)-\(item.id)")
    }

    private func toggleExpanded(slug: String) {
        if expandedBookIds.contains(slug) {
            expandedBookIds.remove(slug)
        } else {
            expandedBookIds.insert(slug)
        }
    }

    private func clearAll() async {
        if await viewModel.clear() {
            expandedBookIds.removeAll()
            router.toast.show("Đã xóa tất cả", type: .success)
        } else {
            router.toast.show("Lỗi: không thể xóa", type: .error)
        }
    }

    private func clearBook(_ row: CacheManagerViewModel.BookCacheRow) async {
        showClearBookConfirm = nil
        if await viewModel.clear(bookId: row.slug) {
            expandedBookIds.remove(row.slug)
            router.toast.show("Đã xóa \(row.title)", type: .success)
        } else {
            router.toast.show("Lỗi: không thể xóa", type: .error)
        }
    }
}
