import SwiftUI

// swiftlint:disable file_length

/// LogScreen — Diagnostic Log Viewer (feat-019, UI scope).
/// Groups entries by chapter-run (runId); entries without runId go to "Phiên chung".
/// Contract LogEntry/LogKind/DiagnosticsStore owned by another lane: reference only, never redefine.
struct LogScreen: View {
    let bookId: String?
    let initialFilter: LogKindFilter
    @State private var store: DiagnosticsStore
    @State private var query = ""
    @State private var groupExpanded: Set<String> = []
    @State private var savedExpanded: Set<String> = []
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
            // Search owns expansion while a query is active; auto-expand only on entry.
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if initialFilter == .error {
                    groupExpanded = Set(filteredGroups.filter { $0.status == .failed }.map { $0.id })
                } else if groupExpanded.isEmpty, let newest = runGroups.first {
                    groupExpanded = [newest.id]
                }
            }
            await store.observe()
        }
        .refreshable {
            await store.refresh()
        }
        .onChange(of: query) { oldValue, newValue in
            let wasSearching = !oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isSearching = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isSearching {
                if !wasSearching {
                    savedExpanded = groupExpanded
                }
                groupExpanded = Set(filteredGroups.map { $0.id })
            } else if wasSearching {
                groupExpanded = savedExpanded
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
        .background(DesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMedium))
        .padding(.horizontal, DesignTokens.sidePadding)
        .padding(.vertical, DesignTokens.spacing8)
    }

    @ViewBuilder
    private var contentList: some View {
        if filteredGroups.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                List(filteredGroups) { group in
                    groupCell(group)
                        .listRowSeparator(.hidden)
                        .listRowBackground(DesignTokens.backgroundWhite)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(DesignTokens.backgroundWhite)
                .accessibilityIdentifier("logList")
                .accessibilityLabel("Danh sách nhật ký, \(filteredGroups.count) nhóm")
                // Reports ring eviction, so it always reflects the ring total,
                // even when the visible list is narrowed by book or search.
                if store.entries.count >= DiagnosticsLog.capacity {
                    Text("Chỉ giữ \(DiagnosticsLog.capacity) mục mới nhất · mục cũ tự xóa")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                        .padding(.vertical, DesignTokens.spacing8)
                }
            }
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
                        Text(groupSubtitle(group))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.muted)
                            .lineLimit(1)
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
                Divider()
                ForEach(group.entries) { entry in
                    innerCell(entry)
                }
            }
        }
    }

    private func groupSubtitle(_ group: LogRunGroup) -> String {
        // Entries arrive newest-first, so the last one is the earliest — no scan per row.
        // Count, range, and latest describe the visible entries (search hits when
        // filtering); title, status, and progress always reflect the full run.
        let earliest = group.entries.last?.timestamp ?? group.latest
        let start = logGroupHourFormatter.string(from: earliest)
        if Calendar.current.isDate(earliest, inSameDayAs: group.latest) {
            return "\(group.entries.count) mục · \(start)–\(logGroupHourFormatter.string(from: group.latest))"
        }
        let range = "\(logGroupDayFormatter.string(from: earliest))–\(logGroupDayFormatter.string(from: group.latest))"
        return "\(group.entries.count) mục · \(range)"
    }

    private func innerCell(_ entry: LogEntry) -> some View {
        let hasBody = entry.requestBody != nil || entry.responseBody != nil
        return VStack(alignment: .leading, spacing: 0) {
            LogRowView(entry: entry, expanded: innerExpanded.contains(entry.id), isFiltered: bookId != nil) {
                toggleInner(entry)
            }
            .accessibilityIdentifier("logRow-\(entry.id.uuidString)")
            if innerExpanded.contains(entry.id), hasBody {
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
        var scoped = store.entries
        if let bookId {
            scoped = scoped.filter { $0.bookId == bookId }
        }
        if initialFilter != .all {
            scoped = scoped.filter { initialFilter.matches($0) }
        }
        return LogRunBuilder.build(from: scoped)
    }

    private var filteredGroups: [LogRunGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return runGroups }
        return runGroups.compactMap { group in
            guard LogRunBuilder.matches(group, needle: needle) else { return nil }
            let hits = LogRunBuilder.matchedEntries(group, needle: needle)
            guard !hits.isEmpty else { return group }
            // Search narrows the visible scope: entries and latest describe the
            // hits, while title/status/progress still reflect the full run.
            return LogRunGroup(
                id: group.id,
                title: group.title,
                latest: hits.first?.timestamp ?? group.latest,
                entries: hits,
                status: group.status,
                chunkProgress: group.chunkProgress
            )
        }
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

private let logGroupHourFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.dateFormat = "HH:mm:ss"
    return formatter
}()

private let logGroupDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.dateFormat = "HH:mm:ss dd/MM"
    return formatter
}()

// MARK: - Run grouping (UI-only, feat-019)

enum LogRunStatus: String, Equatable {
    case failed, success, processing, cancelled

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .failed: return "Thất bại"
            case .success: return "Thành công"
            case .processing: return "Đang xử lý"
            case .cancelled: return "Đã hủy"
        }
        // swiftlint:enable switch_case_alignment
    }

    var color: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .failed: return DesignTokens.error
            case .success: return DesignTokens.success
            case .processing: return DesignTokens.accent
            case .cancelled: return DesignTokens.muted
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
        let sorted = entries.sorted { $0.timestamp > $1.timestamp }
        let newestError = sorted.first(where: LogEntry.isError)?.timestamp
        var newestSuccess: Date?
        for entry in sorted where entry.event == "cache.save" || entry.event == "cache.hit" || isAllCachedSkip(entry) {
            newestSuccess = max(newestSuccess ?? .distantPast, entry.timestamp)
        }
        // Only joined shares count: a lone share newer than the last error
        // must not clear Failed, it has no origin save in this group.
        let savedHashes = Set(entries.filter { $0.event == "cache.save" }.compactMap(keyHash(of:)))
        let joinedStamp = sorted
            .filter { $0.event == "dedup.shared" }
            .compactMap { entry -> Date? in
                guard let hash = keyHash(of: entry), savedHashes.contains(hash) else { return nil }
                return entry.timestamp
            }
            .max()
        if let joinedStamp {
            newestSuccess = max(newestSuccess ?? .distantPast, joinedStamp)
        }
        if let total = entries.compactMap({ $0.chunkTotal }).first, total > 0 {
            let done = Set(entries.filter { $0.event == "chunk.success" }.compactMap { $0.chunkIndex }).count
            let lastChunk = sorted.first(where: { $0.event == "chunk.success" })?.timestamp
            if done >= total, let lastChunk {
                newestSuccess = max(newestSuccess ?? .distantPast, lastChunk)
            }
        }
        // Retry-after-failure: a strictly newer terminal success clears an older
        // error; a tie still reads failed so simultaneous writes never mask a fault.
        if let ok = newestSuccess, let err = newestError {
            return ok > err ? .success : .failed
        }
        if newestError != nil {
            return .failed
        }
        if newestSuccess != nil {
            return .success
        }
        if entries.contains(where: LogEntry.isMutedCancel) {
            return .cancelled
        }
        return .processing
    }

    /// Extracts `keyHash=<token>` from a cache-event detail for origin joining.
    static func keyHash(of entry: LogEntry) -> String? {
        guard let detail = entry.detail,
              let range = detail.range(of: "keyHash=")
        else { return nil }
        let token = detail[range.upperBound...].prefix(while: { !$0.isWhitespace })
        return token.isEmpty ? nil : String(token)
    }

    /// `dedup.shared` is terminal only when joined with its origin `cache.save`
    /// in the same group (equal `keyHash`); a lone share with no origin stays non-terminal.
    static func isJoinedDedupSuccess(_ entries: [LogEntry]) -> Bool {
        let sharedHashes = Set(entries.filter { $0.event == "dedup.shared" }.compactMap(keyHash(of:)))
        guard !sharedHashes.isEmpty else { return false }
        let savedHashes = Set(entries.filter { $0.event == "cache.save" }.compactMap(keyHash(of:)))
        return !sharedHashes.isDisjoint(with: savedHashes)
    }

    /// `prefetch.skip` with nothing left to fetch is terminal success; other skip
    /// reasons (modeNone, invalidRange) stay `.processing`.
    static func isAllCachedSkip(_ entry: LogEntry) -> Bool {
        guard entry.event == "prefetch.skip", let detail = entry.detail else { return false }
        return detail.contains("reason=allCached") || detail.contains("reason=emptyRange")
    }

    static func chunkProgress(of entries: [LogEntry]) -> String? {
        guard let total = entries.compactMap({ $0.chunkTotal }).first, total > 0 else { return nil }
        let done = Set(entries.filter { $0.event == "chunk.success" }.compactMap { $0.chunkIndex }).count
        return "\(done)/\(total) chunk"
    }

    static func title(chapter: Int, mode: String, entries: [LogEntry] = []) -> String {
        let base = "\(mode.prefix(1).uppercased() + mode.dropFirst()) · Ch \(chapter)"
        guard !entries.isEmpty, let suffix = sourceSuffix(of: entries) else { return base }
        return "\(base) · \(suffix)"
    }

    /// Origin suffix so two runs of the same chapter never share a title:
    /// "Cache" (hit/save) > "Dùng chung" (joined share) > "API done/total".
    /// A lone share with no joined origin falls through to the API branch.
    static func sourceSuffix(of entries: [LogEntry]) -> String? {
        if entries.contains(where: { $0.event == "cache.hit" || $0.event == "cache.save" }) {
            return "Cache"
        }
        if isJoinedDedupSuccess(entries) {
            return "Dùng chung"
        }
        if let total = entries.compactMap({ $0.chunkTotal }).first, total > 0 {
            let done = Set(entries.filter { $0.event == "chunk.success" }.compactMap { $0.chunkIndex }).count
            return "API \(done)/\(total)"
        }
        if entries.contains(where: { $0.kind == .api }) {
            return "API"
        }
        return nil
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
        return !matchedEntries(group, needle: needle).isEmpty
    }

    /// Intra-group hits for burst search: only matching entries expand inline.
    static func matchedEntries(_ group: LogRunGroup, needle: String) -> [LogEntry] {
        let query = needle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return group.entries }
        return group.entries.filter { entry in
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
        } else if let representative = sorted.last {
            title = self.title(chapter: representative.chapterNumber, mode: representative.mode, entries: sorted)
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
            case .error: return LogEntry.isError(entry)
        }
        // swiftlint:enable switch_case_alignment
    }
}

// MARK: - Row (collapsed + expand)

struct LogRowView: View {
    let entry: LogEntry
    let expanded: Bool
    let isFiltered: Bool
    let onToggle: () -> Void

    init(entry: LogEntry, expanded: Bool, isFiltered: Bool = false, onToggle: @escaping () -> Void) {
        self.entry = entry
        self.expanded = expanded
        self.isFiltered = isFiltered
        self.onToggle = onToggle
    }

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
            if let reason = LogEntry.cancelReason(of: entry) {
                detailLine(label: "Lý do hủy", value: reason)
            }
            if let hash = LogRunBuilder.keyHash(of: entry) {
                detailLine(label: "Khóa", value: hash)
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
        var text = isFiltered ? "Ch \(entry.chapterNumber)" : "\(entry.bookId) · Ch \(entry.chapterNumber)"
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
            .lineLimit(1)
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
        return LogEntry.isError(entry) ? DesignTokens.error : DesignTokens.accent
    }

    private var kindColor: Color {
        entry.kind == .api ? DesignTokens.accent : DesignTokens.muted
    }

    private var rowVoiceLabel: String {
        "\(entry.kind == .api ? "API" : "Sự kiện"), \(positionText), \(statusText), \(entry.latencyMs) mili giây"
    }

    private func shortEvent(_ event: String) -> String {
        String(event.prefix(16))
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm:ss.SSS dd/MM"
        return formatter
    }()
}
