import SwiftUI

// swiftlint:disable file_length

/// LogScreen — Diagnostic Log Viewer (feat-019, UI scope).
/// Groups entries by chapter-run (runId); entries without runId go to "Phiên chung".
/// Contract LogEntry/LogKind/DiagnosticsStore do lane khác sở hữu: chỉ reference, không redefine.
struct LogScreen: View {
    let bookId: String?
    let initialFilter: LogKindFilter
    @State private var store: DiagnosticsStore
    @State private var query = ""
    @State private var groupExpanded: Set<String> = []
    @State private var innerExpanded: Set<UUID> = []
    @State private var selectedJSONEntry: LogEntry?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(bookId: String? = nil, store: DiagnosticsStore = .shared, initialFilter: LogKindFilter = .all) {
        self.bookId = bookId
        _store = State(initialValue: store)
        self.initialFilter = initialFilter
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            contentList
        }
        .background(DesignTokens.backgroundWhite)
        .navigationTitle("Nhật ký")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refresh()
            if initialFilter == .error {
                groupExpanded = Set(filteredGroups.filter { $0.status == .failed }.map { $0.id })
            }
        }
        .sheet(item: $selectedJSONEntry) { entry in
            jsonSheet(entry)
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignTokens.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.muted)
                .accessibilityHidden(true)
            TextField("Tìm chương, trạng thái, sự kiện…", text: $query)
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
        .padding(.vertical, DesignTokens.spacing8)
    }

    @ViewBuilder
    private var contentList: some View {
        if filteredGroups.isEmpty {
            emptyState
        } else {
            List(filteredGroups) { group in
                groupCell(group)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .accessibilityIdentifier("logList")
            .accessibilityLabel("Danh sách nhật ký, \(filteredGroups.count) nhóm")
        }
    }

    private func groupCell(_ group: LogRunGroup) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
            Button {
                toggleGroup(group.id)
            } label: {
                HStack(spacing: DesignTokens.spacing8) {
                    Image(systemName: groupExpanded.contains(group.id) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                        Text(LogRowView.timeFormatter.string(from: group.latest))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Spacer(minLength: DesignTokens.spacing8)
                    VStack(alignment: .trailing, spacing: 4) {
                        statusBadge(group.status)
                        if let progress = group.chunkProgress {
                            Text(progress)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                }
                .padding(.vertical, DesignTokens.spacing8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityIdentifier("logGroup-\(group.id)")
            .accessibilityLabel("\(group.title), \(group.status.title)")
            .accessibilityHint(groupExpanded.contains(group.id) ? "Chạm để thu gọn" : "Chạm để xem chi tiết")
            .accessibilityAddTraits(.isButton)
            if groupExpanded.contains(group.id) {
                ForEach(group.entries) { entry in
                    innerCell(entry)
                }
            }
        }
    }

    private func innerCell(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LogRowView(entry: entry, expanded: innerExpanded.contains(entry.id)) { toggleInner(entry) }
                .accessibilityIdentifier("logRow-\(entry.id.uuidString)")
            if innerExpanded.contains(entry.id), entry.kind == .api {
                Button("Xem JSON thô") { selectedJSONEntry = entry }
                    .accessibilityIdentifier("logJsonButton")
                    .accessibilityLabel("Xem JSON thô")
                    .padding(.leading, 30)
                    .padding(.vertical, DesignTokens.spacing4)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func statusBadge(_ status: LogRunStatus) -> some View {
        Text(status.title)
            .font(.caption2).bold().foregroundStyle(Color.white)
            .padding(.horizontal, DesignTokens.spacing8).padding(.vertical, 4)
            .background(status.color).clipShape(Capsule()).accessibilityHidden(true)
    }

    private func jsonSheet(_ entry: LogEntry) -> some View {
        BottomSheetView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
                Text("JSON thô")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.text)
                Text("Request")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.text)
                ScrollView {
                    Text(entry.requestBody ?? "Không có body")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("logJsonRequest")
                }
                .frame(maxHeight: 220)
                Text("Response")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.text)
                ScrollView {
                    Text(entry.responseBody ?? "Không có body")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("logJsonResponse")
                }
                .frame(maxHeight: 220)
            }
            .padding(.top, DesignTokens.spacing8)
        }
        .accessibilityIdentifier("logJsonSheet")
        .presentationDetents([.medium, .large])
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
                : "Thử đổi từ khóa khác.")
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.spacing24)
        .accessibilityIdentifier("logEmpty")
    }

    private var runGroups: [LogRunGroup] {
        LogRunBuilder.build(from: store.entries)
    }

    private var filteredGroups: [LogRunGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return runGroups }
        return runGroups.filter { LogRunBuilder.matches($0, needle: needle) }
    }

    private func toggleGroup(_ id: String) {
        let apply = {
            if groupExpanded.contains(id) {
                groupExpanded.remove(id)
            } else {
                groupExpanded.insert(id)
            }
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { apply() }
        }
    }

    private func toggleInner(_ entry: LogEntry) {
        let apply = {
            if innerExpanded.contains(entry.id) {
                innerExpanded.remove(entry.id)
            } else {
                innerExpanded.insert(entry.id)
            }
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { apply() }
        }
    }
}

// MARK: - Run grouping (UI-only, feat-019)

enum LogRunStatus: String, Equatable {
    case failed, success, processing

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .failed: return "Thất bại"
            case .success: return "Thành công"
            case .processing: return "Đang xử lý"
        }
        // swiftlint:enable switch_case_alignment
    }

    var color: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .failed: return DesignTokens.error
            case .success: return DesignTokens.success
            case .processing: return DesignTokens.accent
        }
        // swiftlint:enable switch_case_alignment
    }
}

struct LogRunGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let latest: Date
    let entries: [LogEntry]
    let status: LogRunStatus
    let chunkProgress: String?
}

enum LogRunBuilder {
    static let commonGroupId = "common"
    static let commonGroupTitle = "Phiên chung"

    static func build(from entries: [LogEntry]) -> [LogRunGroup] {
        let sorted = entries.sorted { $0.timestamp > $1.timestamp }
        var order: [String] = []
        var buckets: [String: [LogEntry]] = [:]
        for entry in sorted {
            let key = entry.runId?.uuidString ?? commonGroupId
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(entry)
        }
        var groups: [LogRunGroup] = []
        for key in order {
            guard let bucket = buckets[key], !bucket.isEmpty else { continue }
            groups.append(makeGroup(id: key, entries: bucket))
        }
        return groups.sorted {
            if $0.id == commonGroupId {
                return false
            }
            if $1.id == commonGroupId {
                return true
            }
            return $0.latest > $1.latest
        }
    }

    static func status(of entries: [LogEntry]) -> LogRunStatus {
        if entries.contains(where: LogRowView.isError) {
            return .failed
        }
        if entries.contains(where: { $0.event == "cache.save" }) {
            return .success
        }
        if let total = entries.compactMap({ $0.chunkTotal }).first, total > 0 {
            let done = Set(entries.filter { $0.event == "chunk.success" }.compactMap { $0.chunkIndex }).count
            if done >= total {
                return .success
            }
        }
        return .processing
    }

    static func chunkProgress(of entries: [LogEntry]) -> String? {
        guard let total = entries.compactMap({ $0.chunkTotal }).first, total > 0 else { return nil }
        let done = Set(entries.filter { $0.event == "chunk.success" }.compactMap { $0.chunkIndex }).count
        return "\(done)/\(total) chunk"
    }

    static func title(chapter: Int, mode: String) -> String {
        "\(mode.prefix(1).uppercased() + mode.dropFirst()) · Ch \(chapter)"
    }

    /// Narrow search: chapter number, group status words, event, detail, snippet.
    /// Never matches requestId/host/error codes.
    static func matches(_ group: LogRunGroup, needle: String) -> Bool {
        let query = needle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        if group.title.lowercased().contains(query) {
            return true
        }
        if group.status.title.lowercased().contains(query) {
            return true
        }
        return group.entries.contains { entry in
            (entry.event?.lowercased().contains(query) ?? false)
                || (entry.detail?.lowercased().contains(query) ?? false)
                || (entry.snippet?.lowercased().contains(query) ?? false)
        }
    }

    private static func makeGroup(id: String, entries: [LogEntry]) -> LogRunGroup {
        let sorted = entries.sorted { $0.timestamp > $1.timestamp }
        let latest = sorted.first?.timestamp ?? .distantPast
        let title: String
        if id == commonGroupId {
            title = commonGroupTitle
        } else if let representative = sorted.first {
            title = self.title(chapter: representative.chapterNumber, mode: representative.mode)
        } else {
            title = commonGroupTitle
        }
        return LogRunGroup(
            id: id,
            title: title,
            latest: latest,
            entries: sorted,
            status: status(of: sorted),
            chunkProgress: chunkProgress(of: sorted)
        )
    }
}

// MARK: - Filter models (UI-only)

enum LogKindFilter: String, CaseIterable, Identifiable, Hashable {
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
            if let keys = entry.responseJsonKeys {
                detailLine(label: "Dạng", value: keys.joined(separator: ", "))
            }
            if let count = entry.choicesCount {
                detailLine(label: "Choices", value: "\(count)")
            }
            if let kind = entry.contentKind {
                detailLine(label: "Nội dung", value: kind)
            }
            if let hasReasoning = entry.hasReasoningContent {
                detailLine(label: "Suy luận", value: hasReasoning ? "Có" : "Không")
            }
            if let hasTools = entry.hasToolCalls {
                detailLine(label: "Tool", value: hasTools ? "Có" : "Không")
            }
            detailLine(
                label: "Yêu cầu",
                value: "\(entry.requestId.uuidString.prefix(8))… · Lần thử \(entry.attempt) · \(entry.mode)"
            )
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
