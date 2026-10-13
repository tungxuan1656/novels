import SwiftUI

struct SettingsView: View {
    @Environment(Router.self) private var router
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        List {
            Section("Danh mục") {
                row(
                    key: "BOOKS_API_URL",
                    label: SettingsViewModel.descriptor(for: "BOOKS_API_URL").label,
                    value: settings.booksAPIURL
                )
            }
            Section("Dịch thuật AI") {
                row(
                    key: "OPENAI_API_URL",
                    label: SettingsViewModel.descriptor(for: "OPENAI_API_URL").label,
                    value: settings.openaiAPIURL
                )
                row(
                    key: "OPENAI_MODEL",
                    label: SettingsViewModel.descriptor(for: "OPENAI_MODEL").label,
                    value: settings.openaiModel
                )
                row(
                    key: "AI_API_KEY",
                    label: SettingsViewModel.descriptor(for: "AI_API_KEY").label,
                    value: SettingsViewModel.apiKeyRowValue(settings)
                )
                row(
                    key: "AI_PROVIDER",
                    label: SettingsViewModel.descriptor(for: "AI_PROVIDER").label,
                    value: SettingsViewModel.providerRowValue(settings)
                )
                row(
                    key: "AI_THINKING_EFFORT",
                    label: SettingsViewModel.descriptor(for: "AI_THINKING_EFFORT").label,
                    value: settings.aiThinkingEffort.isEmpty
                        ? "Mặc định (theo mô hình)"
                        : (AIThinkingEffort.normalized(settings.aiThinkingEffort)?.title ?? settings.aiThinkingEffort)
                )
                row(
                    key: "AI_PROMPT",
                    label: SettingsViewModel.descriptor(for: "AI_PROMPT").label,
                    value: settings.aiPrompt
                )
                row(
                    key: "AI_BILINGUAL_PROMPT",
                    label: SettingsViewModel.descriptor(for: "AI_BILINGUAL_PROMPT").label,
                    value: settings.aiBilingualPrompt
                )
                row(
                    key: "AI_MIN_CHUNK_SIZE",
                    label: SettingsViewModel.descriptor(for: "AI_MIN_CHUNK_SIZE").label,
                    value: "\(settings.aiMinChunkSize)"
                )
                row(
                    key: "AI_CUSTOM_HEADERS",
                    label: SettingsViewModel.descriptor(for: "AI_CUSTOM_HEADERS").label,
                    value: settings.aiCustomHeadersJSON
                )
                row(
                    key: "AI_EXTRA_BODY",
                    label: SettingsViewModel.descriptor(for: "AI_EXTRA_BODY").label,
                    value: settings.aiExtraBodyJSON
                )
            }
            Section("Giọng đọc (Audio)") {
                row(
                    key: "AUDIO_SOURCE",
                    label: SettingsViewModel.descriptor(for: "AUDIO_SOURCE").label,
                    value: settings.audioSource.title
                )
                if settings.audioSource == .api {
                    row(
                        key: "AUDIO_API_KEY",
                        label: SettingsViewModel.descriptor(for: "AUDIO_API_KEY").label,
                        value: SettingsViewModel.apiKeyRowValue(settings, key: "AUDIO_API_KEY")
                    )
                    row(
                        key: "AUDIO_MODEL",
                        label: SettingsViewModel.descriptor(for: "AUDIO_MODEL").label,
                        value: settings.audioModel
                    )
                }
            }
            Section("Tải trước") {
                row(
                    key: "PREFETCH_COUNT",
                    label: SettingsViewModel.descriptor(for: "PREFETCH_COUNT").label,
                    value: SettingsViewModel.prefetchCountRowValue(settings)
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
        .safeAreaInset(edge: .bottom) {
            Text("Phiên bản \(appVersion)")
                .font(.footnote)
                .foregroundStyle(DesignTokens.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignTokens.backgroundWhite)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
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
