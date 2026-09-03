import SwiftUI

/// LogScreen — Diagnostic Log Viewer (feat-014, UI scope).
/// Contract LogEntry/LogKind/DiagnosticsStore do lane fix-1 sở hữu (§1 plan): chỉ reference, không redefine.
struct LogScreen: View {
    let bookId: String?
    @State private var store: DiagnosticsStore
    @State private var kindFilter: LogKindFilter = .all
    @State private var selectedBook: String?
    @State private var selectedChapter: Int?
    @State private var query = ""
    @State private var groupMode: LogGroupMode = .timeline
    @State private var expandedIds: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(bookId: String? = nil, store: DiagnosticsStore = .shared) {
        self.bookId = bookId
        _store = State(initialValue: store)
        _selectedBook = State(initialValue: bookId)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            groupToggle
            Divider()
            contentList
        }
        .background(DesignTokens.backgroundWhite)
        .navigationTitle("Nhật ký")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refresh() }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacing8) {
                    ForEach(LogKindFilter.allCases) { kindChip($0) }
                }
                .padding(.horizontal, DesignTokens.sidePadding)
                .padding(.vertical, DesignTokens.spacing4)
            }
            HStack(spacing: DesignTokens.spacing8) {
                bookPicker
                chapterPicker
            }
            .padding(.horizontal, DesignTokens.sidePadding)
            searchField
        }
        .padding(.vertical, DesignTokens.spacing8)
    }

    private func kindChip(_ filter: LogKindFilter) -> some View {
        let selected = kindFilter == filter
        return Button { kindFilter = filter } label: {
            Text(filter.title)
                .font(.subheadline)
                .foregroundStyle(selected ? Color.white : DesignTokens.text)
                .padding(.horizontal, DesignTokens.spacing12)
                .padding(.vertical, DesignTokens.spacing8)
                .background(selected ? DesignTokens.accent : DesignTokens.backgroundGrouped)
                .clipShape(Capsule())
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("logFilter-\(filter.id)")
        .accessibilityLabel("Lọc \(filter.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var bookPicker: some View {
        Picker("Sách", selection: $selectedBook) {
            Text("Tất cả sách").tag(nil as String?)
            ForEach(availableBooks, id: \.self) { Text($0).tag($0 as String?) }
        }
        .pickerStyle(.menu)
        .tint(DesignTokens.text)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("logFilter-book")
        .accessibilityLabel("Lọc theo sách")
    }

    private var chapterPicker: some View {
        Picker("Chương", selection: $selectedChapter) {
            Text("Tất cả chương").tag(nil as Int?)
            ForEach(availableChapters, id: \.self) { Text("Chương \($0)").tag($0 as Int?) }
        }
        .pickerStyle(.menu)
        .tint(DesignTokens.text)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("logFilter-chapter")
        .accessibilityLabel("Lọc theo chương")
    }

    private var searchField: some View {
        HStack(spacing: DesignTokens.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.muted)
                .accessibilityHidden(true)
            TextField("Tìm requestId, host, mã lỗi…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("logFilter-search")
                .accessibilityLabel("Tìm trong nhật ký")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(DesignTokens.muted)
                }
                .a11yHitTarget()
                .accessibilityLabel("Xóa tìm kiếm")
            }
        }
        .padding(.horizontal, DesignTokens.spacing12)
        .frame(minHeight: 44)
        .background(DesignTokens.backgroundGrouped)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMedium))
        .padding(.horizontal, DesignTokens.sidePadding)
    }

    private var groupToggle: some View {
        Picker("Nhóm", selection: $groupMode) {
            ForEach(LogGroupMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DesignTokens.sidePadding)
        .padding(.bottom, DesignTokens.spacing8)
        .accessibilityIdentifier("logFilter-group")
    }

    @ViewBuilder
    private var contentList: some View {
        if filteredEntries.isEmpty {
            emptyState
        } else if groupMode == .timeline {
            List(filteredEntries) { row($0) }
                .listStyle(.plain)
                .accessibilityIdentifier("logList")
                .accessibilityLabel("Danh sách nhật ký, \(filteredEntries.count) mục")
        } else {
            List {
                ForEach(groupedEntries, id: \.chapter) { group in
                    Section("Chương \(group.chapter) (\(group.entries.count) mục)") {
                        ForEach(group.entries) { row($0) }
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("logList")
            .accessibilityLabel("Nhật ký theo chương, \(groupedEntries.count) nhóm")
        }
    }

    private func row(_ entry: LogEntry) -> some View {
        LogRowView(entry: entry, expanded: expandedIds.contains(entry.id)) { toggle(entry) }
            .listRowSeparator(.hidden)
            .accessibilityIdentifier("logRow-\(entry.id.uuidString)")
    }

    private var emptyState: some View {
        let isBlank = store.entries.isEmpty
        return VStack(spacing: DesignTokens.spacing8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(DesignTokens.muted)
                .accessibilityHidden(true)
            Text(isBlank ? "Chưa có nhật ký" : "Không khớp bộ lọc")
                .font(.headline)
                .foregroundStyle(DesignTokens.text)
            Text(isBlank
                ? "Mở sách và dùng AI Rewrite để tạo mục chẩn đoán mới."
                : "Thử đổi từ khóa hoặc bộ lọc khác.")
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.spacing24)
        .accessibilityIdentifier("logEmpty")
    }

    private var sortedEntries: [LogEntry] {
        store.entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var filteredEntries: [LogEntry] {
        sortedEntries.filter { entry in
            guard kindFilter.matches(entry) else { return false }
            if let selectedBook, entry.bookId != selectedBook {
                return false
            }
            if let selectedChapter, entry.chapterNumber != selectedChapter {
                return false
            }
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !needle.isEmpty else { return true }
            return entry.requestId.uuidString.lowercased().contains(needle)
                || (entry.host?.lowercased().contains(needle) ?? false)
                || (entry.errorDomain?.lowercased().contains(needle) ?? false)
                || (entry.errorCode.map { String($0).contains(needle) } ?? false)
                || (entry.event?.lowercased().contains(needle) ?? false)
                || (entry.detail?.lowercased().contains(needle) ?? false)
                || (entry.snippet?.lowercased().contains(needle) ?? false)
        }
    }

    private var groupedEntries: [(chapter: Int, entries: [LogEntry])] {
        Dictionary(grouping: filteredEntries) { $0.chapterNumber }
            .map { (chapter: $0.key, entries: $0.value) }
            .sorted { $0.chapter > $1.chapter }
    }

    private var availableBooks: [String] {
        Array(Set(sortedEntries.map { $0.bookId })).sorted()
    }

    private var availableChapters: [Int] {
        let numbers = selectedBook == nil
            ? sortedEntries.map { $0.chapterNumber }
            : sortedEntries.filter { $0.bookId == selectedBook }.map { $0.chapterNumber }
        return Array(Set(numbers)).sorted()
    }

    private func toggle(_ entry: LogEntry) {
        let apply = {
            if expandedIds.contains(entry.id) {
                expandedIds.remove(entry.id)
            } else {
                expandedIds.insert(entry.id)
            }
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { apply() }
        }
    }
}

// MARK: - Filter models (UI-only)

enum LogKindFilter: String, CaseIterable, Identifiable {
    case all, event, api, error
    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .all: return "Tất cả"
            case .event: return "Sự kiện"
            case .api: return "API"
            case .error: return "Lỗi"
        }
        // swiftlint:enable switch_case_alignment
    }

    func matches(_ entry: LogEntry) -> Bool {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .all: return true
            case .event: return entry.kind == .event
            case .api: return entry.kind == .api
            case .error: return LogRowView.isError(entry)
        }
        // swiftlint:enable switch_case_alignment
    }
}

enum LogGroupMode: String, CaseIterable, Identifiable {
    case timeline, byChapter
    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .timeline: return "Dòng thời gian"
            case .byChapter: return "Theo chương"
        }
        // swiftlint:enable switch_case_alignment
    }
}

// MARK: - Row (collapsed + expand)

struct LogRowView: View {
    let entry: LogEntry
    let expanded: Bool
    let onToggle: () -> Void
    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
                collapsedRow
                if expanded {
                    expandedDetail
                }
            }
            .padding(.vertical, DesignTokens.spacing8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel(rowVoiceLabel)
        .accessibilityHint(expanded ? "Chạm để thu gọn" : "Chạm để xem chi tiết")
        .accessibilityAddTraits(.isButton)
    }

    private var collapsedRow: some View {
        HStack(spacing: DesignTokens.spacing8) {
            Image(systemName: entry.kind == .api ? "arrow.left.arrow.right" : "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(kindColor)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText).font(.caption).monospacedDigit().foregroundStyle(DesignTokens.muted)
                Text(positionText).font(.subheadline).foregroundStyle(DesignTokens.text).lineLimit(2)
            }
            Spacer(minLength: DesignTokens.spacing8)
            VStack(alignment: .trailing, spacing: 4) {
                statusBadge
                Text("\(entry.latencyMs) ms")
                    .font(.caption).monospacedDigit().foregroundStyle(DesignTokens.muted)
            }
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
            Divider()
            detailLine(label: "Trạng thái", value: statusText)
            if let host = entry.host {
                detailLine(label: "Máy chủ", value: host)
            }
            if let model = entry.model {
                detailLine(label: "Mô hình", value: model)
            }
            if let event = entry.event {
                detailLine(label: "Sự kiện", value: event)
            }
            if let detail = entry.detail {
                detailLine(label: "Chi tiết", value: detail)
            }
            if let timeoutKind = entry.timeoutKind {
                detailLine(label: "Hết giờ", value: timeoutKind)
            }
            if let retryAfterMs = entry.retryAfterMs {
                detailLine(label: "Thử lại sau", value: "\(retryAfterMs) ms")
            }
            detailLine(
                label: "Yêu cầu",
                value: "\(entry.requestId.uuidString.prefix(8))… · Lần thử \(entry.attempt) · \(entry.mode)"
            )
            if let headers = entry.headersRedacted, !headers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Headers (giá trị nhạy cảm đã ẩn)")
                        .font(.caption).foregroundStyle(DesignTokens.muted)
                    ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text("\(key): \(value)").font(.caption).monospaced()
                            .foregroundStyle(DesignTokens.text).lineLimit(3)
                    }
                }
            }
            bodyBlock
        }
    }

    private var bodyBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nội dung (độ dài + mã băm)").font(.caption).foregroundStyle(DesignTokens.muted)
            if let bodyLen = entry.bodyLen {
                Text("Gửi: \(bodyLen) ký tự · \(entry.bodyHashPrefix ?? "—")")
                    .font(.caption).monospacedDigit().foregroundStyle(DesignTokens.text)
            }
            if let responseLen = entry.responseLen {
                Text("Nhận: \(responseLen) ký tự · \(entry.responseHashPrefix ?? "—")")
                    .font(.caption).monospacedDigit().foregroundStyle(DesignTokens.text)
            }
            if entry.bodyLen == nil, entry.responseLen == nil {
                Text("Không có nội dung đính kèm.").font(.caption).foregroundStyle(DesignTokens.muted)
            }
            if let snippet = entry.snippet, !snippet.isEmpty {
                Text("Đoạn trích: \(snippet)").font(.caption)
                    .foregroundStyle(DesignTokens.text).lineLimit(4)
            }
        }
    }

    private func detailLine(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacing8) {
            Text(label).font(.caption).foregroundStyle(DesignTokens.muted)
                .frame(width: 76, alignment: .leading)
            Text(value).font(.caption).foregroundStyle(DesignTokens.text)
            Spacer(minLength: 0)
        }
    }

    private var timeText: String {
        Self.timeFormatter.string(from: entry.timestamp)
    }

    private var positionText: String {
        var text = "\(entry.bookId) · Ch \(entry.chapterNumber)"
        if let index = entry.chunkIndex, let total = entry.chunkTotal {
            text += " · Đoạn \(index + 1)/\(total)"
        }
        if let event = entry.event, entry.kind == .event {
            text += " · \(event)"
        }
        return text
    }

    private var statusText: String {
        if let code = entry.statusCode {
            if let domain = entry.errorDomain {
                return "\(code) · \(domain)\(entry.errorCode.map { " \($0)" } ?? "")"
            }
            return "\(code)"
        }
        if let domain = entry.errorDomain {
            return "\(domain)\(entry.errorCode.map { " \($0)" } ?? "")"
        }
        return entry.event ?? (entry.kind == .api ? "API" : "Sự kiện")
    }

    private var statusBadge: some View {
        Text(badgeText).font(.caption2).bold().foregroundStyle(Color.white)
            .padding(.horizontal, DesignTokens.spacing8).padding(.vertical, 4)
            .background(badgeColor).clipShape(Capsule()).accessibilityHidden(true)
    }

    private var badgeText: String {
        if let code = entry.statusCode {
            return "\(code)"
        }
        if let event = entry.event {
            return shortEvent(event)
        }
        return entry.kind == .api ? "API" : "SK"
    }

    private var badgeColor: Color {
        if let code = entry.statusCode {
            if code < 300 {
                return DesignTokens.success
            }
            if code < 500 {
                return DesignTokens.warning
            }
            return DesignTokens.error
        }
        return Self.isError(entry) ? DesignTokens.error : DesignTokens.accent
    }

    private var kindColor: Color {
        entry.kind == .api ? DesignTokens.accent : DesignTokens.muted
    }

    private var rowVoiceLabel: String {
        "\(entry.kind == .api ? "API" : "Sự kiện"), \(positionText), \(statusText), \(entry.latencyMs) mili giây"
    }

    static func isError(_ entry: LogEntry) -> Bool {
        if let code = entry.statusCode, code >= 400 {
            return true
        }
        if entry.errorDomain != nil || entry.errorCode != nil {
            return true
        }
        let marker = (entry.event ?? "").lowercased()
        return marker.contains("fail") || marker.contains("error")
            || marker.contains("timeout") || marker.contains("cancel")
    }

    private func shortEvent(_ event: String) -> String {
        for prefix in ["chunk.", "prefetch.", "cache.", "retry."] where event.hasPrefix(prefix) {
            return String(event.dropFirst(prefix.count).prefix(10))
        }
        return String(event.prefix(10))
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm:ss.SSS dd/MM"
        return formatter
    }()
}
