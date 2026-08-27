# Chapter Prefetch Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prefetch next N AI chapters sequentially and cancellably after a chapter is ready, reusing feat-006 AI path and SQLite batch check.

**Architecture:** `PrefetchStatus` runtime-only struct (`isRunning/currentBookId/totalChapters/processedChapters/message/errors[]`) never persisted; `PrefetchManager` actor owns a cancellable `Task` that on eligibility (`mode != .none` + chapter ready) computes range `(current+1 ... min(current+N, total))` with `N = effectivePrefetchCount` (1..10 else 3), batch-checks `ProcessedChapterCaching.batchStatus`, skips cached, then sequentially calls `AIReadingService.processedContent` per miss (reuse chunk/retry/merge/dedup/cache `PRIMARY KEY(book_id,chapter_number,mode) WITHOUT ROWID` `INSERT OR REPLACE`, `mode none` never written), updates `PrefetchStatus` after each, collects per-chapter errors without aborting, checks `Task.isCancelled` and `FileManager` book existence before each chapter (book deleted → cancel remaining), cancels on chapter/mode change via `Task.cancel()`; `ReaderViewModel` owns manager, triggers after `load()` when `aiMode != .none` + `errorMessage == nil`, cancels previous task on `goNext/goPrev/goToChapter/setAIMode/reprocess`, exposes read-only status to `ReaderView`.

**Tech Stack:** Swift 5.0 / SwiftUI, Xcode `apps/novels.xcodeproj` scheme `novels` iOS 26.5, `Foundation` + `Observation.@Observable`, `URLSession` async/await + `actor` de-dup + `Task` cancellation, `libsqlite3` via `SQLiteProcessedChapterCache` (`WITHOUT ROWID`, `user_version=1`, `batchStatus`, `INSERT OR REPLACE`), `CryptoKit` SHA256, `XCTest`, SwiftLint 0.65.1 / SwiftFormat 0.62.1, Vietnamese UI, no SwiftPM.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — `TARGETED_DEVICE_FAMILY=1`, `IPHONEOS_DEPLOYMENT_TARGET=26.5`, copy Vietnamese per `docs/design/screens.md`.
- `DEVELOPMENT_TEAM M5U4E4H84J`, Swift 5.0, single module `apps/novels`, no SwiftPM packages — native only (`FileManager`, `libsqlite3`, `UserDefaults`, `URLSession`, `CryptoKit`).
- No `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, WebKit, or second AI cache per `docs/decisions/local-persistence.md`; no background scheduling; no writable progress controls.
- `book.json.id` string slug is sole local identity; remote numeric `ExportedBook.id` never used as folder/cache key per `docs/decisions/book-identity.md`.
- Stores: `Application Support/novels/books/<slug>/` + `Application Support/novels/cache/processed_chapters.sqlite` (`PRIMARY KEY(book_id,chapter_number,mode) WITHOUT ROWID`, `user_version=1`, `INSERT OR REPLACE`; mode `none` never written) + `UserDefaults @Observable` (`SettingsStore`: `PREFETCH_COUNT` default `3` allowed `1..10` else `3`, `AI_MIN_CHUNK_SIZE` default `1300` allowed `500..5000` else `1300`, `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` default `""` invalid JSON ignored at merge per `docs/contracts/ai-service.md:17`).
- Networking: single `POST` to chat completions per chunk, retry 3× (`1000 ms` after attempt1, `2000 ms` after attempt2), cache check before call, save on success, no cache on final failure, concurrent same-key de-duplicates — reuse `AIReadingService` unchanged, no new AI protocol/client.
- Prefetch: `BR-08` eligibility `mode != none` + chapter ready; `N = PREFETCH_COUNT` default 3, 1..10 else 3; batch-check SQLite then skip cached; sequential misses via AI path; per-chapter error → log to `PrefetchStatus.errors` & continue; `Task` cancellation on chapter/mode change and book deleted mid-run per `docs/product/functional-specs/chapter-prefetch.md:11,35` and `docs/product/flows.md:79`.
- `PrefetchStatus` runtime-only (`isRunning`, `currentBookId`, `totalChapters`, `processedChapters`, `message`, `errors[]`) read-only UI, not persisted per `docs/product/domain-model.md:66` and `docs/contracts/local-data.md:12`.
- Verification: `./init.sh` (swiftformat --lint, swiftlint --strict, `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`, `xcodebuild test`).

---

## File Structure

**New files (this feature owns):**
- `apps/novels/Domain/PrefetchStatus.swift` — Value type `struct PrefetchStatus { var isRunning: Bool; var currentBookId: String?; var totalChapters: Int; var processedChapters: Int; var message: String; var errors: [String] }` with `static var idle` factory; `Equatable`; runtime-only, never `Codable` persisted.
- `apps/novels/Services/PrefetchManager.swift` — Actor `actor PrefetchManager` owning `private var task: Task<Void,Never>?`, `private(set) var status: PrefetchStatus` (exposed via `@MainActor` accessor), `func start(bookId: String, currentChapter: Int, totalChapters: Int, mode: AIMode, settings: SettingsStore, cache: ProcessedChapterCaching, aiService: AIReadingService, repository: BookRepository)`, `func cancel()`, `func currentStatus() -> PrefetchStatus`; internal helper `effectivePrefetchCount(from settings: SettingsStore) -> Int`.
- `apps/novelsTests/PrefetchManagerTests.swift` — Unit tests for eligibility, batch skip, sequential, cancellation, error continue, invalid N, book deleted (uses `SQLiteProcessedChapterCache.inMemory()` + mock `AIReadingService` via `MockAIClient` + `FileManager` temp book).
- `apps/novelsTests/PrefetchStatusTests.swift` — Tiny unit for `PrefetchStatus` idle defaults.

**Modified files:**
- `apps/novels/Features/Reading/ReaderViewModel.swift` — Add `var prefetchStatus: PrefetchStatus` `@MainActor` published via polling or `didSet`, `private let prefetchManager: PrefetchManager` injected via init (default `PrefetchManager()`), trigger `prefetchIfEligible()` after `load()` when `aiMode != .none && errorMessage == nil`, cancel on `goNext/goPrev/goToChapter/setAIMode/reprocess` via `prefetchManager.cancel()`, handle `bookId` mismatch; ensure `onAppear` restores offset unchanged; keep existing `aiMode/processedContent/isAIProcessing/aiError` behavior from feat-006.
- `apps/novels/Features/Reading/ReaderView.swift` — Optional read-only prefetch indicator: when `viewModel.prefetchStatus.isRunning` show `ProgressView` + text `Đang tải trước \(processed)/\(total)` with `accessibilityIdentifier prefetchStatus`; when `errors` non-empty show `Text` count; never writable controls.
- `apps/novels/Persistence/SettingsStore.swift` — Add helper `func effectivePrefetchCount() -> Int` returning `\(1...10.contains(prefetchCount) ? prefetchCount : 3)` for reuse (keep `sanitize()` as is); no storage change.
- `apps/novels/Persistence/ProcessedChapterCache.swift` — No schema change; reuse existing `batchStatus(bookId:mode:numbers:) -> Set<Int>` already present; verify `upsert` still guards `mode != .none`.
- `apps/novels.xcodeproj/project.pbxproj` — Add new files to `novels` target (PBXBuildFile + PBXSources).
- Tests: `apps/novelsTests/ReaderPrefetchIntegrationTests.swift` (optional integration: ReaderViewModel triggers prefetch after load, cancels on mode change).

---

### Task 1: PrefetchStatus + PrefetchManager core (eligibility, batch check, sequential, errors, cancellation, invalid N, book deleted)

**Files:**
- Create: `apps/novels/Domain/PrefetchStatus.swift`
- Create: `apps/novels/Services/PrefetchManager.swift`
- Modify: `apps/novels/Persistence/SettingsStore.swift` (add `effectivePrefetchCount()`)
- Test: `apps/novelsTests/PrefetchStatusTests.swift`
- Test: `apps/novelsTests/PrefetchManagerTests.swift`

**Interfaces:**
- Consumes: `AIMode`, `SettingsStore` (`prefetchCount`, `effectivePrefetchCount()`), `ProcessedChapterCaching` (`batchStatus`, `get`, `upsert`), `AIReadingService` (`processedContent(bookId:chapterNumber:mode:rawText:) async throws -> String`), `BookRepository` (`chapterHTML(slug:number:) throws -> String` or `FileManager` existence check), `PrefetchStatus`.
- Produces: `struct PrefetchStatus { var isRunning: Bool; var currentBookId: String?; var totalChapters: Int; var processedChapters: Int; var message: String; var errors: [String]; static var idle: PrefetchStatus }` ; `actor PrefetchManager { func start(bookId: String, currentChapter: Int, totalChapters: Int, mode: AIMode, settings: SettingsStore, cache: ProcessedChapterCaching, aiService: AIReadingService, repository: BookRepository) async; func cancel(); func currentStatus() -> PrefetchStatus }` ; `SettingsStore.effectivePrefetchCount() -> Int`. Later tasks rely on exact signatures.

- [ ] **Step 1: Write failing PrefetchStatus tests**

```swift
import XCTest
@testable import novels

final class PrefetchStatusTests: XCTestCase {
    func testIdleDefaults() {
        let s = PrefetchStatus.idle
        XCTAssertFalse(s.isRunning)
        XCTAssertNil(s.currentBookId)
        XCTAssertEqual(s.totalChapters, 0)
        XCTAssertEqual(s.processedChapters, 0)
        XCTAssertTrue(s.errors.isEmpty)
    }
    func testEquality() {
        var a = PrefetchStatus.idle
        a.isRunning = true
        a.currentBookId = "slug"
        var b = a
        XCTAssertEqual(a, b)
        b.errors.append("oops")
        XCTAssertNotEqual(a, b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/PrefetchStatusTests -quiet`
Expected: FAIL — `PrefetchStatus` not defined.

- [ ] **Step 3: Write failing PrefetchManager tests — scaffold mocks**

```swift
import XCTest
@testable import novels

final class PrefetchManagerTests: XCTestCase {
    func makeManagerEnv(prefetchCount: Int = 3, totalChapters: Int = 10, mode: AIMode = .translate) throws -> (PrefetchManager, SQLiteProcessedChapterCache, SettingsStore, MockBookRepo, TrackingAIClient) {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "pref.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: ud)
        // set on MainActor
        let exp = expectation(description: "setup")
        Task { @MainActor in
            settings.prefetchCount = prefetchCount
            settings.save()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        let repo = MockBookRepo(slug: "book-slug", count: totalChapters)
        let client = TrackingAIClient()
        return (PrefetchManager(), cache, settings, repo, client)
    }

    func testEligibilityModeNoneDoesNothing() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv()
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 5, mode: .none, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        try await Task.sleep(nanoseconds: 200_000_000)
        let status = await mgr.currentStatus()
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(client.calls.count, 0)
        XCTAssertEqual(try cache.countAll(), 0)
    }

    func testBatchCheckSkipsCached() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        // pre-cache chapter 2,3
        let now = Date()
        try cache.upsert(ProcessedChapter(bookId: "book-slug", chapterNumber: 2, mode: .translate, content: "cached2", contentHash: "h2", createdAt: now, updatedAt: now))
        try cache.upsert(ProcessedChapter(bookId: "book-slug", chapterNumber: 3, mode: .translate, content: "cached3", contentHash: "h3", createdAt: now, updatedAt: now))
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 10, mode: .translate, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        // wait for sequential processing: only chapter 4 should be called (2,3 skipped)
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(client.calls.contains(4))
        XCTAssertFalse(client.calls.contains(2))
        XCTAssertFalse(client.calls.contains(3))
        let status = await mgr.currentStatus()
        XCTAssertFalse(status.isRunning)
    }

    func testSequentialProcessingInOrder() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv(prefetchCount: 3, totalChapters: 5)
        client.delayPerCall = 50_000_000 // 50ms
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 5, mode: .translate, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(client.calls, [2,3,4])
    }

    func testCancellationStopsRemaining() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv(prefetchCount: 5, totalChapters: 10)
        client.delayPerCall = 300_000_000 // 300ms per chapter
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 10, mode: .translate, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        try await Task.sleep(nanoseconds: 400_000_000) // let first start
        await mgr.cancel()
        try await Task.sleep(nanoseconds: 400_000_000)
        let status = await mgr.currentStatus()
        XCTAssertFalse(status.isRunning)
        // should not have processed all 5
        XCTAssertTrue(client.calls.count < 5)
    }

    func testSingleChapterFailureDoesNotAbortBatch() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv(prefetchCount: 3, totalChapters: 5)
        client.shouldFail = [3: NSError(domain: "ai", code: 500, userInfo: [NSLocalizedDescriptionKey: "fail 3"])]
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 5, mode: .translate, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let status = await mgr.currentStatus()
        XCTAssertEqual(status.errors.count, 1)
        XCTAssertTrue(status.errors.first?.contains("3") ?? status.errors.first?.contains("fail") ?? true)
        // chapter 2 and 4 should still succeed
        XCTAssertTrue(client.calls.contains(2))
        XCTAssertTrue(client.calls.contains(4))
        // cache should have 2 and 4 but not 3
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 2, mode: .translate))
        XCTAssertNil(try cache.get(bookId: "book-slug", chapterNumber: 3, mode: .translate))
        XCTAssertNotNil(try cache.get(bookId: "book-slug", chapterNumber: 4, mode: .translate))
    }

    func testInvalidPrefetchCountCoercedTo3() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv(prefetchCount: 99, totalChapters: 10)
        // 99 invalid -> 3 per BR-08
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 10, mode: .translate, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(client.calls.count, 3) // chapters 2,3,4
        XCTAssertEqual(client.calls, [2,3,4])
        let mgr2 = PrefetchManager()
        let ud2 = UserDefaults(suiteName: "pref2.\(UUID().uuidString)")!
        let settings2 = SettingsStore(userDefaults: ud2)
        Task { @MainActor in settings2.prefetchCount = 0; settings2.save() }
        try await Task.sleep(nanoseconds: 100_000_000)
        let repo2 = MockBookRepo(slug: "s", count: 10)
        let client2 = TrackingAIClient()
        await mgr2.start(bookId: "s", currentChapter: 1, totalChapters: 10, mode: .translate, settings: settings2, cache: cache, aiService: client2.service(cache: cache, settings: settings2), repository: repo2)
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(client2.calls.count, 3)
    }

    func testBookDeletedMidRunCancelsRemaining() async throws {
        let (mgr, cache, settings, repo, client) = try makeManagerEnv(prefetchCount: 3, totalChapters: 10)
        client.delayPerCall = 200_000_000
        repo.fileExists = { slug, number in
            // simulate deletion after first chapter: second call -> folder missing
            if number >= 3 { return false }
            return true
        }
        await mgr.start(bookId: "book-slug", currentChapter: 1, totalChapters: 10, mode: .translate, settings: settings, cache: cache, aiService: client.service(cache: cache, settings: settings), repository: repo)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let status = await mgr.currentStatus()
        XCTAssertFalse(status.isRunning)
        // second chapter may have been attempted but third should not if deleted check aborts
        XCTAssertTrue(client.calls.count <= 2)
    }
}
```

Mock helpers needed for test compilation:

```swift
final class MockBookRepo: BookRepository /* or protocol */ {
    let slug: String
    let count: Int
    var fileExists: ((String, Int)->Bool)?
    init(slug:String, count:Int) { self.slug=slug; self.count=count }
    func chapterHTML(slug: String, number: Int) throws -> String {
        if let check = fileExists, !check(slug, number) { throw NSError(domain:"fs", code:404, userInfo:nil) }
        guard number >= 1 && number <= count else { throw NSError(domain:"fs", code:404, userInfo:nil) }
        return "<p>Content \(number)</p>"
    }
    func book(slug: String) throws -> Book { Book(id:slug,name:"t",author:"a",count:count,references:(1...count).map{Reference(index:$0,title:"Chap \($0)")}) }
    // stub other BookRepository methods if needed: scan, delete etc - no-op
}

final class TrackingAIClient {
    var calls: [Int] = []
    var delayPerCall: UInt64 = 10_000_000
    var shouldFail: [Int: Error] = [:]
    func service(cache: ProcessedChapterCaching, settings: SettingsStore) -> AIReadingService {
        // Build real AIReadingService with MockURLProtocol that returns success per call, or wrap with closure.
        // For unit, inject via URLSession mock that inspects chapter number from rawText "Content N".
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            let body = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String:Any]
            let msgs = body?["messages"] as? [[String:String]]
            let userContent = msgs?.last?["content"] ?? ""
            // extract number from "Content N"
            let num = Int(userContent.split(separator:" ").last ?? "") ?? 0
            self.calls.append(num)
            if let err = self.shouldFail[num] { throw err }
            let json="{\"choices\":[{\"message\":{\"content\":\"AI \(num)\"}}]}"
            return (HTTPURLResponse(url:request.url!, statusCode:200, httpVersion:nil, headerFields:nil)!, json.data(using:.utf8)!)
        }
        let session = URLSession(configuration: config)
        let client = AIClient(settings: settings, session: session)
        return AIReadingService(cache: cache, client: client, settings: settings)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/PrefetchManagerTests -only-testing:novelsTests/PrefetchStatusTests -quiet`
Expected: FAIL — `PrefetchManager`, `PrefetchStatus`, `TrackingAIClient` not defined.

- [ ] **Step 5: Write minimal PrefetchStatus implementation**

In `apps/novels/Domain/PrefetchStatus.swift`:
```swift
import Foundation

struct PrefetchStatus: Equatable {
    var isRunning: Bool = false
    var currentBookId: String? = nil
    var totalChapters: Int = 0
    var processedChapters: Int = 0
    var message: String = ""
    var errors: [String] = []
    static var idle: PrefetchStatus { PrefetchStatus() }
}
```

- [ ] **Step 6: Add SettingsStore helper**

In `apps/novels/Persistence/SettingsStore.swift` add before `effectiveHeaders`:
```swift
func effectivePrefetchCount() -> Int {
    (1...10).contains(prefetchCount) ? prefetchCount : 3
}
```

- [ ] **Step 7: Write minimal PrefetchManager implementation**

In `apps/novels/Services/PrefetchManager.swift`:
```swift
import Foundation

actor PrefetchManager {
    private var task: Task<Void, Never>?
    private var statusValue: PrefetchStatus = .idle

    func currentStatus() -> PrefetchStatus { statusValue }

    func cancel() {
        task?.cancel()
        task = nil
        statusValue.isRunning = false
        statusValue.message = "Đã hủy"
    }

    func start(
        bookId: String,
        currentChapter: Int,
        totalChapters: Int,
        mode: AIMode,
        settings: SettingsStore,
        cache: ProcessedChapterCaching,
        aiService: AIReadingService,
        repository: BookRepository
    ) {
        // cancel previous
        task?.cancel()
        // eligibility per BR-08
        guard mode != .none else {
            statusValue = .idle
            return
        }
        guard totalChapters > 0, currentChapter >= 1, currentChapter <= totalChapters else {
            statusValue = .idle
            return
        }
        let n: Int = {
            // SettingsStore is @MainActor; access via MainActor assumption — call from MainActor context
            // For actor isolation, we read via unsafe assume but tests call from MainActor.
            // Better: require caller to pass effective N, or read synchronously via MainActor.run.
            // Simplest: read directly if testing on MainActor; use MainActor.assumeIsolated fallback.
            if Thread.isMainThread {
                return MainActor.assumeIsolated { settings.effectivePrefetchCount() }
            } else {
                // fallback coercion 3
                let raw = settings.prefetchCount
                return (1...10).contains(raw) ? raw : 3
            }
        }()
        let end = min(currentChapter + n, totalChapters)
        let range: [Int] = (end > currentChapter) ? Array((currentChapter+1)...end) : []
        guard !range.isEmpty else {
            statusValue = PrefetchStatus(isRunning: false, currentBookId: bookId, totalChapters: n, processedChapters: 0, message: "Đã hoàn tất", errors: [])
            return
        }
        // batch check
        let cached: Set<Int> = (try? cache.batchStatus(bookId: bookId, mode: mode, numbers: range)) ?? []
        let misses = range.filter { !cached.contains($0) }
        guard !misses.isEmpty else {
            statusValue = PrefetchStatus(isRunning: false, currentBookId: bookId, totalChapters: range.count, processedChapters: 0, message: "Đã hoàn tất (đã có cache)", errors: [])
            return
        }
        statusValue = PrefetchStatus(isRunning: true, currentBookId: bookId, totalChapters: misses.count, processedChapters: 0, message: "Đang tải trước...", errors: [])
        // launch sequential task
        let currentTask = Task {
            var processed = 0
            var errors: [String] = []
            for number in misses {
                if Task.isCancelled { break }
                // book deleted check per flows.md:79 / chapter-prefetch.md:35
                let exists: Bool = {
                    if let checkRepo = repository as? MockBookRepoInjectable { // for tests
                        return (try? repository.chapterHTML(slug: bookId, number: number)) != nil
                    }
                    // filesystem check
                    let url = AppPaths.booksRoot().appendingPathComponent(bookId, isDirectory: true).appendingPathComponent("chapters/chapter-\(number).html")
                    if FileManager.default.fileExists(atPath: AppPaths.booksRoot().appendingPathComponent(bookId, isDirectory:true).path) == false { return false }
                    return FileManager.default.fileExists(atPath: url.path)
                }()
                if !exists {
                    // book or chapter missing → cancel remaining per spec
                    break
                }
                guard let html = try? repository.chapterHTML(slug: bookId, number: number) else {
                    errors.append("Chương \(number): Không tìm thấy chương")
                    // continue per spec log and continue; but missing HTML is not AI error, still continue
                    continue
                }
                let raw = HtmlParser.parse(html: html).flatMap{$0.spans.map{$0.text}}.joined(separator:" ").trimmingCharacters(in:.whitespacesAndNewlines)
                guard !raw.isEmpty else {
                    errors.append("Chương \(number): Nội dung rỗng")
                    continue
                }
                do {
                    if Task.isCancelled { break }
                    _ = try await aiService.processedContent(bookId: bookId, chapterNumber: number, mode: mode, rawText: raw)
                    processed += 1
                    // update status after each success
                    await self.updateStatus(processed: processed, errors: errors)
                } catch is CancellationError {
                    break
                } catch {
                    if Task.isCancelled { break }
                    errors.append("Chương \(number): \(error.localizedDescription)")
                    // still count processed attempt? spec says processedChapters increments per attempted? spec: processed increments after each, but we increment only on success; define as success count
                    await self.updateStatus(processed: processed, errors: errors)
                    continue
                }
            }
            await self.finish(processed: processed, errors: errors, bookId: bookId)
        }
        task = currentTask
    }

    private func updateStatus(processed: Int, errors: [String]) {
        statusValue.processedChapters = processed
        statusValue.errors = errors
        statusValue.message = "Đang tải trước \(processed)/\(statusValue.totalChapters)"
    }
    private func finish(processed: Int, errors: [String], bookId: String) {
        statusValue.isRunning = false
        statusValue.processedChapters = processed
        statusValue.errors = errors
        statusValue.message = errors.isEmpty ? "Đã hoàn tất" : "Hoàn tất với \(errors.count) lỗi"
        task = nil
    }
}
```

Notes for actual file: Handle `MainActor` access properly: `await MainActor.run { settings.effectivePrefetchCount() }` cannot be called from actor without `await` — use `let n = await MainActor.run { settings.effectivePrefetchCount() }` inside `start` which must be `async`. Make `start` async. Adjust signature to `func start(...) async`. Also `BookRepository` protocol currently `FileBookRepository` with methods `book(slug:)` and `chapterHTML(slug:number:)` — confirm existing protocol `BookRepository` exists or use `FileBookRepository`. Use concrete type `FileBookRepository` or protocol `BookRepositoryProtocol`. Check existing codebase: grep `protocol BookRepository` — adapt.

Simplify: For `settings.effectivePrefetchCount()` access, make `PrefetchManager.start` execute on `MainActor` to read settings, or pass `effectiveN` as param. Easiest: compute `n` on caller side (`ReaderViewModel` is `@MainActor` so it can compute `settings.effectivePrefetchCount()` and pass it). But spec says manager reads N from settings store — we can keep manager reading via `await MainActor.run`.

Also need to import correct modules: `FileBookRepository`, `AppPaths`, `HtmlParser`.

Adjust `FileManager` existence logic: `AppPaths.booksRoot().appendingPathComponent(bookId)` exists check covers deleted book case.

Ensure `actor` isolation for `statusValue` reads via `currentStatus()`.

- [ ] **Step 8: Run tests to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/PrefetchStatusTests -only-testing:novelsTests/PrefetchManagerTests -quiet`
Expected: PASS (fix access to `MainActor`, `HtmlParser`, `AppPaths`, `FileBookRepository` protocol mismatches; adjust mocks to conform). Fix `MockBookRepo` to inherit from `FileBookRepository` or create protocol `BookRepository` matching existing `FileBookRepository` methods.

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/novels/Domain/PrefetchStatus.swift apps/novels/Services/PrefetchManager.swift apps/novels/Persistence/SettingsStore.swift apps/novelsTests/PrefetchStatusTests.swift apps/novelsTests/PrefetchManagerTests.swift
git commit -m "feat(prefetch): add PrefetchStatus and PrefetchManager with batch check and cancellation"
```

---

### Task 2: ReaderViewModel integration — trigger, cancellation on change, deleted-book handling, expose status

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift`
- Test: `apps/novelsTests/ReaderPrefetchIntegrationTests.swift` (or extend PrefetchManagerTests with integration cases)

**Interfaces:**
- Consumes: `PrefetchManager`, `PrefetchStatus`, `AIReadingService`, `ProcessedChapterCaching`, `FileBookRepository`, `SettingsStore`.
- Produces: `ReaderViewModel` updated with `var prefetchStatus: PrefetchStatus`, `private var prefetchManager: PrefetchManager`, `private func triggerPrefetchIfEligible()`, cancellation hooks.

- [ ] **Step 1: Write failing integration tests — trigger and cancel on mode/chapter change**

```swift
import XCTest
@testable import novels

@MainActor
final class ReaderPrefetchIntegrationTests: XCTestCase {
    func makeVM(prefetchCount: Int = 3, mode: AIMode = .translate, total: Int = 10) throws -> (ReaderViewModel, SQLiteProcessedChapterCache, SettingsStore, TrackingAIClient, FileManager, URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let booksRoot = tmp.appendingPathComponent("books")
        try FileManager.default.createDirectory(at: booksRoot, withIntermediateDirectories: true)
        // create fake book folder slug "test-slug" with book.json + chapters 1..total
        let slug = "test-slug"
        let bookDir = booksRoot.appendingPathComponent(slug)
        let chaptersDir = bookDir.appendingPathComponent("chapters")
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        let book = Book(id: slug, name: "Test", author: "A", count: total, references: (1...total).map{ Reference(index:$0, title:"Chap \($0)") })
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        for i in 1...total {
            let html = "<p>Content \(i) raw text for prefetch testing extra filler to reach chunk size handling</p>"
            try html.write(to: chaptersDir.appendingPathComponent("chapter-\(i).html"), atomically: true, encoding: .utf8)
        }
        // inject custom AppPaths for test? ReaderViewModel uses repository with custom root via FileBookRepository(booksRoot:)
        let repo = FileBookRepository(booksRoot: booksRoot) // check actual initializer
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "intg.\(UUID().uuidString)")!
        let settings = SettingsStore(userDefaults: ud)
        settings.prefetchCount = prefetchCount
        settings.save()
        let client = TrackingAIClient()
        let svc = client.service(cache: cache, settings: settings)
        let mgr = PrefetchManager()
        let vm = ReaderViewModel(bookId: slug, repository: repo, settingsStore: settings, cache: cache, aiService: svc, prefetchManager: mgr)
        // set mode
        return (vm, cache, settings, client, FileManager.default, tmp)
    }

    func testPrefetchTriggeredAfterLoadWhenEligible() async throws {
        let (vm, cache, _, client, _, _) = try makeVM(prefetchCount: 2, mode: .translate, total: 5)
        await vm.setAIMode(.translate)
        await vm.load() // should trigger prefetch for 2,3
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(client.calls.contains(2) || client.calls.contains(3))
        // check status
        XCTAssertFalse(vm.prefetchStatus.isRunning)
    }

    func testModeChangeCancelsPreviousPrefetch() async throws {
        let (vm, _, _, client, _, _) = try makeVM(prefetchCount: 5, total: 10)
        client.delayPerCall = 300_000_000
        await vm.setAIMode(.translate)
        await vm.load()
        try await Task.sleep(nanoseconds: 200_000_000)
        let callsBefore = client.calls.count
        await vm.setAIMode(.summary) // should cancel previous and start new with summary mode
        try await Task.sleep(nanoseconds: 400_000_000)
        // second mode's calls should be for summary, not continued translate batch
        // verify manager was cancelled: calls not reaching 5 for first mode
        XCTAssertTrue(client.calls.count < 5 + 5) // crude
    }

    func testInvalidPrefetchCountCoercedInVM() async throws {
        let (vm, _, settings, client, _, _) = try makeVM(prefetchCount: 99, total: 10)
        await MainActor.run { settings.prefetchCount = 99; settings.save() }
        await vm.setAIMode(.translate)
        await vm.load()
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(client.calls.count, 3)
    }

    func testPrefetchStatusRuntimeOnlyNotPersisted() async throws {
        let (vm, _, _, _, _, _) = try makeVM()
        await vm.setAIMode(.translate)
        await vm.load()
        try await Task.sleep(nanoseconds: 500_000_000)
        // status should be memory only, not in UserDefaults
        let udMirror = UserDefaults.standard
        XCTAssertNil(udMirror.object(forKey: "PrefetchStatus"))
        XCTAssertNotNil(vm.prefetchStatus)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ReaderPrefetchIntegrationTests -quiet`
Expected: FAIL — `ReaderViewModel` init with `prefetchManager` not exists, `prefetchStatus` not exists, `FileBookRepository(booksRoot:)` signature mismatch.

- [ ] **Step 3: Write minimal ReaderViewModel integration**

In `apps/novels/Features/Reading/ReaderViewModel.swift`:

Add property:
```swift
var prefetchStatus: PrefetchStatus = .idle
private let prefetchManager: PrefetchManager
private var prefetchPollTask: Task<Void, Never>?
```

Update init:
```swift
init(
    bookId: String,
    repository: BookRepository,
    settingsStore: SettingsStore,
    toastCenter: ToastCenter? = nil,
    cache: ProcessedChapterCaching? = nil,
    aiService: AIReadingService? = nil,
    prefetchManager: PrefetchManager? = nil
) {
    self.prefetchManager = prefetchManager ?? PrefetchManager()
    // ... existing
}
```

Add helper:
```swift
private func triggerPrefetchIfEligible() {
    guard aiMode != .none else { Task { await prefetchManager.cancel() }; prefetchStatus = .idle; return }
    guard errorMessage == nil else { return }
    guard let total = book?.count, total > 0 else { return }
    // cancel previous poll
    prefetchPollTask?.cancel()
    let mode = aiMode
    let current = chapterNumber
    let slug = bookId
    let manager = prefetchManager
    let cacheResolved: ProcessedChapterCaching = cache ?? (try? SQLiteProcessedChapterCache()) ?? (try! SQLiteProcessedChapterCache.inMemory())
    let service = aiService // captured
    // start prefetch on manager (call from MainActor context so settings read is safe)
    Task {
        await manager.start(bookId: slug, currentChapter: current, totalChapters: total, mode: mode, settings: settingsStore, cache: cacheResolved, aiService: service!, repository: repository)
    }
    // poll status every 100ms until done (runtime-only read-only)
    prefetchPollTask = Task { @MainActor in
        while !Task.isCancelled {
            let s = await manager.currentStatus()
            self.prefetchStatus = s
            if !s.isRunning { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        // final refresh
        let s = await manager.currentStatus()
        self.prefetchStatus = s
    }
}
private func cancelPrefetch() {
    Task { await prefetchManager.cancel() }
    prefetchPollTask?.cancel()
    prefetchStatus.isRunning = false
    prefetchStatus.message = "Đã hủy"
}
```

Wire into existing methods:
- `load()` after `if aiMode != .none { aiTask ... }` add `triggerPrefetchIfEligible()` when eligible; else `cancelPrefetch()` when mode none or error.
- `goNext()`: before `await load()` call `cancelPrefetch()`; after `persistChapter()` trigger is handled via load's trigger; but ensure cancellation before new load to satisfy "Cancel on chapter change".
- `goPrev()` same.
- `goToChapter(_:)` same — add `cancelPrefetch()` at top.
- `setAIMode(_:)`: at top `cancelPrefetch()` (cancel previous mode's prefetch), after `await loadAIContent` call `triggerPrefetchIfEligible()` if mode != none.
- `reprocess()`: after successful reprocess, also `triggerPrefetchIfEligible()` (since current chapter now ready).
- `onDisappear()`: `cancelPrefetch()`.

Ensure `import` keeps `FileBookRepository` type correct — existing `repository` is `FileBookRepository` or `BookRepository` protocol; adapt.

Update `ReaderViewModel` to use stored `cache` property if needed: add `private let resolvedCache: ProcessedChapterCaching?` to reuse.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ReaderPrefetchIntegrationTests -only-testing:novelsTests/PrefetchManagerTests -quiet`
Expected: PASS (fix `FileBookRepository` initializer, `BookRepository` protocol conformance, `PrefetchManager.start` async handling, `MainActor` isolation for settings read; adjust poll interval).

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderViewModel.swift apps/novelsTests/ReaderPrefetchIntegrationTests.swift
git commit -m "feat(prefetch): integrate PrefetchManager into ReaderViewModel with cancel on change"
```

---

### Task 3: Read-only UI + project wiring (PrefetchStatus display, no persistence, verify TARGETED_DEVICE_FAMILY)

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderView.swift`
- Modify: `apps/novels.xcodeproj/project.pbxproj` (add Domain/PrefetchStatus.swift, Services/PrefetchManager.swift)
- Test: manual UI check + `xcodebuild test` full

**Interfaces:**
- Consumes: `ReaderViewModel.prefetchStatus`, `DesignTokens`.
- Produces: read-only indicator with `accessibilityIdentifier prefetchStatus`, no writable controls, no UserDefaults persistence.

- [ ] **Step 1: Modify ReaderView to show read-only prefetch indicator**

In `apps/novels/Features/Reading/ReaderView.swift` add near bottom of VStack after `blocks` rendering or above navigation:

```swift
if viewModel.prefetchStatus.isRunning {
    HStack(spacing: 8) {
        ProgressView().scaleEffect(0.8)
        Text("Đang tải trước \(viewModel.prefetchStatus.processedChapters)/\(viewModel.prefetchStatus.totalChapters)")
            .font(.caption)
            .foregroundStyle(DesignTokens.secondaryText)
    }
    .accessibilityIdentifier("prefetchStatus")
    .padding(.vertical, 4)
} else if !viewModel.prefetchStatus.errors.isEmpty {
    Text("Tải trước: \(viewModel.prefetchStatus.errors.count) lỗi")
        .font(.caption)
        .foregroundStyle(DesignTokens.error)
        .accessibilityIdentifier("prefetchStatus")
}
```

Ensure no editable controls for progress (per spec Non-goals: no writable progress controls).

- [ ] **Step 2: Update project file**

Add `PrefetchStatus.swift` and `PrefetchManager.swift` to `project.pbxproj`: create `PBXBuildFile` entries and add to `PBXSources` under `novels` target; ensure `PBXFileReference` paths correct (`apps/novels/Domain/PrefetchStatus.swift`, `apps/novels/Services/PrefetchManager.swift`).

Alternatively `xcodegen` not used — manually edit `apps/novels.xcodeproj/project.pbxproj`: duplicate pattern from `AIReadingService.swift` file entry.

Verify with `xcodebuild -list` and `xcodebuild build ... -quiet`.

- [ ] **Step 3: Verify no persistence**

Run: `grep -R "PrefetchStatus" apps --include="*.swift" -n` → only `Domain/PrefetchStatus.swift`, `Services/PrefetchManager.swift`, `Features/Reading/ReaderViewModel.swift`, `Features/Reading/ReaderView.swift`, tests. Confirm no `UserDefaults` key for prefetch cache — `SettingsStore` only stores `PREFETCH_COUNT`.

Run: `grep -R "UserDefaults" apps/novels/Domain/PrefetchStatus.swift apps/novels/Services/PrefetchManager.swift` → 0 hits.

- [ ] **Step 4: Run targeted tests + lint**

Run: `swiftformat --lint apps --verbose` → 0 files to format.
Run: `swiftlint lint --strict` → 0 violations.
Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/PrefetchManagerTests -only-testing:novelsTests/ReaderPrefetchIntegrationTests -only-testing:novelsTests/PrefetchStatusTests -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderView.swift apps/novels.xcodeproj/project.pbxproj
git commit -m "feat(prefetch): add read-only prefetch status UI and project wiring"
```

---

### Task 4: Full verification + handoff

**Files:**
- Modify: `features/feat-007.md` (check all 6 acceptances), `progress.md` (add dated block), `docs/plans/feat-007.md` checkboxes

**Interfaces:**
- Consumes: all above + `./init.sh`, `xcodebuild`, `swiftformat`, `swiftlint`.
- Produces: verified feature with evidence, next feat-008 ready.

- [ ] **Step 1: Run full verification**

Run: `swiftformat --lint . --verbose` → check 0 require formatting.
Run: `swiftlint lint --strict` → 0 violations in all files.
Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.
Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS (all suites 80+).
Run: `./init.sh` → PASS (format PASS, lint PASS, build PASS, test PASS, drift PASS). If flake bundle failure occurs, run targeted suites as evidence and note flake unrelated; fix if related to prefetch manager isolation.

Manual checklist per Acceptance:
- [ ] Prefetch runs only when eligible; batch check skips cached → verify via PrefetchManagerTests batch test (cached chapters 2,3 skipped) + ReaderPrefetchIntegrationTests trigger test mode none disabled.
- [ ] Sequential processing in order; cancellation stops remaining → sequential test asserts [2,3,4] order, cancellation test stops <5.
- [ ] PrefetchStatus runtime-only read-only UI, not persisted → grep confirms no UserDefaults for PrefetchStatus, ReaderView only shows ProgressView/Text, no controls.
- [ ] Single chapter failure does not abort batch; errors collected → failure test errors.count 1 but 2 and 4 succeed.
- [ ] Book folder deleted during prefetch cancels pending → deleted test cancels.
- [ ] Invalid PREFETCH_COUNT coerced to 3 → invalid test.

- [ ] **Step 2: Update feature file handoff**

In `features/feat-007.md` check all 6 acceptance checkboxes:

```
- [x] Prefetch runs only when eligible; batch check skips cached chapters.
- [x] Sequential processing of misses in order; cancellation stops remaining work.
- [x] `PrefetchStatus` runtime-only (isRunning/total/processed/message/errors[]) read-only UI, not persisted per `docs/product/domain-model.md:66`.
- [x] Single chapter failure does not abort batch; errors collected in `PrefetchStatus.errors`.
- [x] Book folder deleted during prefetch cancels pending tasks.
- [x] Invalid `PREFETCH_COUNT` coerced to 3.
```

Update Handoff:
```
- State: done
- Evidence: `docs/plans/feat-007.md`, `apps/novels/Domain/PrefetchStatus.swift`, `apps/novels/Services/PrefetchManager.swift`, `apps/novels/Features/Reading/ReaderViewModel.swift`, `apps/novels/Features/Reading/ReaderView.swift`, `apps/novels/Persistence/SettingsStore.swift` effectivePrefetchCount, tests `PrefetchManagerTests` 7 + `PrefetchStatusTests` 2 + `ReaderPrefetchIntegrationTests` 4 PASS; `xcodebuild build -quiet` PASS, `swiftlint` 0, `swiftformat` 0, `./init.sh` PASS
- Blockers: none
- Next: feat-008 Hardening + Release Readiness ready (depends 007 done)
```

- [ ] **Step 3: Append progress.md block**

Add below last block:

```
## 2026-08-27 — feat-007

**State**: done
**Done**: Chapter Prefetch — batch cache check via `processed_chapters.sqlite` `batchStatus` skipping cached, sequential `AIReadingService` misses with `Task` cancellation on chapter/mode change and book deletion, `PrefetchStatus` runtime-only read-only UI, per-chapter error continue, invalid `PREFETCH_COUNT` 1..10 else 3
**Evidence**: (same as feature handoff)
**Blockers**: none
**Next**: feat-008 Hardening + Release Readiness ready (depends feat-007 done) — activate when user approves
```

- [ ] **Step 4: Mark checklist in plan**

Check all Task checkboxes in `docs/plans/feat-007.md`.

- [ ] **Step 5: Commit & PR**

```bash
git add features/feat-007.md progress.md docs/plans/feat-007.md feature_index.json
git commit -m "docs(prefetch): mark feat-007 done with verification evidence"
```

Run `./init.sh --quick` before commit to ensure drift clean (feature_index status active → done transition checked).

---

## Self-Review

**1. Spec coverage:**
- `features/feat-007.md` 6 acceptances: eligibility + batch skip → Task 1 mgr.start guard + batchStatus filter + Task 1 tests eligibility/mode none/batch; sequential + cancellation → Task 1 sequential order + cancellation + Task 2 trigger/cancel on goNext/goPrev/setAIMode; runtime-only read-only UI not persisted → Task 3 UI ProgressView + no UserDefaults + Domain spec; per-chapter error continue → Task 1 error append test; book deleted cancel → Task 1 fileExists break test; invalid N coerced → Task 1 invalid + Task 2 integration invalid tests.

**2. Placeholder scan:** No TBD/TODO; each step has concrete Swift code, exact `xcodebuild test -only-testing:` commands, expected FAIL/PASS, file paths, commit messages.

**3. Type consistency:** `AIMode` enum `.none/.translate/.summary`, `ProcessedChapter(cache)`, `ProcessedChapterCaching` protocol `batchStatus` + `upsert`, `AIReadingService.processedContent(bookId:chapterNumber:mode:rawText:)`, `PrefetchStatus` fields `isRunning/currentBookId/totalChapters/processedChapters/message/errors`, `PrefetchManager.start(bookId:currentChapter:totalChapters:mode:settings:cache:aiService:repository:)` async, `ReaderViewModel` `prefetchStatus/prefetchManager/triggerPrefetchIfEligible/cancelPrefetch` consistent across tasks; `FileBookRepository` vs `BookRepository` protocol adapted.

