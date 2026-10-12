import AVFoundation

@MainActor
final class ReaderSpeech {
    private let synthesizer = AVSpeechSynthesizer()

    @discardableResult
    func speak(_ sentence: String) -> Bool {
        stop()
        guard let voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("en-") })
        else { return false }
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = voice
        synthesizer.speak(utterance)
        return true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
