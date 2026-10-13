import Foundation

enum AudioSource: String, CaseIterable, Sendable {
    case apple
    case api

    static let defaultModel = "edge-tts/en-AU-WilliamMultilingualNeural"

    var title: String {
        self == .apple ? "Apple (trên thiết bị)" : "API (Online)"
    }
}
