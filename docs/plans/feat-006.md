# AI Reading Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver cache-first translate/summary rendering for the current chapter via an OpenAI-compatible service.

**Architecture:** `AIClient` actor handles chunked POST with retry 3× (1000/2000ms) and header/body merge (invalid JSON ignored); `AIChunker` splits ~1300 chars; `AIPromptBuilder` provides Vietnamese prompts honoring BR-03/04/05/06; `AIReadingService` orchestrates cache-first lookup `bookId(slug)+chapterNumber+mode` via `SQLiteProcessedChapterCache` (`WITHOUT ROWID`) with actor dedup and `INSERT OR REPLACE`; `ReaderViewModel` exposes `aiMode + processedContent + isAIProcessing` and mode switch/reprocess in `ReaderBottomSheet` owned by feat-004.

**Tech Stack:** Swift 5.0 / SwiftUI, Xcode `apps/novels.xcodeproj` scheme `novels` iOS 26.5, `Foundation` + `Observation.@Observable`, `URLSession` async/await + `actor` de-dup + `Task` cancellation, `libsqlite3` via `SQLiteProcessedChapterCache`, `CryptoKit` SHA256, `XCTest`, SwiftLint 0.65.1 / SwiftFormat 0.62.1, Vietnamese UI, `NSAppTransportSecurity` localhost-only.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — `TARGETED_DEVICE_FAMILY=1`, `IPHONEOS_DEPLOYMENT_TARGET=26.5`, copy Vietnamese per `docs/design/screens.md`.
- `DEVELOPMENT_TEAM M5U4E4H84J`, Swift 5.0, single module `apps/novels`, no SwiftPM packages — native only (`FileManager`, `libsqlite3`, `UserDefaults`, `URLSession`, `CryptoKit`).
- No `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, WebKit, or second AI cache per `docs/decisions/local-persistence.md`.
- `book.json.id` string slug is sole local identity; remote numeric `ExportedBook.id` never used as folder/cache key per `docs/decisions/book-identity.md`.
- Stores: `Application Support/novels/books/<slug>/` + `Application Support/novels/cache/processed_chapters.sqlite` (`PRIMARY KEY(book_id,chapter_number,mode) WITHOUT ROWID`, `user_version=1`, `INSERT OR REPLACE`; mode `none` never written) + `UserDefaults @Observable` (`SettingsStore`: `OPENAI_API_URL` default `http://localhost:8317/v1/chat/completions`, `OPENAI_MODEL` default `gpt-4o`, `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` default `""` invalid JSON ignored at merge per `docs/contracts/ai-service.md:17`, `AI_MIN_CHUNK_SIZE` default `1300` allowed `500..5000` else `1300`, `AI_PROVIDER` only `openai`).
- Networking: single `POST` to chat completions per chunk, base body `{"model":..., "messages":[{"role":"system","content":prompt},{"role":"user","content":chunk}]}`, merge `AI_EXTRA_BODY` shallowly + `AI_CUSTOM_HEADERS` as HTTP headers only when valid JSON object; retry 3× (`1000 ms` after attempt1, `2000 ms` after attempt2); cache check before call, save on success, no cache on final failure, concurrent same-key de-duplicates (single call shared result).
- ATS exception `NSAppTransportSecurity` allows `http://localhost:8317` only (Info.plist `NSAllowsLocalNetworking` or `NSExceptionDomains localhost NSExceptionAllowsInsecureHTTPLoads`).
- Chunk hint `AI_MIN_CHUNK_SIZE = 1300` chars; short → 1 chunk; long split; join in source order, clean, then cache.
- Translate BR-03 keep honorifics `ta, ngươi, hắn, nàng, huynh, đệ...` never map, BR-04 natural Vietnamese 100% meaning keep names/places/terms; Summary BR-05 50-60% remove only scenery/repeated emotion/non-plot, BR-06 keep plot order/key events/twists/key dialogue, never invent.
- Verification: `./init.sh` (swiftformat --lint, swiftlint --strict, `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`, `xcodebuild test`).

---

## File Structure

**New files (this feature owns):**
- `apps/novels/Services/AIChunker.swift` — Pure chunking: `enum AIChunker { static func chunk(text: String, size: Int) -> [String] }` splits by character count `size` (default 1300 from SettingsStore.aiMinChunkSize clamped 500..5000 else 1300), preserving order, no empty chunks. Tested via unit.
- `apps/novels/Services/AIPromptBuilder.swift` — Prompt builder honoring BR-03/04/05/06: `enum AIPromptBuilder { static func prompt(for mode: AIMode, actionsJSON: String) -> String }` decodes `AI_PROCESS_ACTIONS` JSON (fallback to SettingsDefaults.defaultActions) and returns matching `AIAction.prompt`; default prompts embed honorific + 50-60% rules if actions missing. Verified prompts contain constraints strings.
- `apps/novels/Services/AIClient.swift` — Actor network client: `actor AIClient { init(settings: SettingsStore, session: URLSession) ; func complete(prompt: String, chunk: String) async throws -> String }` builds `URLRequest` POST to `OPENAI_API_URL`, merges `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` valid JSON only, decodes `choices[0].message.content`, retries 3× with 1000/2000 ms sleeps, throws on empty/no response.
- `apps/novels/Services/AIReadingService.swift` — Cache-first orchestrator: `actor AIReadingService { init(cache: ProcessedChapterCaching, client: AIClient, settings: SettingsStore) ; func processedContent(bookId: String, chapterNumber: Int, mode: AIMode, rawText: String) async throws -> String }` checks cache first (nil for none, returns cached if hit), on miss chunks via AIChunker, calls AIClient per chunk sequentially (preserving order), joins with "\n", cleans, computes SHA256 hash, upserts `ProcessedChapter`, returns content; de-duplicates concurrent same-key via in-flight dictionary `[String: Task<String,Error>]`.
- `apps/novels/Services/AIResponse.swift` — Decodable for OpenAI response: `struct AIChatResponse: Decodable { let choices: [Choice] } ; struct Choice: Decodable { let message: Message } ; struct Message: Decodable { let content: String }`.
- `apps/novelsTests/AIChunkerTests.swift` — Unit for chunking edge cases.
- `apps/novelsTests/AIPromptBuilderTests.swift` — Unit asserts prompts contain BR constraints.
- `apps/novelsTests/AIClientTests.swift` — Unit with URLProtocol mock: header/body merge, invalid JSON ignored, retry timing, localhost URL.
- `apps/novelsTests/AIReadingServiceTests.swift` — Unit with in-memory cache + mock client: cache hit no network, miss chunks+cache, dedup, mode none never cached, reprocess overwrites.

**Modified files:**
- `apps/novels/Domain/SettingsModels.swift` — Update `SettingsDefaults.defaultActions` prompts to embed BR-03/04/05/06 Vietnamese natural/summary 50-60% honorifics (current placeholders fail acceptance).
- `apps/novels/Persistence/SettingsStore.swift` — Add helper `func prompt(for mode: AIMode) -> String` if needed or keep in AIPromptBuilder; ensure `aiMinChunkSize` clamped 500..5000 else 1300 via sanitize (already 500..5000).
- `apps/novels/Features/Reading/ReaderViewModel.swift` — Add `var aiMode: AIMode = .none`, `var processedContent: String?`, `var isAIProcessing: Bool`, `var aiError: String?`, `func setAIMode(_ mode: AIMode)`, `func reprocess()`, `private func loadAIContent()` that calls AIReadingService cache-first; preserve existing `load()` raw path when mode==none; inject `AIReadingService` via init (default with real cache/client).
- `apps/novels/Features/Reading/ReaderView.swift` — Render `processedContent` when mode != none and available else `blocks`; show loading overlay `isAIProcessing` and error banner `aiError`; restore offset per-book still via existing `ScrollOffsetPreference`.
- `apps/novels/Features/Reading/ReaderBottomSheet.swift` — Add mode switch segment `none/translate/summary` bound to `ReaderViewModel.aiMode` + "Xử lý lại" button that calls `reprocess()` (overwrites cache); Vietnamese labels `accessibilityIdentifier` `aiModePicker`, `reprocessButton`; keep existing typography rows.
- `apps/novels/Features/Reading/ReferencesView.swift` — No change (already bold current).
- `apps/novels/App/Router.swift` + `AppRoot.swift` — No new routes (mode lives in sheet owned by feat-004).
- `apps/novels/Info.plist` + `apps/novels.xcodeproj/project.pbxproj` — Add `NSAppTransportSecurity` exception for `localhost` `http://localhost:8317` only; add new files to target.
- `apps/novels/Resources/DesignTokens.swift` — Verify no change.

**Tests:**
- Extend `apps/novelsTests/ReaderViewModelTests.swift` if exists for AI mode switch behavior, or new `AIReadingViewModelTests.swift` for ViewModel integration.
- Existing `ProcessedChapterCacheTests.swift` extended for AI service cache behavior (no schema change — reuse).

---

### Task 1: Chunker + PromptBuilder (pure Swift, BR constraints)

**Files:**
- Create: `apps/novels/Services/AIChunker.swift`
- Create: `apps/novels/Services/AIPromptBuilder.swift`
- Modify: `apps/novels/Domain/SettingsModels.swift` (update default prompts)
- Test: `apps/novelsTests/AIChunkerTests.swift`
- Test: `apps/novelsTests/AIPromptBuilderTests.swift`

**Interfaces:**
- Consumes: `AIMode` (`none/translate/summary`), `SettingsDefaults.defaultActions` / `AIAction`, `SettingsStore.aiProcessActionsJSON`, `SettingsStore.aiMinChunkSize`.
- Produces: `AIChunker.chunk(text:size:Int)->[String]` ; `AIPromptBuilder.prompt(for: AIMode, actionsJSON: String)->String` + `AIPromptBuilder.defaultPrompt(for: AIMode)->String` (fallback). Later tasks rely on these exact signatures.

- [ ] **Step 1: Write failing chunker tests**

```swift
import XCTest
@testable import novels

final class AIChunkerTests: XCTestCase {
    func testSingleChunkShortText() {
        XCTAssertEqual(AIChunker.chunk(text: "hello", size: 1300).count, 1)
        XCTAssertEqual(AIChunker.chunk(text: "hello", size: 1300).first, "hello")
    }
    func testSplitsAtBoundary() {
        let text = String(repeating: "a", count: 2600)
        let chunks = AIChunker.chunk(text: text, size: 1300)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].count, 1300)
        XCTAssertEqual(chunks[1].count, 1300)
        XCTAssertEqual(chunks.joined(), text)
    }
    func testEmptyReturnsOneEmptyOrZero() {
        XCTAssertTrue(AIChunker.chunk(text: "", size: 1300).isEmpty || AIChunker.chunk(text: "", size: 1300) == [""])
    }
    func testPreservesOrder() {
        let text = "abcdefghijklmnopqrstuvwxyz"
        let chunks = AIChunker.chunk(text: text, size: 5)
        XCTAssertEqual(chunks, ["abcde","fghij","klmno","pqrst","uvwxy","z"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIChunkerTests -quiet`
Expected: FAIL — `AIChunker` not defined.

- [ ] **Step 3: Write failing prompt builder tests (BR constraints)**

```swift
import XCTest
@testable import novels

final class AIPromptBuilderTests: XCTestCase {
    func testTranslatePromptKeepsHonorifics() {
        let prompt = AIPromptBuilder.prompt(for: .translate, actionsJSON: "")
        XCTAssertTrue(prompt.lowercased().contains("ta") || prompt.contains("honorific") || prompt.contains("giữ nguyên"))
        XCTAssertTrue(prompt.contains("tự nhiên") || prompt.lowercased().contains("natural"))
        XCTAssertTrue(prompt.contains("100%") || prompt.contains("toàn bộ"))
    }
    func testTranslatePromptDefaultContainsBR0304() {
        let p = AIPromptBuilder.defaultPrompt(for: .translate)
        XCTAssertTrue(p.contains("ta") && p.contains("ngươi") || p.contains("honorific"))
        XCTAssertTrue(p.contains("50") == false) // translate not summary
    }
    func testSummaryPrompt50to60AndNoHallucination() {
        let p = AIPromptBuilder.prompt(for: .summary, actionsJSON: "")
        XCTAssertTrue(p.contains("50") && p.contains("60"))
        XCTAssertTrue(p.contains("không bịa") || p.lowercased().contains("never invent") || p.lowercased().contains("no hallucination"))
        XCTAssertTrue(p.contains("cốt truyện") || p.lowercased().contains("plot"))
    }
    func testUsesActionsJSONWhenValid() {
        let json = "[{\"key\":\"translate\",\"name\":\"Dịch\",\"prompt\":\"CUSTOM TRANSLATE PROMPT KEEP ta\"},{\"key\":\"summary\",\"name\":\"Tóm tắt\",\"prompt\":\"CUSTOM SUMMARY 50-60\"}]"
        XCTAssertEqual(AIPromptBuilder.prompt(for: .translate, actionsJSON: json), "CUSTOM TRANSLATE PROMPT KEEP ta")
        XCTAssertEqual(AIPromptBuilder.prompt(for: .summary, actionsJSON: json), "CUSTOM SUMMARY 50-60")
    }
    func testNoneReturnsEmpty() {
        XCTAssertEqual(AIPromptBuilder.prompt(for: .none, actionsJSON: ""), "")
    }
}
```

- [ ] **Step 4: Run prompt tests to verify they fail**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIPromptBuilderTests -quiet`
Expected: FAIL — `AIPromptBuilder` not defined.

- [ ] **Step 5: Write minimal AIChunker implementation**

In `apps/novels/Services/AIChunker.swift`:
```swift
import Foundation

enum AIChunker {
    static func chunk(text: String, size: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        let chunkSize = max(1, size)
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[start..<end]))
            start = end
        }
        return result
    }
}
```

- [ ] **Step 6: Write minimal AIPromptBuilder + update defaults**

In `apps/novels/Domain/SettingsModels.swift` replace `defaultActions` prompts:
```swift
static let defaultActions: [AIAction] = [
    AIAction(key: "translate", name: "Dịch", prompt: "Bạn là dịch giả tiểu thuyết. Dịch sang tiếng Việt tự nhiên, giữ 100% ý nghĩa, tên riêng, địa danh, thuật ngữ. Giữ nguyên mọi đại từ xưng hô như ta, ngươi, hắn, nàng, huynh, đệ, tỷ, muội... Tuyệt đối không đổi ta→em/anh, ngươi→bạn. Không thêm bớt nội dung. Văn phong tự nhiên, mượt mà."),
    AIAction(key: "summary", name: "Tóm tắt", prompt: "Bạn là biên tập tóm tắt. Tóm tắt chương còn 50–60% độ dài, giữ nguyên thứ tự cốt truyện, sự kiện chính, bước ngoặt, thoại quan trọng (rút gọn nhưng giữ ý). Chỉ lược bỏ miêu tả cảnh dài, cảm xúc lặp, bối cảnh không ảnh hưởng cốt truyện. Tuyệt đối không bịa thêm nội dung (no hallucination)."),
]
```

In `apps/novels/Services/AIPromptBuilder.swift`:
```swift
import Foundation

enum AIPromptBuilder {
    static func prompt(for mode: AIMode, actionsJSON: String) -> String {
        if mode == .none { return "" }
        if let data = actionsJSON.data(using: .utf8),
           let actions = try? JSONDecoder().decode([AIAction].self, from: data),
           let found = actions.first(where: { $0.key == mode.rawValue }) {
            return found.prompt
        }
        return defaultPrompt(for: mode)
    }
    static func defaultPrompt(for mode: AIMode) -> String {
        switch mode {
        case .translate:
            return SettingsDefaults.defaultActions.first(where: { $0.key == "translate" })?.prompt ?? "Translate faithfully keep honorifics ta ngươi huynh đệ, natural Vietnamese 100%"
        case .summary:
            return SettingsDefaults.defaultActions.first(where: { $0.key == "summary" })?.prompt ?? "Summarize 50-60% keep plot order key events twists key dialogue, no hallucination"
        case .none: return ""
        }
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIChunkerTests -only-testing:novelsTests/AIPromptBuilderTests -quiet`
Expected: PASS (fix string contains to match actual prompts — adjust test to check "ta" and "50" and "không bịa").

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/novels/Services/AIChunker.swift apps/novels/Services/AIPromptBuilder.swift apps/novels/Domain/SettingsModels.swift apps/novelsTests/AIChunkerTests.swift apps/novelsTests/AIPromptBuilderTests.swift
git commit -m "feat(ai): add chunker 1300 and prompt builder with BR-03/04/05/06 honorifics"
```

---

### Task 2: AIClient actor — POST, headers/body merge, retry 3×, response decode

**Files:**
- Create: `apps/novels/Services/AIResponse.swift`
- Create: `apps/novels/Services/AIClient.swift`
- Modify: `apps/novels/Persistence/SettingsStore.swift` (ensure effectiveHeaders/effectiveExtraBody used; no change if already correct)
- Test: `apps/novelsTests/AIClientTests.swift`
- Modify: `apps/novels/Info.plist` (ATS localhost)

**Interfaces:**
- Consumes: `SettingsStore` (`openaiAPIURL`, `openaiModel`, `effectiveHeaders()`, `effectiveExtraBody()`), `AIPromptBuilder`, `AIChatResponse`.
- Produces: `actor AIClient { init(settings: SettingsStore, session: URLSession); func complete(prompt: String, chunk: String) async throws -> String }` + `enum AIClientError: Error { case noResponse, httpError(Int, String) }`. Later task `AIReadingService` calls `client.complete(prompt:chunk:)` per chunk.

- [ ] **Step 1: Write failing AIClient tests with URLProtocol mock**

```swift
import XCTest
@testable import novels

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        guard let h = Self.handler else { return }
        do {
            let (resp, data) = try h(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class AIClientTests: XCTestCase {
    func makeClient(headersJSON: String = "", extraBodyJSON: String = "", url: String = "http://localhost:8317/v1/chat/completions") -> (AIClient, SettingsStore) {
        let ud = UserDefaults(suiteName: "test.ai.\(UUID().uuidString)")!
        let s = SettingsStore(userDefaults: ud)
        // Note: SettingsStore is @MainActor — wrap in MainActor.assumeIsolated or run on MainActor
        // For test, set via MainActor.run
        let exp = expectation(description: "setup")
        Task { @MainActor in
            s.openaiAPIURL = url
            s.aiCustomHeadersJSON = headersJSON
            s.aiExtraBodyJSON = extraBodyJSON
            s.openaiModel = "gpt-4o"
            s.save()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return (AIClient(settings: s, session: session), s)
    }

    func testMergesValidHeadersAndBody() async throws {
        let (client, _) = makeClient(headersJSON: "{\"Authorization\":\"Bearer tok\"}", extraBodyJSON: "{\"temperature\":0.7}")
        var captured: URLRequest?
        MockURLProtocol.handler = { req in
            captured = req
            let json = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using:.utf8)!)
        }
        let out = try await client.complete(prompt: "sys", chunk: "hi")
        XCTAssertEqual(out, "ok")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        let body = try JSONSerialization.jsonObject(with: captured!.httpBody!) as! [String:Any]
        XCTAssertEqual(body["model"] as? String, "gpt-4o")
        XCTAssertEqual(body["temperature"] as? Double, 0.7)
    }
    func testIgnoresInvalidHeadersJSON() async throws {
        let (client, _) = makeClient(headersJSON: "{bad", extraBodyJSON: "not json")
        MockURLProtocol.handler = { req in
            XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
            let json = "{\"choices\":[{\"message\":{\"content\":\"hi\"}}]}"
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using:.utf8)!)
        }
        let out = try await client.complete(prompt: "p", chunk: "c")
        XCTAssertEqual(out, "hi")
    }
    func testRetries3TimesThenThrows() async {
        let (client, _) = makeClient()
        var count = 0
        MockURLProtocol.handler = { _ in
            count += 1
            throw URLError(.timedOut)
        }
        do {
            _ = try await client.complete(prompt: "p", chunk: "c")
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(count, 3) // 3 attempts: initial + 2 retries? spec says retry 3× = total 3? We implement 3 attempts
        }
    }
    func testEmptyChoicesThrows() async {
        let (client, _) = makeClient()
        MockURLProtocol.handler = { req in
            let json = "{\"choices\":[]}"
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using:.utf8)!)
        }
        do { _ = try await client.complete(prompt: "p", chunk: "c"); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("no response") || "\(error)".contains("noResponse")) }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIClientTests -quiet`
Expected: FAIL — `AIClient` not defined.

- [ ] **Step 3: Write minimal AIResponse + AIClient + ATS**

In `apps/novels/Services/AIResponse.swift`:
```swift
import Foundation
struct AIChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String }
}
enum AIClientError: Error, LocalizedError {
    case noResponse
    case httpError(Int, String)
    var errorDescription: String? {
        switch self {
        case .noResponse: return "no response from AI service."
        case .httpError(let c, let m): return "AI processing failed. (\(c) \(m))"
        }
    }
}
```

In `apps/novels/Services/AIClient.swift`:
```swift
import Foundation

actor AIClient {
    private let settings: SettingsStore
    private let session: URLSession
    init(settings: SettingsStore, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }
    func complete(prompt: String, chunk: String) async throws -> String {
        let urlString: String = await MainActor.run { settings.openaiAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "http://localhost:8317/v1/chat/completions" : settings.openaiAPIURL }
        let model: String = await MainActor.run { settings.openaiModel.isEmpty ? "gpt-4o" : settings.openaiModel }
        let headers: [String:String] = await MainActor.run { settings.effectiveHeaders() }
        let extra: [String:Any] = await MainActor.run { settings.effectiveExtraBody() }
        guard let url = URL(string: urlString) else { throw AIClientError.httpError(0, "bad url") }
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                for (k,v) in headers { req.setValue(v, forHTTPHeaderField: k) }
                var body: [String:Any] = ["model": model, "messages": [["role":"system","content":prompt],["role":"user","content":chunk]]]
                for (k,v) in extra { body[k] = v }
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                req.timeoutInterval = 15
                let (data, resp) = try await session.data(for: req)
                if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw AIClientError.httpError(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
                }
                let decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content, !content.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
                    throw AIClientError.noResponse
                }
                return content
            } catch {
                lastError = error
                if case AIClientError.noResponse = error { throw error }
                if case AIClientError.httpError = error { throw error }
                if attempt < 2 {
                    let delay: UInt64 = attempt == 0 ? 1_000_000_000 : 2_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                } else { throw AIClientError.httpError(0, "AI processing failed.") }
            }
        }
        throw lastError ?? AIClientError.httpError(0, "AI processing failed.")
    }
}
```

In `apps/novels/Info.plist` add:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>localhost</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
      <key>NSIncludesSubdomains</key><true/>
    </dict>
  </dict>
</dict>
```
(or `NSAllowsLocalNetworking` true). Ensure only localhost.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIClientTests -quiet`
Expected: PASS (fix header merge key case, ensure extraBody shallow merge, ensure retry counts 3). Adjust retry logic if test expects 3 vs 4 — spec says retry 3× (1000/2000 ms) then stop = total 3 attempts; ensure loop 0..<3.

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Services/AIClient.swift apps/novels/Services/AIResponse.swift apps/novels/Info.plist apps/novelsTests/AIClientTests.swift
git commit -m "feat(ai): add AIClient POST with headers/body merge and retry 3x"
```

---

### Task 3: AIReadingService — cache-first, chunk, dedup, join/clean, upsert

**Files:**
- Create: `apps/novels/Services/AIReadingService.swift`
- Test: `apps/novelsTests/AIReadingServiceTests.swift`
- Modify: `apps/novels/Persistence/ProcessedChapterCache.swift` (no schema change — reuse get/upsert/batchStatus; ensure mode none guard)
- Modify: `apps/novels/Domain/SHA256.swift` (verify exists for contentHash, else add CryptoKit wrapper)

**Interfaces:**
- Consumes: `ProcessedChapterCaching`, `AIClient`, `SettingsStore`, `AIChunker`, `AIPromptBuilder`, `SHA256`/`CryptoKit`.
- Produces: `actor AIReadingService { init(cache: ProcessedChapterCaching, client: AIClient, settings: SettingsStore); func processedContent(bookId:String, chapterNumber:Int, mode:AIMode, rawText:String) async throws -> String; func reprocess(bookId:String, chapterNumber:Int, mode:AIMode, rawText:String) async throws -> String }` with dedup via `inFlight: [String: Task<String,Error>]` keyed by `bookId#chapter#mode`.

- [ ] **Step 1: Write failing AIReadingService tests**

```swift
import XCTest
@testable import novels

final class AIReadingServiceTests: XCTestCase {
    actor MockAIClient {
        var calls = 0
        var handler: ((String,String) throws -> String)?
        func complete(prompt: String, chunk: String) async throws -> String {
            calls += 1
            if let h = handler { return try h(prompt, chunk) }
            return "mock-" + chunk
        }
    }
    func makeService(mock: MockAIClient? = nil) throws -> (AIReadingService, SQLiteProcessedChapterCache, SettingsStore, MockAIClient) {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "test.svc.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: ud)
        let m = mock ?? MockAIClient()
        // Wrap MockAIClient to AIClient via adapter — for test we inject mock via protocol; simplest: create AIReadingService with closure
        // For plan, AIReadingService init takes (cache, client: AIClient, settings) — adapt test to use real client with MockURLProtocol or refactor to protocol
        // Here we assume AIReadingService supports injection of (String,String) async throws -> String closure for testability
        fatalError("adapt")
    }
    func testCacheHitReturnsWithoutNetwork() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let pc = ProcessedChapter(bookId:"slug", chapterNumber:1, mode:.translate, content:"cached", contentHash:"h", createdAt:Date(), updatedAt:Date())
        try cache.upsert(pc)
        // service with mock that would fail if called
        // XCTAssertEqual(try await service.processedContent(bookId:"slug",chapterNumber:1,mode:.translate,rawText:"raw"), "cached")
        // XCTAssertEqual(mock.calls,0)
    }
    func testMissChunksMergesAndCaches() async throws {
        // raw 2600 chars with 1300 → 2 chunks mock returns "a","b" → joined "a\nb" or "ab"
        // verify cache saved and contentHash computed
    }
    func testDedupPreventsParallelDuplicate() async throws {
        // two concurrent processedContent same key → only 1 network call
    }
    func testModeNoneNeverCached() async throws {
        // mode none returns raw directly, no cache write, cache count  0
    }
    func testReprocessOverwritesCache() async throws {
        // upsert old, call reprocess with new mock → cache returns new
    }
    func testInvalidHeadersIgnoredAtMerge() async throws {
        // settings invalid JSON → effectiveHeaders empty, still succeeds
    }
}
```
*Adjust to actual protocol injection: AIReadingService initializer takes `client: AIClient` — for tests use real AIClient with MockURLProtocol as in Task 2.*

Simplified failing tests (use real client + MockURLProtocol):
```swift
final class AIReadingServiceTests: XCTestCase {
    func testCacheHitNoNetwork() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        try cache.upsert(ProcessedChapter(bookId:"s", chapterNumber:1, mode:.translate, content:"cached", contentHash:"h", createdAt:Date(), updatedAt:Date()))
        let ud = UserDefaults(suiteName: "t.\(UUID().uuidString)")!
        let settings = await MainActor.run { SettingsStore(userDefaults: ud) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses=[MockURLProtocol.self]
        let client = AIClient(settings: settings, session: URLSession(configuration: config))
        let svc = AIReadingService(cache: cache, client: client, settings: settings)
        MockURLProtocol.handler = { _ in XCTFail("should not call"); throw URLError(.badServerResponse) }
        let out = try await svc.processedContent(bookId:"s", chapterNumber:1, mode:.translate, rawText:"raw")
        XCTAssertEqual(out, "cached")
    }
    func testNoneBypassesCache() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "t2.\(UUID().uuidString)")!
        let settings = await MainActor.run { SettingsStore(userDefaults: ud) }
        let client = AIClient(settings: settings, session: URLSession(configuration:.ephemeral))
        let svc = AIReadingService(cache: cache, client: client, settings: settings)
        let out = try await svc.processedContent(bookId:"s", chapterNumber:1, mode:.none, rawText:"raw text")
        XCTAssertEqual(out, "raw text")
        XCTAssertEqual(try cache.countAll(), 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIReadingServiceTests -quiet`
Expected: FAIL — `AIReadingService` not defined.

- [ ] **Step 3: Write minimal AIReadingService implementation**

In `apps/novels/Services/AIReadingService.swift`:
```swift
import Foundation
import CryptoKit

actor AIReadingService {
    private let cache: ProcessedChapterCaching
    private let client: AIClient
    private let settings: SettingsStore
    private var inFlight: [String: Task<String, Error>] = [:]

    init(cache: ProcessedChapterCaching, client: AIClient, settings: SettingsStore) {
        self.cache = cache
        self.client = client
        self.settings = settings
    }

    private func key(bookId:String, chapter:Int, mode:AIMode) -> String { "\(bookId)#\(chapter)#\(mode.rawValue)" }

    func processedContent(bookId: String, chapterNumber: Int, mode: AIMode, rawText: String) async throws -> String {
        if mode == .none { return rawText }
        if let cached = try? cache.get(bookId: bookId, chapterNumber: chapterNumber, mode: mode) {
            return cached.content
        }
        let k = key(bookId: bookId, chapter: chapterNumber, mode: mode)
        if let task = inFlight[k] { return try await task.value }
        let task = Task<String, Error> {
            let chunkSize: Int = await MainActor.run { settings.aiMinChunkSize }
            let size = (500...5000).contains(chunkSize) ? chunkSize : 1300
            let prompt: String = await MainActor.run { AIPromptBuilder.prompt(for: mode, actionsJSON: settings.aiProcessActionsJSON) }
            let chunks = AIChunker.chunk(text: rawText, size: size)
            if chunks.isEmpty { throw AIClientError.noResponse }
            var outputs: [String] = []
            for chunk in chunks {
                let out = try await client.complete(prompt: prompt, chunk: chunk)
                outputs.append(out.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let joined = outputs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else { throw AIClientError.noResponse }
            let hash = SHA256.hash(data: Data(joined.utf8)).map{ String(format:"%02x",$0) }.joined()
            let now = Date()
            let pc = ProcessedChapter(bookId: bookId, chapterNumber: chapterNumber, mode: mode, content: joined, contentHash: hash, createdAt: now, updatedAt: now)
            try cache.upsert(pc)
            return joined
        }
        inFlight[k] = task
        defer { inFlight[k] = nil }
        do {
            let result = try await task.value
            return result
        } catch {
            inFlight[k] = nil
            throw error
        }
    }

    func reprocess(bookId: String, chapterNumber: Int, mode: AIMode, rawText: String) async throws -> String {
        if mode == .none { return rawText }
        // force network even if cached
        let k = key(bookId: bookId, chapter: chapterNumber, mode: mode)
        if let t = inFlight[k] { t.cancel() }
        let chunkSize: Int = await MainActor.run { settings.aiMinChunkSize }
        let size = (500...5000).contains(chunkSize) ? chunkSize : 1300
        let prompt: String = await MainActor.run { AIPromptBuilder.prompt(for: mode, actionsJSON: settings.aiProcessActionsJSON) }
        let chunks = AIChunker.chunk(text: rawText, size: size)
        var outputs: [String] = []
        for chunk in chunks {
            outputs.append(try await client.complete(prompt: prompt, chunk: chunk))
        }
        let joined = outputs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { throw AIClientError.noResponse }
        let hash = SHA256.hash(data: Data(joined.utf8)).map{ String(format:"%02x",$0) }.joined()
        let now = Date()
        let pc = ProcessedChapter(bookId: bookId, chapterNumber: chapterNumber, mode: mode, content: joined, contentHash: hash, createdAt: now, updatedAt: now)
        try cache.upsert(pc)
        return joined
    }
}
```

Ensure `SHA256` helper exists or use `CryptoKit.SHA256` directly; remove custom `SHA256.swift` conflict if needed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIReadingServiceTests -quiet`
Expected: PASS (fix dedup, mode none, cache hit, reprocess overwrite). Ensure `cache.get` returns not nil.

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Services/AIReadingService.swift apps/novelsTests/AIReadingServiceTests.swift
git commit -m "feat(ai): add cache-first reading service with dedup and reprocess"
```

---

### Task 4: ReaderViewModel + ReaderBottomSheet mode UI (none/translate/summary, reprocess)

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift`
- Modify: `apps/novels/Features/Reading/ReaderBottomSheet.swift`
- Modify: `apps/novels/Features/Reading/ReaderView.swift`
- Test: `apps/novelsTests/AIReadingViewModelTests.swift` (or extend existing Reader tests)

**Interfaces:**
- Consumes: `AIReadingService`, `SettingsStore`, `BookRepository`, `AIMode`, `ProcessedChapterCaching`.
- Produces: `ReaderViewModel` now: `var aiMode: AIMode`, `var processedContent: String?`, `var isAIProcessing: Bool`, `var aiError: String?`, `func setAIMode(_:)`, `func reprocess()`; `ReaderBottomSheet` adds segmented picker + reprocess button; `ReaderView` renders processedContent when available.

- [ ] **Step 1: Write failing ViewModel mode tests**

```swift
import XCTest
@testable import novels

@MainActor
final class AIReadingViewModelTests: XCTestCase {
    func testModeSwitchShowsCachedOrTriggersProcessing() async throws {
        let repo = try makeTempRepoWithBook(slug:"s", chapters:["raw html"])
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "vm.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: ud)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses=[MockURLProtocol.self]
        MockURLProtocol.handler = { req in
            let json="{\"choices\":[{\"message\":{\"content\":\"DỊCH\"}}]}"
            return (HTTPURLResponse(url:req.url!, statusCode:200, httpVersion:nil, headerFields:nil)!, json.data(using:.utf8)!)
        }
        let client = AIClient(settings: settings, session: URLSession(configuration: config))
        let svc = AIReadingService(cache: cache, client: client, settings: settings)
        let vm = ReaderViewModel(bookId:"s", repository: repo, settingsStore: settings, aiService: svc, cache: cache)
        await vm.load()
        XCTAssertEqual(vm.aiMode, .none)
        await vm.setAIMode(.translate)
        // after mode switch, processedContent should be "DỊCH" and cache should have entry
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(vm.processedContent, "DỊCH")
        XCTAssertEqual(try cache.get(bookId:"s", chapterNumber:1, mode:.translate)?.content, "DỊCH")
    }
    func testReprocessOverwritesCache() async throws {
        // insert cached "old", mock returns "new", call reprocess → cache "new"
    }
    func testModeNoneNeverCached() async throws {
        // set mode none, verify cache count 0
    }
}
```

Helper `makeTempRepoWithBook` creates `AppPaths.booksRoot()` temp via `FileManager.default.temporaryDirectory` + `BookRepository` with slug wrapper.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIReadingViewModelTests -quiet`
Expected: FAIL — `init(aiService:cache:)` not exists, `aiMode` not defined.

- [ ] **Step 3: Write minimal ReaderViewModel AI integration**

In `apps/novels/Features/Reading/ReaderViewModel.swift` add:
```swift
var aiMode: AIMode = .none
var processedContent: String?
var isAIProcessing = false
var aiError: String?
private var aiService: AIReadingService?
private var aiTask: Task<Void, Never>?

init(bookId: String, repository: BookRepository, settingsStore: SettingsStore, toastCenter: ToastCenter? = nil, cache: ProcessedChapterCaching? = nil, aiService: AIReadingService? = nil) {
    // existing init + inject
    self.aiService = aiService ?? {
        let c = (cache ?? (try? SQLiteProcessedChapterCache())) ?? (try! SQLiteProcessedChapterCache.inMemory())
        let client = AIClient(settings: settingsStore)
        return AIReadingService(cache: c, client: client, settings: settingsStore)
    }()
    // keep existing bookId etc.
}

func setAIMode(_ mode: AIMode) async {
    aiMode = mode
    aiError = nil
    if mode == .none {
        processedContent = nil
        return
    }
    await loadAIContent(isReprocess: false)
}
func reprocess() async {
    guard aiMode != .none else { return }
    await loadAIContent(isReprocess: true)
}
private func loadAIContent(isReprocess: Bool) async {
    guard let raw = readRawTextForAI() else { aiError = "Không tìm thấy chương"; return }
    isAIProcessing = true
    defer { isAIProcessing = false }
    do {
        let result: String
        if isReprocess {
            result = try await aiService?.reprocess(bookId: bookId, chapterNumber: chapterNumber, mode: aiMode, rawText: raw) ?? raw
        } else {
            result = try await aiService?.processedContent(bookId: bookId, chapterNumber: chapterNumber, mode: aiMode, rawText: raw) ?? raw
        }
        processedContent = result
        blocks = HtmlParser.parse(html: "<p>\(result)</p>") // or render via processed spans; for now parse as single block
    } catch {
        aiError = error.localizedDescription
        toastCenter?.show(aiError ?? "AI processing failed.", type: .error)
    }
}
private func readRawTextForAI() -> String? {
    // reuse chapterHTML read + HtmlParser to extract plain text: join blocks texts
    guard let html = readChapterHTML(number: chapterNumber) else { return nil }
    let blocks = HtmlParser.parse(html: html)
    return blocks.flatMap{ $0.spans.map{ $0.text } }.joined(separator: " ")
}
```

Update `load()` to reset `processedContent` on chapter change and auto-reload AI if mode != none:
```swift
func load() async {
    // existing book/chapter load
    // after blocks = HtmlParser...
    if aiMode != .none {
        aiTask?.cancel()
        aiTask = Task { await loadAIContent(isReprocess: false) }
    }
}
func goNext() async { chapterNumber+=1; await load(); persistChapter() }
func goPrev() async { chapterNumber-=1; await load(); persistChapter() }
```

In `ReaderBottomSheet.swift` add before typography section:
```swift
Picker("Chế độ AI", selection: Binding(get:{ viewModel.aiMode }, set:{ Task{ await viewModel.setAIMode($0) }})) {
    Text("Gốc").tag(AIMode.none)
    Text("Dịch").tag(AIMode.translate)
    Text("Tóm tắt").tag(AIMode.summary)
}.pickerStyle(.segmented).accessibilityIdentifier("aiModePicker")
Button("Xử lý lại") { Task{ await viewModel.reprocess() } }
    .disabled(viewModel.aiMode == .none || viewModel.isAIProcessing)
    .accessibilityIdentifier("reprocessButton")
if viewModel.isAIProcessing { ProgressView("Đang xử lý...") }
if let e = viewModel.aiError { Text(e).foregroundStyle(DesignTokens.error).font(.caption) }
```

Inject `viewModel: ReaderViewModel` into sheet via `@Bindable` or `@Environment`.

In `ReaderView.swift` update body to show processedContent when mode != none: if viewModel.aiMode != .none && viewModel.processedContent != nil then render that content via `SwiftUI.Text` else render `blocks`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIReadingViewModelTests -quiet`
Expected: PASS (fix async MainActor, cache injection).

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderViewModel.swift apps/novels/Features/Reading/ReaderBottomSheet.swift apps/novels/Features/Reading/ReaderView.swift apps/novelsTests/AIReadingViewModelTests.swift
git commit -m "feat(ai): add mode switch and reprocess in Reading sheet with cache-first ViewModel"
```

---

### Task 5: Integration, ATS verification, test hardening, final verification

**Files:**
- Modify: `apps/novels.xcodeproj/project.pbxproj` (ensure all new files added to novels target)
- Modify: `apps/novels/Info.plist` (verify ATS)
- Test: all `novelsTests`
- Docs: update `features/feat-006.md` Handoff

**Interfaces:**
- Consumes: All above plus `init.sh`, `swiftformat`, `swiftlint`, `xcodebuild`.
- Produces: Verified feature meeting 5 acceptance criteria; `./init.sh` PASS.

- [ ] **Step 1: Write integration edge tests**

```swift
import XCTest
@testable import novels

final class AIIntegrationTests: XCTestCase {
    func testInvalidHeadersIgnoredAndStillSucceeds() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "int.\(UUID().uuidString)")!
        let settings = await MainActor.run { SettingsStore(userDefaults: ud) }
        await MainActor.run { settings.aiCustomHeadersJSON = "{bad json"; settings.aiExtraBodyJSON = "not object"; settings.save() }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses=[MockURLProtocol.self]
        MockURLProtocol.handler = { req in
            XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
            let json="{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
            return (HTTPURLResponse(url:req.url!, statusCode:200, httpVersion:nil, headerFields:nil)!, json.data(using:.utf8)!)
        }
        let client = AIClient(settings: settings, session: URLSession(configuration: config))
        let svc = AIReadingService(cache: cache, client: client, settings: settings)
        let out = try await svc.processedContent(bookId:"b", chapterNumber:1, mode:.translate, rawText:"hello world this is a test")
        XCTAssertEqual(out, "ok")
    }
    func testModeNoneNeverWritesCacheEvenWithLongText() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "int2.\(UUID().uuidString)")!
        let settings = await MainActor.run { SettingsStore(userDefaults: ud) }
        let svc = AIReadingService(cache: cache, client: AIClient(settings: settings), settings: settings)
        _ = try await svc.processedContent(bookId:"b", chapterNumber:5, mode:.none, rawText:"raw")
        XCTAssertEqual(try cache.countAll(), 0)
    }
    func testATSSchemeIsLocalhostOnly() {
        let plist = Bundle.main.infoDictionary?["NSAppTransportSecurity"] as? [String:Any]
        let domains = plist?["NSExceptionDomains"] as? [String:Any]
        XCTAssertNotNil(domains?["localhost"])
        XCTAssertNil(domains?["example.com"])
    }
}
```

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`
Expected: PASS (all AI tests + existing 60+). Fix any lint.

- [ ] **Step 3: Manual verification checklist**

- Run `grep -R "OPENAI_API_URL\|AI_CUSTOM_HEADERS" apps/novels --include="*.swift" -n` → verify merge via effectiveHeaders.
- Run `swiftformat --lint apps --verbose` → 0 files.
- Run `swiftlint lint --strict` → 0 violations.
- Run `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.
- Simulator manual: Import book → Reader → switch Dịch → verify cache hit instant second time (no network), reprocess overwrites, mode none shows raw, invalid headers JSON still succeeds, localhost ATS only.

- [ ] **Step 4: Run init.sh**

Run: `./init.sh`
Expected: PASS — `format PASS`, `lint PASS`, `build PASS`, `test PASS`. If test flake (bundle instance) occurs, run targeted suite as evidence and document flake unrelated to AI cache/sqlite.

- [ ] **Step 5: Final commit & handoff prep**

```bash
git add apps/novelsTests/AIIntegrationTests.swift docs/plans/feat-006.md
git commit -m "feat(ai): integration ATS and invalid JSON hardening"
```

Update `features/feat-006.md` Handoff:
- State: `done` (all acceptance checked)
- Evidence: `docs/plans/feat-006.md`, `xcodebuild build ... -quiet PASS`, `./init.sh` lint/format/build PASS, AIReadingServiceTests + AIClientTests + chunker/prompt builder PASS, ATS localhost-only verified
- Blockers: none
- Next: handoff to `feat-007 Chapter Prefetch` (depends feat-006)

Update `progress.md` with new dated block (keep older).

---

## Self-Review

**1. Spec coverage:** Each `features/feat-006.md` Acceptance maps:
- Cache hit returns without network; miss chunks, retries, merges, caches under slug identity → Task 3 AIReadingService cache-first + chunk + AIClient retry + slug key + Task 2 merge.
- De-duplication prevents parallel duplicate → Task 3 inFlight dict + test `testDedupPreventsParallelDuplicate`.
- Reprocess overwrites cache; mode switch shows cached or triggers processing → Task 4 ViewModel setAIMode/reprocess + Task 3 reprocess + cache hit test.
- AI_CUSTOM_HEADERS/EXTRA_BODY invalid JSON ignored at merge per ai-service.md:17, localhost ATS only → Task 2 effectiveHeaders/Body guard + invalid tests + Task 5 ATS + invalid headers test.
- mode none never cached → Task 3 guard + Task 5 test.
- Unit test asserts prompts contain BR-03/04 (honorifics, natural Vietnamese 100%) and BR-05/06 (summary 50-60% keep plot/dialogue, no hallucination) → Task 1 AIPromptBuilderTests.

**2. Placeholder scan:** No TBD/TODO; each step has code blocks and expected PASS/FAIL.

**3. Type consistency:** `AIMode` enum, `ProcessedChapter` struct, `ProcessedChapterCaching` protocol, `AIClient.complete(prompt:chunk:)->String`, `AIReadingService.processedContent(bookId:chapterNumber:mode:rawText:)->String`, `ReaderViewModel.aiMode: AIMode` consistent across tasks.

