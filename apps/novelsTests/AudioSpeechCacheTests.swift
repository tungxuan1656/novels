import Foundation
@testable import novels
import XCTest

extension AudioSpeechTests {
    func testReplayReusesAudioAcrossReaderInstancesWithoutLoading() async throws {
        try AudioURLProtocol.configure(mime: "audio/wav", data: playableAudio())
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let fixture = try makeSettings()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let speech = ReaderSpeech(client: client)
        defer { speech.stop() }
        speech.speak("Replay this sentence", settings: fixture.settings)
        try await waitUntil { !speech.isLoading }
        XCTAssertNil(speech.errorMessage)
        XCTAssertTrue(speech.isPlaying)
        speech.stop()
        speech.speak("Replay this sentence", settings: fixture.settings)
        XCTAssertFalse(speech.isLoading)
        XCTAssertTrue(speech.isPlaying)
        XCTAssertEqual(AudioURLProtocol.requests().count, 1)
        speech.stop()

        let nextReader = ReaderSpeech(client: client)
        defer { nextReader.stop() }
        nextReader.speak("Replay this sentence", settings: fixture.settings)
        XCTAssertFalse(nextReader.isLoading)
        XCTAssertTrue(nextReader.isPlaying)
        XCTAssertEqual(AudioURLProtocol.requests().count, 1)
        nextReader.stop()

        let newSession = ReaderSpeech(client: client, audioCache: NSCache())
        defer { newSession.stop() }
        newSession.speak("Replay this sentence", settings: fixture.settings)
        XCTAssertTrue(newSession.isLoading)
        try await waitUntil { !newSession.isLoading }
        XCTAssertTrue(newSession.isPlaying)
        XCTAssertEqual(AudioURLProtocol.requests().count, 2)
    }

    func testCacheSeparatesSentenceModelAndCredentialAndCanEvict() async throws {
        try AudioURLProtocol.configure(mime: "audio/wav", data: playableAudio())
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let fixture = try makeSettings()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let settings = fixture.settings
        let key = settings.audioAPIKey
        let model = settings.audioModel
        let cache = NSCache<NSArray, NSData>()
        let speech = ReaderSpeech(client: client, audioCache: cache)
        defer { speech.stop() }
        speech.speak("Hello", settings: settings)
        try await waitUntil { !speech.isLoading }
        settings.audioModel = model + "-different"
        speech.speak("Hello", settings: settings)
        try await waitUntil { !speech.isLoading }
        settings.audioModel = model
        settings.audioAPIKey = key + "-different"
        speech.speak("Hello", settings: settings)
        try await waitUntil { !speech.isLoading }
        settings.audioAPIKey = key
        speech.speak("Another sentence", settings: settings)
        try await waitUntil { !speech.isLoading }
        XCTAssertNil(speech.errorMessage)
        XCTAssertEqual(AudioURLProtocol.requests().count, 4)
        settings.audioModel = " \(model) \n"
        settings.audioAPIKey = " \(key) \n"
        speech.speak("Hello", settings: settings)
        XCTAssertFalse(speech.isLoading)
        XCTAssertTrue(speech.isPlaying)
        XCTAssertEqual(AudioURLProtocol.requests().count, 4)
        speech.stop()
        cache.removeAllObjects()
        speech.speak("Hello", settings: settings)
        XCTAssertTrue(speech.isLoading)
        try await waitUntil { !speech.isLoading }
        XCTAssertTrue(speech.isPlaying)
        XCTAssertEqual(AudioURLProtocol.requests().count, 5)
    }

    func testFailedAndCancelledLoadsDoNotPopulateCache() async throws {
        AudioURLProtocol.configure(status: 500)
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let fixture = try makeSettings()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let speech = ReaderSpeech(client: client, audioCache: NSCache())
        defer { speech.stop() }
        speech.speak("Retry", settings: fixture.settings)
        try await waitUntil { !speech.isLoading }
        XCTAssertEqual(speech.errorMessage, AudioSpeechError.httpStatus(500).localizedDescription)
        AudioURLProtocol.configure(data: Data("not audio".utf8))
        speech.speak("Retry", settings: fixture.settings)
        try await waitUntil { !speech.isLoading }
        XCTAssertEqual(speech.errorMessage, AudioSpeechError.playbackFailed.localizedDescription)
        speech.speak("Retry", settings: fixture.settings)
        try await waitUntil { !speech.isLoading }
        XCTAssertEqual(AudioURLProtocol.requests().count, 2)

        let started = expectation(description: "Uncached request started")
        let stopped = expectation(description: "Uncached request cancelled")
        AudioURLProtocol.configure(hold: true, started: started, stopped: stopped)
        speech.speak("Retry", settings: fixture.settings)
        await fulfillment(of: [started], timeout: 2)
        speech.stop()
        await fulfillment(of: [stopped], timeout: 2)
        try AudioURLProtocol.configure(mime: "audio/wav", data: playableAudio())
        speech.speak("Retry", settings: fixture.settings)
        XCTAssertTrue(speech.isLoading)
        try await waitUntil { !speech.isLoading }
        XCTAssertNil(speech.errorMessage)
        XCTAssertTrue(speech.isPlaying)
        XCTAssertEqual(AudioURLProtocol.requests().count, 1)
    }

    private func playableAudio() throws -> Data {
        let header = try XCTUnwrap(Data(base64Encoded: "UklGRqQ+AABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YYA+AAA="))
        return header + Data(repeating: 0, count: 16000)
    }
}
