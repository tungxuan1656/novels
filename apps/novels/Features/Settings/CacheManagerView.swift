import SwiftUI

struct CacheManagerView: View {
    @Environment(Router.self) private var router

    private let cache: ProcessedChapterCaching?

    @State private var total = 0
    @State private var rows: [(slug: String, count: Int)] = []
    @State private var isLoading = true
    @State private var showClearAllConfirm = false
    @State private var showClearBookConfirm: String?
    @State private var initError: String?

    init(cache: ProcessedChapterCaching? = nil) {
        if let cache {
            self.cache = cache
            _initError = State(initialValue: nil)
        } else if let prod = try? SQLiteProcessedChapterCache() {
            self.cache = prod
            _initError = State(initialValue: nil)
        } else if let mem = try? SQLiteProcessedChapterCache.inMemory() {
            self.cache = mem
            _initError = State(initialValue: nil)
        } else {
            self.cache = nil
            _initError = State(initialValue: "Bộ nhớ đệm không khả dụng")
        }
    }

    var body: some View {
        Group {
            if cache == nil {
                VStack(spacing: 16) {
                    Text(initError ?? "Bộ nhớ đệm không khả dụng")
                        .foregroundStyle(DesignTokens.text)
                        .multilineTextAlignment(.center)
                    Button("Thử lại") {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("retryCacheButton")
                    .accessibilityLabel("Thử lại")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.backgroundWhite)
            } else {
                List {
                    countCard
                    bookSection
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
            "Xóa cache cho \(showClearBookConfirm ?? "")?",
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
                if let slug = showClearBookConfirm {
                    Task { await clearBook(slug) }
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
                        Text(total == 0 ? "Chưa lưu chương nào" : "\(total) chương đã lưu")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Text("Máy giữ sẵn để mở lại nhanh hơn.")
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
                    .disabled(total == 0)
                    .opacity(total == 0 ? 0.4 : 1)
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
            if rows.isEmpty {
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
            } else {
                ForEach(rows, id: \.slug) { row in
                    HStack(spacing: DesignTokens.spacing8) {
                        Text(row.slug)
                            .font(.body)
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: DesignTokens.spacing8)
                        Text("\(row.count)")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(DesignTokens.muted)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 32)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DesignTokens.muted.opacity(0.2), in: Capsule())
                            .accessibilityLabel("\(row.count) chương")
                        Button(role: .destructive) {
                            showClearBookConfirm = row.slug
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
                        .accessibilityLabel("Xóa \(row.slug)")
                        .a11yHitTarget()
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("cache-\(row.slug)")
                    .listRowBackground(DesignTokens.surface)
                    .listRowSeparatorTint(DesignTokens.border)
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

    private func load() async {
        guard let cache else {
            initError = "Bộ nhớ đệm không khả dụng"
            isLoading = false
            total = 0
            rows = []
            return
        }
        isLoading = true
        do {
            total = try cache.countAll()
            let ids = try cache.allBookIds()
            rows = try ids.map { slug in
                try (slug, cache.count(bookId: slug))
            }
            .sorted { $0.slug < $1.slug }
            initError = nil
        } catch {
            total = 0
            rows = []
        }
        isLoading = false
    }

    private func clearAll() async {
        guard let cache else { return }
        do { try cache.clearAll() } catch {}
        await load()
        router.toast.show("Đã xóa tất cả", type: .success)
    }

    private func clearBook(_ slug: String) async {
        guard let cache else { return }
        do { try cache.clear(bookId: slug) } catch {}
        showClearBookConfirm = nil
        await load()
        router.toast.show("Đã xóa \(slug)", type: .success)
    }
}
