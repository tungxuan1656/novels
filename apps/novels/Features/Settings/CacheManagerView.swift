import SwiftUI

// swiftlint:disable:next type_body_length
struct CacheManagerView: View {
    @Environment(Router.self) private var router

    private let cache: ProcessedChapterCaching?
    private let bookRepository: BookRepository

    @State private var totalVersions = 0
    @State private var distinctChapters = 0
    @State private var books: [BookCacheRow] = []
    @State private var expandedBookIds: Set<String> = []
    @State private var bookMetadata: [String: [ProcessedChapterMetadata]] = [:]
    @State private var isLoading = true
    @State private var showClearAllConfirm = false
    @State private var showClearBookConfirm: BookCacheRow?
    @State private var errorMessage: String?

    struct BookCacheRow: Identifiable, Equatable {
        let slug: String
        let title: String
        let versionCount: Int

        var id: String {
            slug
        }
    }

    init(cache: ProcessedChapterCaching? = nil, bookRepository: BookRepository? = nil) {
        self.bookRepository = bookRepository ?? FileBookRepository(root: AppPaths.booksRoot())
        if let cache {
            self.cache = cache
            _errorMessage = State(initialValue: nil)
        } else {
            do {
                self.cache = try SQLiteProcessedChapterCache()
                _errorMessage = State(initialValue: nil)
            } catch {
                self.cache = nil
                _errorMessage = State(initialValue: "Không thể mở bộ nhớ đệm: \(error.localizedDescription)")
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm dd/MM/yyyy"
        return formatter
    }()

    var body: some View {
        Group {
            if cache == nil {
                unusableCacheView
            } else {
                List {
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    if errorMessage == nil {
                        countCard
                        bookSection
                    }
                }
                .listSectionSpacing(DesignTokens.spacing8)
                .scrollContentBackground(.hidden)
                .background(DesignTokens.backgroundWhite)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Quản lý bộ nhớ đệm")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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
            Text("Hành động không thể hoàn tác.")
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
            Text("Hành động không thể hoàn tác.")
        }
        .overlay {
            if isLoading, cache != nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            }
        }
    }

    private var unusableCacheView: some View {
        VStack(spacing: 16) {
            Text(errorMessage ?? "Bộ nhớ đệm không khả dụng")
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
                        Text(totalVersions == 0 ? "Chưa lưu bản dịch nào" : "\(totalVersions) bản dịch đã lưu")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Text(distinctChapters == 0
                            ? "Máy giữ sẵn để mở lại nhanh hơn."
                            : "Trên \(distinctChapters) chương khác nhau.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                Text("Xóa để giải phóng dung lượng, truyện gốc không bị ảnh hưởng.")
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
                    .disabled(totalVersions == 0)
                    .opacity(totalVersions == 0 ? 0.4 : 1)
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
            if books.isEmpty {
                emptySection
            } else {
                ForEach(books) { row in
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

    private func bookRow(_ row: BookCacheRow) -> some View {
        let isExpanded = expandedBookIds.contains(row.slug)

        return VStack(alignment: .leading, spacing: 0) {
            bookHeader(row: row, isExpanded: isExpanded)
            if isExpanded {
                expandedDetails(slug: row.slug)
            }
        }
        .accessibilityIdentifier("cache-\(row.slug)")
        .listRowBackground(DesignTokens.surface)
        .listRowSeparatorTint(DesignTokens.border)
    }

    private func bookHeader(row: BookCacheRow, isExpanded: Bool) -> some View {
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
            .accessibilityIdentifier("clear-\(row.slug)")
            .accessibilityLabel("Xóa \(row.title)")
            .a11yHitTarget()
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func expandedDetails(slug: String) -> some View {
        if let items = bookMetadata[slug], !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                ForEach(items) { item in
                    metadataItemRow(slug: slug, item: item)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, DesignTokens.spacing8)
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

    private func load() async {
        guard let cache else {
            errorMessage = errorMessage ?? "Bộ nhớ đệm không khả dụng"
            isLoading = false
            totalVersions = 0
            distinctChapters = 0
            books = []
            return
        }
        isLoading = true
        do {
            totalVersions = try cache.countAll()
            let ids = try cache.allBookIds()
            books = try ids.map { slug in
                let count = try cache.count(bookId: slug)
                let title = (try? bookRepository.book(slug: slug))?.name ?? slug
                return BookCacheRow(slug: slug, title: title, versionCount: count)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            bookMetadata = [:]
            var uniqueChapters = 0
            for slug in ids {
                let meta = try cache.metadata(bookId: slug)
                uniqueChapters += Set(meta.map(\.chapterNumber)).count
                bookMetadata[slug] = meta
            }
            distinctChapters = uniqueChapters
            errorMessage = nil
        } catch {
            errorMessage = "Không thể tải bộ nhớ đệm: \(error.localizedDescription)"
            totalVersions = 0
            distinctChapters = 0
            books = []
        }
        isLoading = false
    }

    private func clearAll() async {
        guard let cache else { return }
        do {
            try cache.clearAll()
            bookMetadata.removeAll()
            expandedBookIds.removeAll()
            await load()
            router.toast.show("Đã xóa tất cả", type: .success)
        } catch {
            errorMessage = "Xóa tất cả thất bại: \(error.localizedDescription)"
            router.toast.show("Lỗi: không thể xóa", type: .error)
        }
    }

    private func clearBook(_ row: BookCacheRow) async {
        guard let cache else { return }
        do {
            try cache.clear(bookId: row.slug)
            bookMetadata.removeValue(forKey: row.slug)
            expandedBookIds.remove(row.slug)
            showClearBookConfirm = nil
            await load()
            router.toast.show("Đã xóa \(row.title)", type: .success)
        } catch {
            showClearBookConfirm = nil
            errorMessage = "Xóa \(row.title) thất bại: \(error.localizedDescription)"
            router.toast.show("Lỗi: không thể xóa", type: .error)
        }
    }
}
