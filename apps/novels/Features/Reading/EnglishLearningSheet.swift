import SafariServices
import SwiftUI

struct EnglishLearningSheet: View {
    let theme: ReadingTheme
    let speech: ReaderSpeech
    let settings: SettingsStore
    private let sentences: [EnglishSentence]
    @Environment(\.dismiss) private var dismiss
    @State private var lookup: GoogleLookup?
    @State private var loadingSentenceID: Int?

    init(paragraph: BilingualParagraph, theme: ReadingTheme, speech: ReaderSpeech, settings: SettingsStore) {
        self.theme = theme
        self.speech = speech
        self.settings = settings
        sentences = EnglishLearning.sentences(in: paragraph.en)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.spacing24) {
                    Text(settings.audioSource == .apple
                        ? "Tra cứu gửi câu đến Google."
                        : "API/Google nhận câu; API có thể tính phí.")
                        .font(.footnote)
                        .foregroundStyle(theme.textMuted)
                    if let errorMessage = speech.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(theme.textPrimary)
                    }
                    ForEach(sentences) { sentence in
                        let isLoading = speech.isLoading && loadingSentenceID == sentence.id
                        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
                            Text(verbatim: sentence.text)
                                .font(.body)
                                .foregroundStyle(theme.textPrimary)
                                .textSelection(.enabled)
                            HStack(spacing: DesignTokens.spacing16) {
                                Button {
                                    loadingSentenceID = sentence.id
                                    speech.speak(sentence.text, settings: settings)
                                } label: {
                                    Label {
                                        Text(settings.audioSource == .apple ? "Nghe" : "Nghe · Online")
                                    } icon: {
                                        if isLoading {
                                            ProgressView()
                                                .controlSize(.small)
                                                .accessibilityHidden(true)
                                        } else {
                                            Image(systemName: "speaker.wave.2")
                                        }
                                    }
                                    .frame(minHeight: 44)
                                }
                                .disabled(isLoading)
                                .accessibilityLabel(isLoading ? "Đang tải audio cho câu tiếng Anh" :
                                    "Nghe câu tiếng Anh")
                                Button {
                                    speech.stop()
                                    if let url = EnglishLearning.googleURL(for: sentence.text) {
                                        lookup = GoogleLookup(url: url)
                                    }
                                } label: {
                                    Label("Tra cứu", systemImage: "magnifyingglass")
                                        .frame(minHeight: 44)
                                }
                                .accessibilityLabel("Tra cứu câu trên Google, cần Internet")
                            }
                            .buttonStyle(.borderless)
                            .tint(theme.accentColor)
                        }
                    }
                }
                .padding(DesignTokens.spacing16)
            }
            .background(theme.background)
            .navigationTitle("Học tiếng Anh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Dừng") { speech.stop() }
                        .disabled(!speech.canStop)
                        .accessibilityLabel("Dừng tải hoặc phát âm")
                }
            }
            .sheet(item: $lookup) { item in
                GoogleSearchBrowser(url: item.url)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(theme.preferredColorScheme)
        .onChange(of: settings.audioSource) { speech.stop() }
        .onDisappear { speech.stop() }
    }
}

private struct GoogleLookup: Identifiable {
    let id = UUID()
    let url: URL
}

private struct GoogleSearchBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
