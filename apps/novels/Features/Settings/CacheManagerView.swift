import SwiftUI

struct CacheManagerView: View {
    @Environment(Router.self) private var router

    private let cache: ProcessedChapterCaching

    @State private var total = 0
    @State private var rows: [(slug: String, count: Int)] = []
    @State private var isLoading = true
    @State private var showClearAllConfirm = false
    @State private var showClearBookConfirm: String?

    init(cache: ProcessedChapterCaching? = nil) {
        if let cache {
            self.cache = cache
        } else if let prod = try? SQLiteProcessedChapterCache() {
            self.cache = prod
        } else if let mem = try? SQLiteProcessedChapterCache.inMemory() {
            self.cache = mem
        } else {
            fatalError("Unable to initialize cache — inMemory should always succeed")
        }
    }

    var body: some View {
        List {
            countCard
            bookSection
        }
        .navigationTitle("Quản lý bộ nhớ đệm")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.backgroundPaper)
        .task { await load() }
        .refreshable { await load() }
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
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            }
        }
    }

    private var countCard: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tổng số bản đã xử lý: \(total)")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.text)
                Text("Lưu trong processed_chapters.sqlite — xóa sẽ trống ngay")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
                Button(role: .destructive) {
                    showClearAllConfirm = true
                } label: {
                    Label("Xóa tất cả", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.error)
                .disabled(total == 0)
                .accessibilityIdentifier("clearAllButton")
            }
            .padding(.vertical, 4)
            .listRowBackground(DesignTokens.surface)
        }
    }

    private var bookSection: some View {
        Section("Theo sách") {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if rows.isEmpty {
                Text("Chưa có dữ liệu đệm")
                    .foregroundStyle(DesignTokens.muted)
            } else {
                ForEach(rows, id: \.slug) { row in
                    HStack {
                        Text(row.slug)
                            .lineLimit(1)
                            .foregroundStyle(DesignTokens.text)
                        Spacer()
                        Text("\(row.count)")
                            .foregroundStyle(DesignTokens.muted)
                        Button("Xóa", role: .destructive) {
                            showClearBookConfirm = row.slug
                        }
                        .accessibilityIdentifier("clear-\(row.slug)")
                    }
                    .accessibilityIdentifier("cache-\(row.slug)")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        do {
            total = try cache.countAll()
            let ids = try cache.allBookIds()
            rows = try ids.map { slug in
                try (slug, cache.count(bookId: slug))
            }
            .sorted { $0.slug < $1.slug }
        } catch {
            total = 0
            rows = []
        }
        isLoading = false
    }

    private func clearAll() async {
        do { try cache.clearAll() } catch {}
        await load()
        router.toast.show("Đã xóa tất cả", type: .success)
    }

    private func clearBook(_ slug: String) async {
        do { try cache.clear(bookId: slug) } catch {}
        showClearBookConfirm = nil
        await load()
        router.toast.show("Đã xóa \(slug)", type: .success)
    }
}
