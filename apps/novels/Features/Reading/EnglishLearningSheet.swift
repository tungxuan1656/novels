import SafariServices
import SwiftUI

struct EnglishLearningSheet: View {
    let theme: ReadingTheme
    let speech: ReaderSpeech
    private let sentences: [EnglishSentence]
    @Environment(\.dismiss) private var dismiss
    @State private var lookup: GoogleLookup?
    @State private var speechError: String?

    init(paragraph: BilingualParagraph, theme: ReadingTheme, speech: ReaderSpeech) {
        self.theme = theme
        self.speech = speech
        sentences = EnglishLearning.sentences(in: paragraph.en)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.spacing24) {
                    Text("Chọn câu để nghe hoặc tra cứu. Giọng đọc dùng trên thiết bị; "
                        + "Google cần Internet và nhận câu bạn chọn.")
                        .font(.footnote)
                        .foregroundStyle(theme.textMuted)
                    if let speechError {
                        Text(speechError)
                            .font(.footnote)
                            .foregroundStyle(theme.textPrimary)
                    }
                    ForEach(sentences) { sentence in
                        VStack(alignment: .leading, spacing: DesignTokens.spacing8) {
                            Text(verbatim: sentence.text)
                                .font(.body)
                                .foregroundStyle(theme.textPrimary)
                                .textSelection(.enabled)
                            HStack(spacing: DesignTokens.spacing16) {
                                Button {
                                    speechError = speech.speak(sentence.text) ? nil :
                                        "Chưa có giọng tiếng Anh. Hãy tải giọng đọc trong Cài đặt iOS."
                                } label: {
                                    Label("Nghe", systemImage: "speaker.wave.2")
                                        .frame(minHeight: 44)
                                }
                                .accessibilityLabel("Nghe câu tiếng Anh")
                                Button {
                                    speech.stop()
                                    if let url = EnglishLearning.googleURL(for: sentence.text) {
                                        lookup = GoogleLookup(url: url)
                                    }
                                } label: {
                                    Label("Tra cứu Google · Online", systemImage: "magnifyingglass")
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
                    Button("Dừng", systemImage: "stop.fill") { speech.stop() }
                        .accessibilityLabel("Dừng phát âm")
                }
            }
            .sheet(item: $lookup) { item in
                GoogleSearchBrowser(url: item.url)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(theme.preferredColorScheme)
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
