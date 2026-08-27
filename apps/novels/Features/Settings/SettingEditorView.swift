import SwiftUI

struct SettingEditorView: View {
    let settingKey: String
    @Environment(SettingsStore.self) private var settings
    @Environment(Router.self) private var router
    @State private var draft: String = ""
    @State private var errorMessage: String?

    private var descriptor: SettingDescriptor {
        SettingsViewModel.descriptor(for: settingKey)
    }

    var body: some View {
        Form {
            Section {
                Text(descriptor.description)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
            }
            Section("Giá trị") {
                if descriptor.key == "AI_CUSTOM_HEADERS"
                    || descriptor.key == "AI_EXTRA_BODY"
                    || descriptor.key == "AI_PROCESS_ACTIONS"
                // swiftlint:disable:next opening_brace
                {
                    TextEditor(text: $draft)
                        .frame(minHeight: 120)
                        .font(.caption.monospaced())
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                } else {
                    TextField(descriptor.placeholder, text: $draft)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.error)
                }
            }
            Section {
                HStack {
                    Button("Xóa") {
                        draft = descriptor.defaultValue
                        errorMessage = nil
                    }
                    .foregroundStyle(DesignTokens.error)
                    Spacer()
                    Button("Lưu") {
                        save()
                    }
                    .bold()
                    .disabled(shouldBlockSave)
                }
            }
        }
        .navigationTitle(descriptor.label)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.backgroundPaper)
        .onAppear {
            draft = settings.value(forKey: settingKey)
            errorMessage = descriptor.validate(draft)
        }
        .onChange(of: draft) { _, newValue in
            errorMessage = descriptor.validate(newValue)
        }
    }

    private var shouldBlockSave: Bool {
        guard errorMessage != nil else { return false }
        return !descriptor.allowsVerbatimSave
    }

    private func save() {
        let message = descriptor.validate(draft)
        if let message, !descriptor.allowsVerbatimSave {
            errorMessage = message
            return
        }
        errorMessage = message
        settings.setValue(draft, forKey: settingKey)
        settings.save()
        router.toast.show("Đã lưu", type: .success)
        router.pop()
    }
}
