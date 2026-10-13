import Foundation
@testable import novels
import XCTest

@MainActor
final class AIConfigurationWarningTests: XCTestCase {
    private let universalResponse = """
    {"status":"completed","output_text":"ok",
    "choices":[{"message":{"content":"ok"}}],"content":[{"type":"text","text":"ok"}]}
    """

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIConfigurationURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // swiftlint:disable:next large_tuple
    private func setupHarness() throws -> (SettingsStore, AIClient, URLSession, String) {
        let name = "AIConfigurationWarningTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let store = SettingsStore(userDefaults: defaults)
        store.openaiAPIURL = "https://ai-fixture.test/v1/chat/completions"
        store.aiAPIKey = "fixture-api-key"
        let session = makeSession()
        let client = AIClient(settings: store, session: session)
        AIConfigurationURLProtocol.configure(status: 200, response: universalResponse)
        return (store, client, session, name)
    }

    func testMalformedHeadersWarnDespiteGeneratedSessionAndBearer() async throws {
        let (store, client, session, name) = try setupHarness()
        defer {
            session.invalidateAndCancel()
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        let malformed = "not-json-headers"
        store.aiCustomHeadersJSON = malformed
        let runId = UUID()
        let context = AIDiagnosticsContext(bookId: "b1", chapterNumber: 1, mode: "rewrite", runId: runId)

        let output = try await client.complete(prompt: "p", chunk: "c", context: context)
        XCTAssertEqual(output, "ok")

        let request = try XCTUnwrap(AIConfigurationURLProtocol.requests().first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-opencode-session"), "novels-b1-c1-rewrite")

        let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
        let warning = try XCTUnwrap(entries.first { $0.event == "invalid.headers" })
        XCTAssertEqual(warning.runId, runId)
        XCTAssertFalse(warning.debugSummary.contains(malformed))
        XCTAssertFalse(warning.detail?.contains(malformed) == true)
    }

    func testMalformedHeadersWarnWithOnlyGeneratedAnthropicVersion() async throws {
        let (store, client, session, name) = try setupHarness()
        defer {
            session.invalidateAndCancel()
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        store.openaiAPIURL = "https://ai-fixture.test/v1/messages"
        store.aiAPIKey = ""
        store.aiCustomHeadersJSON = "[]"
        let context = AIDiagnosticsContext()

        let output = try await client.complete(prompt: "p", chunk: "c", context: context)
        XCTAssertEqual(output, "ok")
        let request = try XCTUnwrap(AIConfigurationURLProtocol.requests().first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
        XCTAssertEqual(entries.filter { $0.event == "invalid.headers" }.count, 1)
    }

    func testMalformedOrNonObjectBodyAndHeadersWarnAndIgnoredRequestSucceeds() async throws {
        let (store, client, session, name) = try setupHarness()
        defer {
            session.invalidateAndCancel()
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        let malformedBody = "[1, 2, 3]"
        let malformedHeaders = "true"
        store.aiExtraBodyJSON = malformedBody
        store.aiCustomHeadersJSON = malformedHeaders
        let context = AIDiagnosticsContext(requestId: UUID())

        let output = try await client.complete(prompt: "p", chunk: "c", context: context)
        XCTAssertEqual(output, "ok")

        let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
        XCTAssertTrue(entries.contains { $0.event == "invalid.headers" })
        XCTAssertTrue(entries.contains { $0.event == "invalid.body" })
    }

    func testValidEmptyObjectAndWhitespaceDoNotWarn() async throws {
        let (store, client, session, name) = try setupHarness()
        defer {
            session.invalidateAndCancel()
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        for (emptyHeaders, emptyBody) in [("{}", "{}"), ("  \n  ", "   ")] {
            store.aiCustomHeadersJSON = emptyHeaders
            store.aiExtraBodyJSON = emptyBody
            let context = AIDiagnosticsContext(requestId: UUID())
            let output = try await client.complete(prompt: "p", chunk: "c", context: context)
            XCTAssertEqual(output, "ok")

            let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
            XCTAssertFalse(entries.contains { $0.event == "invalid.headers" })
            XCTAssertFalse(entries.contains { $0.event == "invalid.body" })
        }
    }

    func testValidNonStringHeaderEntriesFilteredWithoutWarning() async throws {
        let (store, client, session, name) = try setupHarness()
        defer {
            session.invalidateAndCancel()
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        store.aiAPIKey = ""
        store.aiCustomHeadersJSON = #"{"X-Num": 123, "X-Bool": true}"#
        let context = AIDiagnosticsContext(requestId: UUID())

        let output = try await client.complete(prompt: "p", chunk: "c", context: context)
        XCTAssertEqual(output, "ok")

        let request = try XCTUnwrap(AIConfigurationURLProtocol.requests().first)
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Num"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Bool"))

        let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
        XCTAssertFalse(entries.contains { $0.event == "invalid.headers" })
    }

    func testSensitiveMalformedStringNeverAppearsInWarningSummaryOrDetail() async throws {
        let (store, client, session, name) = try setupHarness()
        defer {
            session.invalidateAndCancel()
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        let sensitiveSecret = "sk-fixture-very-secret-token-12345"
        store.aiCustomHeadersJSON = "{ malformed: \(sensitiveSecret) }"
        let runId = UUID()
        let context = AIDiagnosticsContext(bookId: "bk", chapterNumber: 2, mode: "bilingual", runId: runId)

        _ = try await client.complete(prompt: "p", chunk: "c", context: context)

        let entries = await DiagnosticsLog.shared.snapshot().filter { $0.requestId == context.requestId }
        let warning = try XCTUnwrap(entries.first { $0.event == "invalid.headers" })
        XCTAssertEqual(warning.runId, runId)
        XCTAssertFalse(warning.debugSummary.contains(sensitiveSecret))
        XCTAssertFalse(warning.detail?.contains(sensitiveSecret) == true)
    }
}
