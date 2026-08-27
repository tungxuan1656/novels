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
                row(key: "AI_PROVIDER", label: "Nhà cung cấp", value: settings.aiProvider)
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
                    key: "AI_PROCESS_ACTIONS",
                    label: "Hành động AI (JSON)",
                    value: settings.aiProcessActionsJSON
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
            Section("Kiểu chữ") {
                row(key: "font", label: "Phông chữ", value: settings.typography.font)
                row(
                    key: "fontSize",
                    label: "Cỡ chữ",
                    value: String(format: "%g", settings.typography.fontSize)
                )
                row(
                    key: "lineHeight",
                    label: "Giãn dòng",
                    value: String(format: "%.1f", settings.typography.lineHeight)
                )
                row(
                    key: "letterSpacing",
                    label: "Giãn chữ",
                    value: String(format: "%.1f", settings.typography.letterSpacing)
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
                .accessibilityIdentifier("settings-CACHE")
            }
        }
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.backgroundPaper)
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
        .accessibilityIdentifier("settings-\(key)")
    }
}
