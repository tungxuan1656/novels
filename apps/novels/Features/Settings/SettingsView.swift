import SwiftUI

struct SettingsView: View {
    @Environment(Router.self) private var router
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        List {
            Section("Danh mục") {
                row(key: "BOOKS_API_URL", label: "URL Danh mục", value: settings.booksAPIURL)
            }
            Section("AI") {
                row(key: "OPENAI_API_URL", label: "URL OpenAI", value: settings.openaiAPIURL)
                row(key: "OPENAI_MODEL", label: "Mô hình", value: settings.openaiModel)
                row(
                    key: "AI_CUSTOM_HEADERS",
                    label: "Headers tùy chỉnh (JSON)",
                    value: settings.aiCustomHeadersJSON
                )
                row(
                    key: "AI_EXTRA_BODY",
                    label: "Body bổ sung (JSON)",
                    value: settings.aiExtraBodyJSON
                )
                row(
                    key: "AI_PROMPT",
                    label: "Prompt",
                    value: settings.aiPrompt
                )
                row(
                    key: "AI_MIN_CHUNK_SIZE",
                    label: "Kích thước chunk",
                    value: "\(settings.aiMinChunkSize)"
                )
            }
            Section("Tải trước") {
                row(
                    key: "PREFETCH_COUNT",
                    label: "Số chương tải trước",
                    value: "\(settings.prefetchCount)"
                )
            }
            Section("Dữ liệu") {
                NavigationLink(value: Router.Route.cacheManager) {
                    Label("Quản lý bộ nhớ đệm", systemImage: "internaldrive")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .listRowBackground(DesignTokens.surface)
                .accessibilityIdentifier("settings-CACHE")
                NavigationLink(value: Router.Route.apiLog(bookId: nil, initialFilter: .all)) {
                    Label("Nhật ký", systemImage: "doc.text.magnifyingglass")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .listRowBackground(DesignTokens.surface)
                .accessibilityIdentifier("settings-LOG")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.backgroundWhite)
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(key: String, label: String, value: String) -> some View {
        NavigationLink(value: Router.Route.settingEditor(settingKey: key)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.text)
                Text(value.isEmpty ? "—" : String(value.prefix(60)))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
                    .lineLimit(1)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .listRowBackground(DesignTokens.surface)
        .accessibilityIdentifier("settings-\(key)")
    }
}
