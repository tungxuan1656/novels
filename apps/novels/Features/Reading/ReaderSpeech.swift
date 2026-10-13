import AVFoundation
import Observation

@MainActor
@Observable final class ReaderSpeech {
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let client: AudioSpeechClient
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    init(client: AudioSpeechClient = AudioSpeechClient()) {
        self.client = client
    }

    func speak(_ sentence: String, settings: SettingsStore) {
        stop()
        errorMessage = nil
        if settings.audioSource == .apple {
            speakWithApple(sentence)
            return
        }
        let generation = generation
        let client = client
        let apiKey = settings.audioAPIKey
        let model = settings.audioModel
        isLoading = true
        loadTask = Task { [weak self] in
            defer {
                if let self, self.generation == generation {
                    self.isLoading = false
                    self.loadTask = nil
                }
            }
            do {
                let data = try await client.audio(for: sentence, apiKey: apiKey, model: model)
                try Task.checkCancellation()
                guard let self, self.generation == generation else { return }
                try self.play(data)
            } catch {
                guard let self, self.generation == generation, !Task.isCancelled else { return }
                if let error = error as? AudioSpeechError {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.errorMessage = "Không thể tải hoặc phát audio. Kiểm tra kết nối và thử lại."
                }
            }
        }
    }

    func stop() {
        generation = UUID()
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
    }

    private func speakWithApple(_ sentence: String) {
        guard let voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("en-") })
        else {
            errorMessage = "Chưa có giọng tiếng Anh. Hãy tải giọng đọc trong Cài đặt iOS."
            return
        }
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    private func play(_ data: Data) throws {
        do {
            let player = try AVAudioPlayer(data: data)
            guard player.play() else { throw AudioSpeechError.playbackFailed }
            self.player = player
        } catch {
            throw AudioSpeechError.playbackFailed
        }
    }
}
