import Foundation
@testable import novels
import XCTest

@MainActor
final class AudioSpeechTests: XCTestCase {
    func testExactRequestAndRawAudioResponse() async throws {
        let audio = Data([1, 2, 3])
        AudioURLProtocol.configure(data: audio)
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let sentence = "Tần Dương said: \"A+B & C?\"\nHello!"
        let result = try await client.audio(for: sentence, apiKey: " test-key \n", model: " edge-tts/test ")
        XCTAssertEqual(result, audio)
        let request = try XCTUnwrap(AudioURLProtocol.requests().first)
        XCTAssertEqual(request.url?.absoluteString, AudioSpeechClient.endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String])
        XCTAssertEqual(body, ["model": "edge-tts/test", "input": sentence])
        XCTAssertEqual(AudioURLProtocol.requests().count, 1)
    }

    func testInvalidConfigurationDoesNotSendRequest() async throws {
        AudioURLProtocol.configure()
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        // swiftlint:disable trailing_comma
        let cases: [InvalidRequest] = [
            .init(input: "Hello", key: "  ", model: "model", error: .invalidKey),
            .init(input: "Hello", key: "key\r\ninjected", model: "model", error: .invalidKey),
            .init(input: "Hello", key: "key", model: " \n ", error: .invalidModel),
            .init(input: " \n ", key: "key", model: "model", error: .emptyInput),
        ]
        // swiftlint:enable trailing_comma
        for test in cases {
            do {
                _ = try await client.audio(for: test.input, apiKey: test.key, model: test.model)
                XCTFail("Invalid configuration must fail")
            } catch {
                XCTAssertEqual(error as? AudioSpeechError, test.error)
            }
        }
        XCTAssertTrue(AudioURLProtocol.requests().isEmpty)
    }

    func testHTTPAndInvalidAudioErrorsDoNotExposeProviderBodyOrRetry() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        // swiftlint:disable trailing_comma
        let cases: [InvalidResponse] = [
            .init(status: 401, mime: "application/json", data: Data("private-key echoed by server".utf8),
                  error: .httpStatus(401)),
            .init(status: 429, mime: "application/json", data: Data(), error: .httpStatus(429)),
            .init(status: 500, mime: "text/plain", data: Data(), error: .httpStatus(500)),
            .init(status: 200, mime: "application/json", data: Data("{}".utf8), error: .invalidAudio),
            .init(status: 200, mime: "audio/mpeg", data: Data(), error: .invalidAudio),
            .init(status: 200, mime: "audio/mpeg", data: Data(repeating: 0, count: 10 * 1024 * 1024 + 1),
                  error: .invalidAudio),
        ]
        // swiftlint:enable trailing_comma
        for test in cases {
            AudioURLProtocol.configure(status: test.status, mime: test.mime, data: test.data)
            do {
                _ = try await client.audio(for: "Hello", apiKey: "test-key", model: "model")
                XCTFail("Bad response must fail")
            } catch {
                XCTAssertEqual(error as? AudioSpeechError, test.error)
                XCTAssertFalse(error.localizedDescription.contains("private-key"))
            }
            XCTAssertEqual(AudioURLProtocol.requests().count, 1)
        }
    }

    func testOctetStreamResponseIsAccepted() async throws {
        AudioURLProtocol.configure(mime: "application/octet-stream", data: Data([1]))
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let audio = try await client.audio(for: "Hello", apiKey: "key", model: "model")
        XCTAssertEqual(audio, Data([1]))
    }

    func testCancelledRequestStopsTransport() async throws {
        let started = expectation(description: "Request started")
        let stopped = expectation(description: "Transport cancelled")
        AudioURLProtocol.configure(hold: true, started: started, stopped: stopped)
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let task = Task { try await client.audio(for: "Hello", apiKey: "key", model: "model") }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled request must not return audio")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled)
        }
        await fulfillment(of: [stopped], timeout: 2)
    }

    func testReaderReplacementAndStopCancelWithoutStaleErrorsOrLoadingChanges() async throws {
        let started = expectation(description: "Both requests started")
        started.expectedFulfillmentCount = 2
        let stopped = expectation(description: "Both requests cancelled")
        stopped.expectedFulfillmentCount = 2
        AudioURLProtocol.configure(hold: true, started: started, stopped: stopped)
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let fixture = try makeSettings()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let settings = fixture.settings
        let speech = ReaderSpeech(client: client)
        defer { speech.stop() }
        speech.speak("First", settings: settings)
        try await waitUntil { AudioURLProtocol.requests().count == 1 }
        XCTAssertTrue(speech.isLoading)
        speech.speak("Second", settings: settings)
        await fulfillment(of: [started], timeout: 2)
        try await waitUntil { AudioURLProtocol.stopCount() == 1 }
        XCTAssertTrue(speech.isLoading)
        XCTAssertNil(speech.errorMessage)
        speech.stop()
        XCTAssertFalse(speech.isLoading)
        await fulfillment(of: [stopped], timeout: 2)
        XCTAssertNil(speech.errorMessage)
    }

    func testReaderMissingKeyAndUndecodableAudioShowActionableErrors() async throws {
        AudioURLProtocol.configure(data: Data("not an MP3".utf8))
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let fixture = try makeSettings()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let settings = fixture.settings
        let speech = ReaderSpeech(client: client)
        defer { speech.stop() }
        settings.audioAPIKey = ""
        speech.speak("Hello", settings: settings)
        try await waitUntil { !speech.isLoading }
        XCTAssertEqual(speech.errorMessage, AudioSpeechError.invalidKey.localizedDescription)
        XCTAssertTrue(AudioURLProtocol.requests().isEmpty)
        settings.audioAPIKey = "key"
        speech.speak("Hello", settings: settings)
        XCTAssertNil(speech.errorMessage)
        try await waitUntil { !speech.isLoading }
        XCTAssertEqual(speech.errorMessage, AudioSpeechError.playbackFailed.localizedDescription)
        XCTAssertEqual(AudioURLProtocol.requests().count, 1)
    }

    private struct InvalidRequest {
        let input: String
        let key: String
        let model: String
        let error: AudioSpeechError
    }

    private struct InvalidResponse {
        let status: Int
        let mime: String
        let data: Data
        let error: AudioSpeechError
    }

    private func makeClient() -> (AudioSpeechClient, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AudioURLProtocol.self]
        let session = URLSession(configuration: config)
        return (AudioSpeechClient(session: session), session)
    }

    private struct SettingsFixture {
        let settings: SettingsStore
        let defaults: UserDefaults
        let suite: String
    }

    private func makeSettings() throws -> SettingsFixture {
        let suite = "AudioSpeechTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = SettingsStore(userDefaults: defaults)
        settings.audioSource = .api
        settings.audioAPIKey = "test-key"
        return SettingsFixture(settings: settings, defaults: defaults, suite: suite)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition() {
            guard Date() < deadline else { return XCTFail("Timed out waiting for audio state") }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

private final nonisolated class AudioURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var status = 200
    private nonisolated(unsafe) static var mime = "audio/mpeg"
    private nonisolated(unsafe) static var data = Data([1])
    private nonisolated(unsafe) static var hold = false
    private nonisolated(unsafe) static var captured: [URLRequest] = []
    private nonisolated(unsafe) static var stoppedCount = 0
    private nonisolated(unsafe) static var started: XCTestExpectation?
    private nonisolated(unsafe) static var stopped: XCTestExpectation?

    // swiftlint:disable opening_brace
    static func configure(status: Int = 200, mime: String = "audio/mpeg", data: Data = Data([1]),
                          hold: Bool = false, started: XCTestExpectation? = nil, stopped: XCTestExpectation? = nil)
    {
        lock.withLock {
            self.status = status
            self.mime = mime
            self.data = data
            self.hold = hold
            self.started = started
            self.stopped = stopped
            captured = []
            stoppedCount = 0
        }
    }

    // swiftlint:enable opening_brace

    static func requests() -> [URLRequest] {
        lock.withLock { captured }
    }

    static func stopCount() -> Int {
        lock.withLock { stoppedCount }
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.absoluteString == AudioSpeechClient.endpoint
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var copy = request
        if copy.httpBody == nil, let stream = copy.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            var count = stream.read(&buffer, maxLength: buffer.count)
            while count > 0 {
                data.append(buffer, count: count)
                count = stream.read(&buffer, maxLength: buffer.count)
            }
            copy.httpBody = data
        }
        let snapshot = Self.lock.withLock {
            Self.captured.append(copy)
            return (Self.status, Self.mime, Self.data, Self.hold, Self.started)
        }
        snapshot.4?.fulfill()
        guard !snapshot.3, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: snapshot.0, httpVersion: nil,
                                             headerFields: ["Content-Type": snapshot.1])
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: snapshot.2)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        let stopped = Self.lock.withLock {
            Self.stoppedCount += 1
            return Self.stopped
        }
        stopped?.fulfill()
    }
}
