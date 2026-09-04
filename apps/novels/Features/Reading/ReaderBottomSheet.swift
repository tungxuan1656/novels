import SwiftUI

struct ReaderBottomSheet: View {
    @Bindable var settingsStore: SettingsStore
    var viewModel: ReaderViewModel?
    var onClose: () -> Void
    @Environment(Router.self) private var router: Router?
    @State private var diagnosticsStore: DiagnosticsStore = .shared

    let fonts = ReaderFontMapper.fonts

    var body: some View {
        BottomSheetView {
            VStack(spacing: 12) {
                HStack {
                    Text("Cài đặt đọc")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                    Button {
                        onClose()
                        router?.push(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .accessibilityLabel("Cài đặt")
                    .a11yHitTarget()
                }
                .padding(.top, 4)

                Divider()

                if let viewModel {
                    aiModeSection(viewModel: viewModel)
                    Divider()
                }

                HStack {
                    Text("Phông chữ")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                    Picker(
                        "Phông chữ",
                        selection: Binding(
                            get: { ReaderFontMapper.normalizedFontName(settingsStore.typography.font) },
                            set: {
                                settingsStore.typography.font = ReaderFontMapper.normalizedFontName($0)
                                settingsStore.save()
                            }
                        )
                    ) {
                        ForEach(fonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(DesignTokens.text)
                    .accessibilityIdentifier("fontPicker")
                }
                .frame(minHeight: 36)

                stepperRow(
                    title: "Cỡ chữ",
                    value: Binding(
                        get: { settingsStore.typography.fontSize },
                        set: { clampAndSaveFontSize($0) }
                    ),
                    range: 12 ... 40,
                    step: 1,
                    format: "%.0f"
                )

                stepperRow(
                    title: "Giãn dòng",
                    value: Binding(
                        get: { settingsStore.typography.lineHeight },
                        set: { clampAndSaveLineHeight($0) }
                    ),
                    range: 1.0 ... 50,
                    step: 0.5,
                    format: "%.1f"
                )

                stepperRow(
                    title: "Giãn chữ",
                    value: Binding(
                        get: { settingsStore.typography.letterSpacing },
                        set: { clampAndSaveLetterSpacing($0) }
                    ),
                    range: 0 ... 3.0,
                    step: 0.1,
                    format: "%.1f"
                )
            }
            .padding(.horizontal, DesignTokens.spacing12)
            .padding(.bottom, DesignTokens.spacing16)
        }
    }

    private func aiModeSection(viewModel: ReaderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Rewrite")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.text)

            HStack(spacing: 12) {
                Picker(
                    "AI Rewrite",
                    selection: Binding(
                        get: { viewModel.aiMode },
                        set: { newValue in
                            viewModel.aiMode = newValue
                            Task { await viewModel.setAIMode(newValue) }
                        }
                    )
                ) {
                    ForEach(AIMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("aiModePicker")

                Button("Xử lý lại") {
                    Task { await viewModel.reprocess() }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.aiMode == .none || viewModel.isAIProcessing)
                .opacity(viewModel.aiMode == .none || viewModel.isAIProcessing ? 0.4 : 1)
                .accessibilityIdentifier("reprocessButton")
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())

            apiLogButton(viewModel: viewModel)
        }
    }

    private func apiLogButton(viewModel: ReaderViewModel) -> some View {
        let hasErrors = diagnosticsStore.errorCount > 0
        let title = hasErrors ? "Nhật ký · \(diagnosticsStore.errorCount) lỗi" : "Nhật ký"
        let voiceLabel = hasErrors
            ? "Nhật ký chẩn đoán, có \(diagnosticsStore.errorCount) lỗi"
            : "Nhật ký chẩn đoán"
        let hint = hasErrors ? "Mở nhật ký, lọc lỗi" : "Mở nhật ký chẩn đoán"
        let initialFilter: LogKindFilter = hasErrors ? .error : .all
        return Button {
            onClose()
            router?.push(.apiLog(bookId: viewModel.bookId, initialFilter: initialFilter))
        } label: {
            HStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(DesignTokens.muted)
                    if hasErrors {
                        Circle()
                            .fill(DesignTokens.error)
                            .frame(width: 10, height: 10)
                            .offset(x: 5, y: -4)
                            .accessibilityHidden(true)
                    }
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("apiLogButton")
        .accessibilityLabel(voiceLabel)
        .accessibilityHint(hint)
        .task {
            await diagnosticsStore.refresh()
        }
    }

    private func stepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.text)
            Spacer()
            HStack(spacing: 8) {
                Stepper(value: value, in: range, step: step) {
                    Text(title)
                }
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityValue(String(format: format, value.wrappedValue))

                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.text)
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private func clampAndSaveFontSize(_ value: Double) {
        settingsStore.typography.fontSize = min(max(12, value), 40)
        settingsStore.save()
    }

    private func clampAndSaveLineHeight(_ value: Double) {
        settingsStore.typography.lineHeight = min(max(1.0, value), 50)
        settingsStore.save()
    }

    private func clampAndSaveLetterSpacing(_ value: Double) {
        settingsStore.typography.letterSpacing = min(max(0, value), 3.0)
        settingsStore.save()
    }
}
