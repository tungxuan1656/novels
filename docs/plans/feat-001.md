# Native Persistence Foundation Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the native Swift persistence foundation (FileManager+Codable books, SQLite processed_chapters cache, UserDefaults @Observable settings with slug identity) behind testable boundaries for later features.

**Architecture:** Three isolated stores under Application Support/UserDefaults per `docs/decisions/local-persistence.md` + `book-identity.md` and `ARCHITECTURE.md` §1-2. Domain/Codable types are pure Swift; repositories are protocol/actor-gated; single SQLite cache with PRIMARY KEY (book_id, chapter_number, mode); current-keys-only settings; strict ZIP root validation.

**Tech Stack:** Swift 5.0 / SwiftUI stub intact, Xcode 26.5 scheme `novels`, `Foundation.FileManager` + `Codable` + `FileManager.unzipItem`, `Foundation.UserDefaults` + `Observation.@Observable`, system `libsqlite3` (no Swift package) via `import SQLite3`, `CryptoKit` for `SHA256.hex` (`ProcessedChapter.contentHash`), `WebKit` not touched in this feature, `XCTest`/`XCUITest`, `URLSession` not wired in this feature.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — product intent; `TARGETED_DEVICE_FAMILY` and `IPHONEOS_DEPLOYMENT_TARGET` unchanged in this feature.
- `DEVELOPMENT_TEAM M5U4E4H84J`, Swift 5.0, single module `apps/novels` today; first test target added here.
- No SwiftPM dependencies; no `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, second AI cache, RN packages, or RN data/settings/cache migration.
- `book.json.id` is string slug local identity; remote `ExportedBook.id`/`bookId` are numbers metadata only — no coercion.
- `book.json.count` is number; `references.length == count`; chapters 1-based; ZIP exact root `book.json` + `chapters/chapter-N.html`.
- Settings current keys only with defaults: `OPENAI_MODEL=gpt-4o`, `PREFETCH_COUNT=3` (1..10 else 3), `AI_MIN_CHUNK_SIZE=1300`, `AI_PROVIDER=openai` (unknown→openai), `BOOKS_API_URL=https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books`, `OPENAI_API_URL=http://localhost:8317/v1/chat/completions`; invalid `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` JSON ignored; unknown/legacy ignored.
- SQLite `processed_chapters` single cache: `PRIMARY KEY (book_id, chapter_number, mode)` / `UNIQUE(book_id, chapter_number, mode)`, index on `book_id`, `mode != "none"` never stored, upsert semantics.
- Real secrets never appear in docs/examples; `AI_CUSTOM_HEADERS` normal UserDefaults storage.
- Test-first, persistence isolation via temp Application Support / in-memory SQLite, no change to `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip`.

---

### Task 1: Create both test targets and fixtures

**Files:**
- Create: `apps/novelsTests/Fixtures/book.json` (planned — valid sample with `"id":"test-slug","name":"Test","count":2,"author":"A","references":["Ch 1","Ch 2"]`)
- Create: `apps/novelsTests/Fixtures/chapters/chapter-1.html` (planned)
- Create: `apps/novelsTests/Fixtures/chapters/chapter-2.html` (planned)
- Create: `apps/novelsTests/Fixtures/wrapper-invalid.zip` (planned — outer folder + `__MACOSX` shape mirroring docs/samples for rejection test; generated in-test, not the real sample)
- Create: `apps/novelsTests/Fixtures/invalid-missing-bookjson.zip` (planned — missing root `book.json`)
- Create: `apps/novelsUITests/LaunchSmokeTests.swift` (planned — `XCUITest` launch smoke test, see Step 3b)
- Modify: `apps/novels.xcodeproj/project.pbxproj` — add two `PBXNativeTarget`s: `novelsTests` at `apps/novelsTests/` (unit `XCTest`, bundle id `com.tungxuan.novels.tests`, `TEST_HOST=$(BUILT_PRODUCTS_DIR)/novels.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/novels`, `Info.plist` at `apps/novelsTests/Info.plist`) and `novelsUITests` at `apps/novelsUITests/` (UI `XCTest`, bundle id `com.tungxuan.novels.uitests`, `TEST_TARGET_NAME=novels`, `Info.plist` at `apps/novelsUITests/Info.plist`) (planned)

**Interfaces:**
- Consumes: none
- Produces: `novelsTests` host bundle `com.tungxuan.novels.tests` and `novelsUITests` host bundle `com.tungxuan.novels.uitests`; fixture helper `FixtureLoader.rootURL() -> URL` returning fixture directory URL (used by Tasks 2-3); `LaunchSmokeTests.testAppLaunches()` (XCUITest) for UI smoke; spec that unit tests use `FileManager.temporaryDirectory` for isolation.

- [ ] **Step 1: Add both test target skeletons (planned paths)**

Add `novelsTests` at `apps/novelsTests/` as `XCTest` unit target with `INFOPLIST_FILE=apps/novelsTests/Info.plist`, `PRODUCT_BUNDLE_IDENTIFIER=com.tungxuan.novels.tests`, `TEST_HOST=$(BUILT_PRODUCTS_DIR)/novels.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/novels`, `BUNDLE_LOADER=$(TEST_HOST)`. Add `novelsUITests` at `apps/novelsUITests/` as `XCTest` UI target with `INFOPLIST_FILE=apps/novelsUITests/Info.plist`, `PRODUCT_BUNDLE_IDENTIFIER=com.tungxuan.novels.uitests`, `TEST_TARGET_NAME=novels`. Do not edit `TARGETED_DEVICE_FAMILY`.

- [ ] **Step 2: Create fixture files (planned)**

Write `apps/novelsTests/Fixtures/book.json` with `{"id":"test-slug","name":"Test","count":2,"author":"A","references":["Ch 1","Ch 2"]}` and two HTML files with distinct content. Keep `apps/novelsTests/Fixtures/` under the test target.

- [ ] **Step 3: Write failing tests for fixture load and UI smoke**

```swift
// apps/novelsTests/FixtureTests.swift (planned)
import XCTest
final class FixtureTests: XCTestCase {
  func testFixturesExist() throws {
    let url = Bundle(for: Self.self).resourceURL!.appendingPathComponent("Fixtures/book.json")
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
  }
}
// apps/novelsUITests/LaunchSmokeTests.swift (planned)
import XCTest
final class LaunchSmokeTests: XCTestCase {
  func testAppLaunches() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
  }
}
```

- [ ] **Step 4: Run tests to verify they fail (before targets exist)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: FAIL — no test targets / no bundle resources.

- [ ] **Step 5: Implement minimal fix — wire fixtures and UI test and make tests pass**

Add `apps/novelsTests/FixtureTests.swift` and fixtures to `novelsTests` target's `Sources`/`Resources`; add `apps/novelsUITests/LaunchSmokeTests.swift` to `novelsUITests` target.

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/FixtureTests`
Expected: PASS `FixtureTests`.
Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsUITests/LaunchSmokeTests`
Expected: PASS `LaunchSmokeTests.testAppLaunches`.

- [ ] **Step 7: Record handoff for Task 1**

Changed paths (planned): `apps/novels.xcodeproj/project.pbxproj`, `apps/novelsTests/Info.plist`, `apps/novelsTests/FixtureTests.swift`, `apps/novelsTests/Fixtures/book.json`, `apps/novelsTests/Fixtures/chapters/chapter-1.html`, `apps/novelsTests/Fixtures/chapters/chapter-2.html`, `apps/novelsUITests/Info.plist`, `apps/novelsUITests/LaunchSmokeTests.swift`. Verify both bundle ids `com.tungxuan.novels.tests` and `com.tungxuan.novels.uitests` appear in `project.pbxproj`.

**Handoff dependency:** Tasks 2-5 consume `FixtureLoader`/`novelsTests` target and `novelsUITests` launch smoke.

---

### Task 2: Define pure Swift domain/Codable types

**Files:**
- Create: `apps/novels/Domain/Book.swift` (planned — `struct Book: Codable, Equatable { let id: String; let name: String; let author: String?; let count: Int; let references: [String] }`)
- Create: `apps/novels/Domain/Reference.swift` (planned — `typealias Reference = String` because `book.json` stores references as strings per `docs/contracts/book-package.md`; keep `Book.references` as `[String]`)
- Create: `apps/novels/Domain/Chapter.swift` (planned — `struct Chapter { let bookId: String; let number: Int; let html: String }`)
- Create: `apps/novels/Domain/ProcessedChapter.swift` (planned — `struct ProcessedChapter: Equatable { let bookId: String; let chapterNumber: Int; let mode: AIMode; let content: String; let contentHash: String; let createdAt: Date; let updatedAt: Date }` where `contentHash` is SHA256 via `CryptoKit`)
- Create: `apps/novels/Domain/AIMode.swift` (planned — `enum AIMode: String, Codable { case none, translate, summary }`)
- Create: `apps/novels/Domain/ReadingSession.swift` (planned — `struct ReadingSession: Codable { var bookId: String; var onScreen: Bool; var offset: Double; var chapterNumber: Int }`)
- Create: `apps/novels/Domain/TypographySetting.swift` (planned — `struct TypographySetting: Codable`)
- Create: `apps/novels/Domain/SettingsModels.swift` (planned — `struct AIAction: Codable { let key: String; let name: String; let prompt: String }`)
- Create: `apps/novels/Domain/SHA256.swift` (planned — `enum SHA256 { static func hex(_ string: String) -> String }` via `import CryptoKit` `SHA256.hash(data:)`)
- Test: `apps/novelsTests/DomainCodableTests.swift` (planned)

**Interfaces:**
- Consumes: fixture `book.json` from Task 1; `CryptoKit` for hashing.
- Produces: `Book.decode(from:) throws -> Book`, `SHA256.hex(_:) -> String` (`CryptoKit.SHA256`), `ProcessedChapter.contentHash` (SHA256 hex), `AIMode` rawValue, `typealias Reference = String`, all types used by Tasks 3-5.

- [ ] **Step 1: Write failing Codable round-trip test**

```swift
func testBookCodableRoundTrip() throws {
  let json = #"{"id":"test-slug","name":"Test","count":2,"author":"A","references":["Ch 1","Ch 2"]}"#
  let data = json.data(using: .utf8)!
  let book = try JSONDecoder().decode(Book.self, from: data)
  XCTAssertEqual(book.id, "test-slug")
  XCTAssertEqual(book.count, 2)
  XCTAssertEqual(book.references.count, 2)
  let encoded = try JSONEncoder().encode(book)
  let decoded2 = try JSONDecoder().decode(Book.self, from: encoded)
  XCTAssertEqual(decoded2, book)
}
```

- [ ] **Step 2: Run test — expect FAIL (types undefined)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/DomainCodableTests`
Expected: FAIL compile error `cannot find type 'Book'`.

- [ ] **Step 3: Implement minimal types**

Add `apps/novels/Domain/*.swift` with `Book` `id: String` (slug) and `count: Int`, `AIMode`, etc. `Book` decodes `id` as String only — no numeric coercion.

- [ ] **Step 4: Run test — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/DomainCodableTests`
Expected: PASS.

- [ ] **Step 5: Write ProcessedChapter hash and none-reject test (CryptoKit)**

```swift
import CryptoKit // planned import for SHA256.hex in Domain
func testProcessedChapterHashStable() {
  let a = ProcessedChapter(bookId: "s", chapterNumber: 1, mode: .translate, content: "hi", contentHash: SHA256.hex("hi"), createdAt: Date(), updatedAt: Date())
  XCTAssertEqual(a.contentHash, SHA256.hex("hi"))
}
```

- [ ] **Step 6: Run and record handoff for Task 2**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/DomainCodableTests`
Expected: PASS after adding `CryptoKit` hash helper.

Changed paths (planned): `apps/novels/Domain/Book.swift`, `apps/novels/Domain/Reference.swift` (`typealias Reference = String`), `apps/novels/Domain/Chapter.swift`, `apps/novels/Domain/ProcessedChapter.swift`, `apps/novels/Domain/AIMode.swift`, `apps/novels/Domain/ReadingSession.swift`, `apps/novels/Domain/TypographySetting.swift`, `apps/novels/Domain/SettingsModels.swift`, `apps/novels/Domain/SHA256.swift` (`import CryptoKit`), `apps/novelsTests/DomainCodableTests.swift`.

**Handoff dependency:** Tasks 3 and 4 import `Book`/`ProcessedChapter`/`AIMode`.

---

### Task 3: Application Support paths and FileManager+Codable book repository

**Files:**
- Create: `apps/novels/Persistence/Paths.swift` (planned — `enum AppPaths { static func booksRoot(fileManager: FileManager) -> URL; static func cacheRoot(fileManager: FileManager) -> URL }`)
- Create: `apps/novels/Persistence/BookRepository.swift` (planned — `protocol BookRepository { func listBooks() throws -> [Book]; func book(slug: String) throws -> Book?; func chapterHTML(slug: String, number: Int) throws -> String; func save(validatedRoot: URL, slug: String) throws; func deleteBook(slug: String) throws }` + `struct FileBookRepository: BookRepository`)
- Create: `apps/novels/Persistence/ZipValidator.swift` (planned — `enum ZipValidator { static func isValidRoot(at extractedURL: URL) -> Bool }`)
- Test: `apps/novelsTests/BookRepositoryTests.swift` (planned)

**Interfaces:**
- Consumes: `Book` from Task 2, `FileManager`, `Codable`.
- Produces: `FileBookRepository.init(root: URL, fileManager: FileManager)` and methods above; `AppPaths` consumed by Task 4 for cache path.

- [ ] **Step 1: Write failing repository isolation test**

```swift
func testListSkipsInvalidFolder() throws {
  let fm = FileManager.default
  let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try fm.createDirectory(at: tmp.appendingPathComponent("books/valid-slug/chapters"), withIntermediateDirectories: true)
  try #"{"id":"valid-slug","name":"V","count":1,"author":null,"references":["C1"]}"#.write(to: tmp.appendingPathComponent("books/valid-slug/book.json"), atomically: true, encoding: .utf8)
  try "<html>c1</html>".write(to: tmp.appendingPathComponent("books/valid-slug/chapters/chapter-1.html"), atomically: true, encoding: .utf8)
  try fm.createDirectory(at: tmp.appendingPathComponent("books/bad/chapters"), withIntermediateDirectories: true)
  let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: fm)
  XCTAssertEqual(try repo.listBooks().map(\.id), ["valid-slug"])
}
```

- [ ] **Step 2: Run — expect FAIL (no repo)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/BookRepositoryTests`
Expected: FAIL compile.

- [ ] **Step 3: Implement Paths and FileBookRepository**

Implement `AppPaths.booksRoot` returning `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("novels/books", isDirectory: true)` (injected `fileManager` for tests). Implement `listBooks()` scanning `root`, decoding `book.json` via `Codable`, skipping folders where `book.json` missing or `count != references.count` or `chapters/chapter-N.html` missing; `chapterHTML` validates `1 <= number <= book.count`; `save` uses `write(to:atomically:true)`; `deleteBook` removes `root/<slug>` atomically; `ZipValidator.isValidRoot` checks `book.json` at `extractedURL` root and `chapters/chapter-1..count` existence, rejecting outer-folder/`__MACOSX` wrappers.

- [ ] **Step 4: Write validation rejection test for wrapper**

```swift
func testValidatorRejectsWrapper() throws {
  let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: tmp.appendingPathComponent("outer/chapters"), withIntermediateDirectories: true)
  XCTAssertFalse(ZipValidator.isValidRoot(at: tmp))
  XCTAssertFalse(ZipValidator.isValidRoot(at: tmp.appendingPathComponent("outer")))
}
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/BookRepositoryTests`
Expected: PASS both tests, invalid folder skipped, wrapper rejected, atomic delete removes only slug.

- [ ] **Step 6: Record handoff for Task 3**

Changed paths (planned): `apps/novels/Persistence/Paths.swift`, `apps/novels/Persistence/BookRepository.swift`, `apps/novels/Persistence/ZipValidator.swift`, `apps/novelsTests/BookRepositoryTests.swift`. Verify isolation via `FileManager.temporaryDirectory`.

**Handoff dependency:** Task 5 integration test uses repository; Task 4 uses `AppPaths`.

---

### Task 4: SQLite processed_chapters cache behind protocol/actor

**Files:**
- Create: `apps/novels/Persistence/ProcessedChapterCache.swift` (planned — `protocol ProcessedChapterCaching { func get(bookId: String, chapterNumber: Int, mode: AIMode) throws -> ProcessedChapter?; func batchStatus(bookId: String, mode: AIMode, numbers: [Int]) throws -> Set<Int>; func upsert(_ pc: ProcessedChapter) throws; func clearAll() throws; func clear(bookId: String) throws }` + `actor ProcessedChapterStore` + `struct SQLiteProcessedChapterCache: ProcessedChapterCaching`)
- Create: `apps/novels/Persistence/SQLiteSupport.swift` (planned — `user_version` migration helper, `sqlite3_open`, `sqlite3_exec` wrappers)
- Test: `apps/novelsTests/ProcessedChapterCacheTests.swift` (planned)

**Interfaces:**
- Consumes: `ProcessedChapter`, `AIMode` from Task 2, `AppPaths.cacheRoot` from Task 3.
- Produces: `ProcessedChapterCaching` for later AI/prefetch; `cache.dbURL` at `Application Support/novels/cache/processed_chapters.sqlite`.

- [ ] **Step 1: Write failing cache hit test (in-memory DB)**

```swift
func testCacheHitAndBatch() throws {
  let cache = try SQLiteProcessedChapterCache.inMemory()
  let pc = ProcessedChapter(bookId: "test-slug", chapterNumber: 1, mode: .translate, content: "<p>hi</p>", contentHash: SHA256.hex("<p>hi</p>"), createdAt: Date(), updatedAt: Date())
  try cache.upsert(pc)
  XCTAssertNotNil(try cache.get(bookId: "test-slug", chapterNumber: 1, mode: .translate))
  XCTAssertNil(try cache.get(bookId: "test-slug", chapterNumber: 1, mode: .summary))
  XCTAssertEqual(try cache.batchStatus(bookId: "test-slug", mode: .translate, numbers: [1,2]), [1])
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ProcessedChapterCacheTests`
Expected: FAIL no type.

- [ ] **Step 3: Implement SQLite schema (planned code)**

Execute `CREATE TABLE IF NOT EXISTS processed_chapters (book_id TEXT NOT NULL, chapter_number INTEGER NOT NULL, mode TEXT NOT NULL, content TEXT NOT NULL, content_hash TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY (book_id, chapter_number, mode)) WITHOUT ROWID; CREATE INDEX IF NOT EXISTS idx_processed_chapters_book ON processed_chapters(book_id); PRAGMA user_version=1;` via `SQLiteSupport`. Upsert via `INSERT OR REPLACE INTO processed_chapters VALUES (?,?,?,?,?,?,?)` (or `ON CONFLICT DO UPDATE`). Guard: `guard mode != .none else { return }` — never write `none`. Wrap all ops in actor `ProcessedChapterStore` to dedupe single-flight later.

```swift
func upsert(_ pc: ProcessedChapter) throws {
  guard pc.mode != .none else { return }
  // INSERT OR REPLACE ...
}
```

- [ ] **Step 4: Write remaining cache semantics tests**

```swift
func testUpsertOverwrites() throws {
  let c = try SQLiteProcessedChapterCache.inMemory()
  var a = ProcessedChapter(bookId: "s", chapterNumber: 1, mode: .translate, content: "a", contentHash: "a", createdAt: Date(), updatedAt: Date())
  try c.upsert(a); a = ProcessedChapter(bookId: "s", chapterNumber: 1, mode: .translate, content: "b", contentHash: "b", createdAt: Date(), updatedAt: Date())
  try c.upsert(a)
  XCTAssertEqual(try c.get(bookId: "s", chapterNumber: 1, mode: .translate)?.content, "b")
}
func testClear() throws {
  let c = try SQLiteProcessedChapterCache.inMemory()
  try c.upsert(.init(bookId: "s", chapterNumber: 1, mode: .summary, content: "x", contentHash: "x", createdAt: Date(), updatedAt: Date()))
  try c.clear(bookId: "s")
  XCTAssertNil(try c.get(bookId: "s", chapterNumber: 1, mode: .summary))
}
func testNoneNeverWritten() throws {
  let c = try SQLiteProcessedChapterCache.inMemory()
  try c.upsert(.init(bookId: "s", chapterNumber: 1, mode: .none, content: "x", contentHash: "x", createdAt: Date(), updatedAt: Date()))
  XCTAssertNil(try c.get(bookId: "s", chapterNumber: 1, mode: .none))
}
```

- [ ] **Step 5: Run — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ProcessedChapterCacheTests`
Expected: PASS hit, batch, upsert, clear-all, clear-by-book, none-reject, identity (slug) not numeric.

- [ ] **Step 6: Record handoff for Task 4**

Changed paths (planned): `apps/novels/Persistence/ProcessedChapterCache.swift`, `apps/novels/Persistence/SQLiteSupport.swift`, `apps/novelsTests/ProcessedChapterCacheTests.swift`. Verify slug identity and `mode != "none"` rejection.

**Handoff dependency:** Later AI/prefetch will `actor` dedupe via `ProcessedChapterStore`.

---

### Task 5: Current-key-only settings/session/typography via UserDefaults @Observable

**Files:**
- Create: `apps/novels/Persistence/SettingsStore.swift` (planned — `@Observable final class SettingsStore { var booksAPIURL: String; var openaiAPIURL: String; var openaiModel: String; var aiCustomHeadersJSON: String; var aiExtraBodyJSON: String; var aiProvider: String; var aiProcessActionsJSON: String; var aiMinChunkSize: Int; var prefetchCount: Int; var typography: TypographySetting; var session: ReadingSession?; func load(); func sanitize(); func save(); }`)
- Create: `apps/novels/Persistence/DefaultsKeys.swift` (planned — `enum DefaultsKeys { static let booksAPIURL = "BOOKS_API_URL"; ... ; static let allCurrent: [String] }`)
- Test: `apps/novelsTests/SettingsStoreTests.swift` (planned)

**Interfaces:**
- Consumes: `ReadingSession`, `TypographySetting`, `AIAction` from Task 2, `UserDefaults`.
- Produces: `SettingsStore.shared` observable used by startup/settings UI later; sanitize behavior for BR-12.

- [ ] **Step 1: Write failing defaults and invalid JSON test**

```swift
func testDefaultsAndInvalidJSONIgnored() {
  let ud = UserDefaults(suiteName: UUID().uuidString)!
  let s = SettingsStore(userDefaults: ud)
  s.load()
  XCTAssertEqual(s.openaiModel, "gpt-4o")
  XCTAssertEqual(s.prefetchCount, 3)
  s.aiCustomHeadersJSON = "{bad"
  s.sanitize()
  XCTAssertEqual(s.aiCustomHeadersJSON, "{bad}") // stored verbatim
  // request merge would ignore invalid; store keeps raw but caller treats as empty
  XCTAssertTrue(s.effectiveHeaders().isEmpty)
  XCTAssertTrue(s.effectiveExtraBody().isEmpty)
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/SettingsStoreTests`
Expected: FAIL no store.

- [ ] **Step 3: Implement SettingsStore (planned skeleton)**

Store current keys only per `docs/contracts/settings-schema.md`. `load()` reads `UserDefaults` or defaults: `BOOKS_API_URL=https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books`, `OPENAI_API_URL=http://localhost:8317/v1/chat/completions`, `gpt-4o`, `3`, `1300`, `openai`. `sanitize()` coerces `prefetchCount` 1..10 else 3, `aiMinChunkSize` else 1300, `aiProvider` case-insensitive else `openai`, `aiProcessActionsJSON` must decode `[AIAction]` with `key` in `translate`/`summary` else reset to defaults JSON; `aiCustomHeadersJSON`/`aiExtraBodyJSON` if non-empty and not valid JSON object → `effectiveHeaders()`/`effectiveExtraBody()` return `[:]` (ignored). Unknown keys in `UserDefaults` never read — `allCurrent` allowlist. No legacy migration.

```swift
func effectiveHeaders() -> [String:String] {
  guard let data = aiCustomHeadersJSON.data(using: .utf8),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String:String] else { return [:] }
  return obj
}
```

- [ ] **Step 4: Write unknown-key ignore test**

```swift
func testUnknownLegacyIgnored() {
  let ud = UserDefaults(suiteName: UUID().uuidString)!
  ud.set("foo", forKey: "COPILOT_API_KEY")
  ud.set("123", forKey: "BOOKS_API_URL")
  let s = SettingsStore(userDefaults: ud)
  s.load(); s.sanitize()
  XCTAssertEqual(s.booksAPIURL, "123")
  // legacy key remains in UD but never influences store
  XCTAssertEqual(ud.string(forKey: "COPILOT_API_KEY"), "foo")
  XCTAssertEqual(s.prefetchCount, 3)
}
```

- [ ] **Step 5: Run — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/SettingsStoreTests`
Expected: PASS defaults, invalid JSON ignored, unknown/legacy ignored, `UserDefaults` isolated via suite.

- [ ] **Step 6: Record handoff for Task 5**

Changed paths (planned): `apps/novels/Persistence/SettingsStore.swift`, `apps/novels/Persistence/DefaultsKeys.swift`, `apps/novelsTests/SettingsStoreTests.swift`. After `s.aiCustomHeadersJSON = "{bad"` stored remains exactly `"{bad"` and only `effectiveHeaders()` returns empty; unknown/legacy ignored.

**Handoff dependency:** Startup flow will call `SettingsStore.load()+sanitize()` on launch.

---

### Task 6: Verification, isolation, and handoff

**Files:**
- Modify: `features/feat-001.md` — fill Evidence with test file paths and commands (planned)
- Modify: `progress.md` — add done block (planned, but actually keep todo until orchestrator marks)
- Test: all `apps/novelsTests/*` (planned)

**Interfaces:**
- Consumes: Tasks 1-5 outputs.
- Produces: green `xcodebuild test`, persistence isolation proof, cache identity proof.

- [ ] **Step 1: Run full unit and UI suites isolated**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS all — `DomainCodableTests`, `BookRepositoryTests`, `ProcessedChapterCacheTests`, `SettingsStoreTests`, `FixtureTests` (novelsTests) and `LaunchSmokeTests.testAppLaunches` (novelsUITests) with no access to real `Application Support/novels`.

- [ ] **Step 2: Run build verification**

Run: `./init.sh`
Expected: PASS — format SKIP, lint SKIP, build PASS, test PASS (after `init.sh` updated to include `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`).

- [ ] **Step 3: Verify non-goals — grep for forbidden imports**

Run: `grep -R "SwiftData\|Core Data\|import.*RN\|Keychain\|BGTaskScheduler" --include="*.swift" apps`
Expected: no output.

- [ ] **Step 4: Update feature handoff (after Task 1-5 actually done)**

Update `features/feat-001.md` Evidence with exact paths: `apps/novels/Domain/*`, `apps/novels/Persistence/*`, `apps/novelsTests/*`, `apps/novels.xcodeproj/project.pbxproj`. Keep State `todo` until user approves activation; do not mark `done`/`active` here.

- [ ] **Step 5: Record final handoff**

Changed paths (planned): `features/feat-001.md` Evidence section. Verify both targets `novelsTests` (`apps/novelsTests/`) and `novelsUITests` (`apps/novelsUITests/`) ran and `CryptoKit` import exists in `SHA256.swift`.

**Rollback:** If SQLite migration version bumps, add `PRAGMA user_version` migration in `SQLiteSupport`; if test target breaks build, revert `project.pbxproj` change for that target only.

**Links:** `ARCHITECTURE.md`, `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`, `docs/contracts/book-package.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/functional-specs/settings-management.md`

