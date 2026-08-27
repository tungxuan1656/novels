import SwiftUI

struct ReaderBottomSheet: View {
    @Bindable var settingsStore: SettingsStore
    var viewModel: ReaderViewModel?
    var onClose: () -> Void
    @State private var showGearToast = false
    /// Source of truth for font names is ReaderFontDesign (ScrollOffsetPreference.swift) — keep in sync:
    /// System/Serif/Mono
    let fonts = ["System", "Serif", "Mono"]

    var body: some View {
        BottomSheetView {
            VStack(spacing: DesignTokens.spacing16) {
                HStack {
                    Text("Cài đặt đọc")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .accessibilityLabel("Đóng")
                    .a11yHitTarget()
                    Button {
                        withAnimation { showGearToast = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { showGearToast = false }
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .accessibilityLabel("Cài đặt")
                    .a11yHitTarget()
                }
                Divider()
                if let viewModel {
                    aiModeSection(viewModel: viewModel)
                    Divider()
                }
                Picker(
                    "Phông chữ",
                    selection: Binding(
                        get: { settingsStore.typography.font },
                        set: { settingsStore.typography.font = $0; settingsStore.save() }
                    )
                ) {
                    ForEach(fonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("fontPicker")
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                stepperRow(
                    title: "Cỡ chữ",
                    value: Binding(
                        get: { settingsStore.typography.fontSize },
                        set: { clampAndSaveFontSize($0) }
                    ),
                    range: 12 ... 24,
                    step: 1,
                    format: "%.0f"
                )
                stepperRow(
                    title: "Giãn dòng",
                    value: Binding(
                        get: { settingsStore.typography.lineHeight },
                        set: { clampAndSaveLineHeight($0) }
                    ),
                    range: 1.2 ... 2.0,
                    step: 0.1,
                    format: "%.1f"
                )
                stepperRow(
                    title: "Giãn chữ",
                    value: Binding(
                        get: { settingsStore.typography.letterSpacing },
                        set: { clampAndSaveLetterSpacing($0) }
                    ),
                    range: 0 ... 1.0,
                    step: 0.1,
                    format: "%.1f"
                )
                if showGearToast {
                    Text("Cài đặt sẽ có ở feat-005")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.muted)
                        .transition(.opacity)
                }
            }
            .padding(DesignTokens.spacing16)
        }
    }

    private func aiModeSection(viewModel: ReaderViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
            Text("Chế độ AI")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.text)
            Picker(
                "Chế độ AI",
                selection: Binding(
                    get: { viewModel.aiMode },
                    set: { newValue in
                        viewModel.aiMode = newValue
                        Task { await viewModel.setAIMode(newValue) }
                    }
                )
            ) {
                Text("Gốc").tag(AIMode.none)
                Text("Dịch").tag(AIMode.translate)
                Text("Tóm tắt").tag(AIMode.summary)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("aiModePicker")
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            Button("Xử lý lại") {
                Task { await viewModel.reprocess() }
            }
            .disabled(viewModel.aiMode == .none || viewModel.isAIProcessing)
            .opacity(viewModel.aiMode == .none || viewModel.isAIProcessing ? 0.4 : 1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("reprocessButton")
            if viewModel.isAIProcessing {
                ProgressView("Đang xử lý...")
                    .tint(DesignTokens.accent)
            }
            if let error = viewModel.aiError {
                Text(error)
                    .foregroundStyle(DesignTokens.error)
                    .font(.caption)
            }
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
                .foregroundStyle(DesignTokens.text)
            Spacer()
            Stepper(value: value, in: range, step: step) {
                Text(String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.text)
            }
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityValue(String(format: format, value.wrappedValue))
            .a11yHitTarget()
            Text(String(format: format, value.wrappedValue))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.text)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func clampAndSaveFontSize(_ value: Double) {
        settingsStore.typography.fontSize = min(max(12, value), 24)
        settingsStore.save()
    }

    private func clampAndSaveLineHeight(_ value: Double) {
        settingsStore.typography.lineHeight = min(max(1.2, value), 2.0)
        settingsStore.save()
    }

    private func clampAndSaveLetterSpacing(_ value: Double) {
        settingsStore.typography.letterSpacing = min(max(0, value), 1.0)
        settingsStore.save()
    }
}
