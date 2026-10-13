import AVFoundation
import Observation

@MainActor
@Observable final class ReaderSpeech: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private(set) var isLoading = false
    private(set) var isPlaying = false
    private(set) var errorMessage: String?

    var canStop: Bool {
        isLoading || isPlaying
    }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let client: AudioSpeechClient
    @ObservationIgnored private let audioCache: NSCache<NSArray, NSData>
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
    @ObservationIgnored private let audioSession = AVAudioSession.sharedInstance()
    @ObservationIgnored private var audioSessionIsActive = false

    private static let sessionAudioCache: NSCache<NSArray, NSData> = {
        let cache = NSCache<NSArray, NSData>()
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()

    // swiftlint:disable opening_brace
    init(client: AudioSpeechClient = AudioSpeechClient(),
         audioCache: NSCache<NSArray, NSData>? = nil)
    {
        self.client = client
        self.audioCache = audioCache ?? Self.sessionAudioCache
        super.init()
        synthesizer.usesApplicationAudioSession = true
        synthesizer.delegate = self
    }

    // swiftlint:enable opening_brace

    func speak(_ sentence: String, settings: SettingsStore) {
        stop()
        errorMessage = nil
        if settings.audioSource == .apple {
            speakWithApple(sentence)
            return
        }
        let generation = generation
        let client = client
        let apiKey = settings.audioAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.audioModel.trimmingCharacters(in: .whitespacesAndNewlines)
        // Array equality keeps sentence/model/credential boundaries unambiguous; keys never leave RAM.
        let cacheKey = [apiKey, model, sentence] as NSArray
        if let cached = audioCache.object(forKey: cacheKey) {
            do {
                try play(cached as Data)
            } catch {
                audioCache.removeObject(forKey: cacheKey)
                errorMessage = AudioSpeechError.playbackFailed.localizedDescription
            }
            return
        }
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
                self.audioCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
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
        isPlaying = false
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        deactivateAudioSession()
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
        do {
            try activateAudioSession()
            currentUtterance = utterance
            isPlaying = true
            synthesizer.speak(utterance)
        } catch {
            errorMessage = AudioSpeechError.playbackFailed.localizedDescription
        }
    }

    private func play(_ data: Data) throws {
        do {
            let player = try AVAudioPlayer(data: data)
            try activateAudioSession()
            player.delegate = self
            self.player = player
            guard player.play() else { throw AudioSpeechError.playbackFailed }
            isPlaying = true
        } catch {
            player = nil
            deactivateAudioSession()
            throw AudioSpeechError.playbackFailed
        }
    }

    private func activateAudioSession() throws {
        // Explicit listening should remain audible with the Ring/Silent switch on.
        try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try audioSession.setActive(true)
        audioSessionIsActive = true
    }

    private func deactivateAudioSession() {
        guard audioSessionIsActive else { return }
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        audioSessionIsActive = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identity = RetainedPlaybackIdentity(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance.map(ObjectIdentifier.init) == identity.id else { return }
            self.stop()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speechSynthesizer(synthesizer, didFinish: utterance)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finishPlayer(player, successfully: flag)
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        finishPlayer(player, successfully: false)
    }

    private nonisolated func finishPlayer(_ player: AVAudioPlayer, successfully: Bool) {
        let identity = RetainedPlaybackIdentity(player)
        Task { @MainActor [weak self] in
            guard let self, self.player.map(ObjectIdentifier.init) == identity.id else { return }
            self.stop()
            if !successfully {
                self.errorMessage = AudioSpeechError.playbackFailed.localizedDescription
            }
        }
    }
}

/// Retain through the actor hop; only immutable identity is exposed across threads.
private final nonisolated class RetainedPlaybackIdentity: @unchecked Sendable {
    private let object: NSObject

    var id: ObjectIdentifier {
        ObjectIdentifier(object)
    }

    init(_ object: NSObject) {
        self.object = object
    }
}
