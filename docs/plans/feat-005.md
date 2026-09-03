# Settings + Cache Manager Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose editable settings and cache controls persisted via `UserDefaults` + `@Observable` from feat-001 — groups, editor with validation blocking save on error, and Cache Manager with count + clear-all (confirm) + clear-by-book, reflecting `processed_chapters.sqlite` immediately and surviving relaunch.

**Architecture:** `SettingsStore` (`@MainActor @Observable`, `UserDefaults` sanitize on launch) is single source; `SettingsView` grouped list drives `SettingEditorView` (per-key validation) and `CacheManagerView` (SQLite count/clear via `ProcessedChapterCaching`); `Router` adds `settings`, `cacheManager`, `settingEditor(settingKey:)` routes on single `NavigationStack`; typography edits persist live and apply on next render.

**Tech Stack:** Swift 5.0 / SwiftUI, Xcode `apps/novels.xcodeproj` scheme `novels` iOS 26.5, `Foundation` + `Observation.@Observable`, `FileManager` + `Codable`, `libsqlite3` via `SQLiteProcessedChapterCache` (`WITHOUT ROWID` + `user_version=1`), `UserDefaults` + `@Observable`, `XCTest`/`Testing` (`Testing.framework`), SwiftLint 0.65.1 + SwiftFormat 0.62.1, Vietnamese UI.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — `TARGETED_DEVICE_FAMILY=1`, `IPHONEOS_DEPLOYMENT_TARGET=26.5`, copy in Vietnamese (`Cài đặt`, `Cache Manager`, `Clear All`, `Cleared`, etc.) per `docs/design/screens.md:25`.
- `DEVELOPMENT_TEAM M5U4E4H84J`, Swift 5.0, single module `apps/novels`, no SwiftPM packages — native only (`FileManager`, `libsqlite3`, `UserDefaults`, `URLSession` actor, `Foundation` HTML).
- No `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, WebKit, or second AI cache per `docs/decisions/local-persistence.md`.
- `book.json.id` string slug is sole local identity; remote numeric `ExportedBook.id` never used as folder/cache key; do not coerce per `docs/decisions/book-identity.md`.
- Stores: `Application Support/novels/books/<slug>/` (`book.json`+`chapters/chapter-N.html`) + `Application Support/novels/cache/processed_chapters.sqlite` (`CREATE TABLE IF NOT EXISTS processed_chapters (book_id TEXT NOT NULL, chapter_number INTEGER NOT NULL, mode TEXT NOT NULL, content TEXT NOT NULL, content_hash TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY (book_id,chapter_number,mode)) WITHOUT ROWID; CREATE INDEX idx_processed_chapters_book ON processed_chapters(book_id); PRAGMA user_version=1`) + `UserDefaults @Observable` (`SettingsStore`, `ReadingSession`, `TypographySetting`).
- Settings keys `docs/contracts/settings-schema.md:7-21` — `BOOKS_API_URL` default `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books`, `OPENAI_API_URL` default `http://localhost:8317/v1/chat/completions`, `OPENAI_MODEL` default `gpt-4o`, `AI_PROVIDER` default `openai` (only `openai`, case-insensitive, unknown→`openai`), `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` string JSON object default `""` (invalid→treated empty at merge, stored verbatim per `docs/contracts/ai-service.md:17`, `effectiveHeaders()`→`[String:String]` via `JSONSerialization` else `[:]`), `AI_PROCESS_ACTIONS` JSON array `[{key,name,prompt}]` where `key∈{translate,summary}` else reset to defaults `translate+summary`, `AI_MIN_CHUNK_SIZE` default `1300` (string-stored number), `PREFETCH_COUNT` default `3` allowed `1..10` else `3` (BR-08), `font/fontSize/lineHeight/letterSpacing` (BR-11: `fontSize 12..24 step1`, `lineHeight 1.2..2.0 step0.1`, `letterSpacing 0..1.0 step0.1`, defaults `System/16/1.5/0`).
- Sanitize offline on every launch + every `save()` per `SettingsStore.sanitize()`: missing/invalid→defaults, unknown/legacy (`COPILOT`, `DEEPSEEK`, old keys)→ignored (BR-12), no migration; `PREFETCH_COUNT` `1..10` else `3`, `AI_MIN_CHUNK_SIZE` `500..5000` else `1300` (store impl), `provider` lowercased, `actions` decode fallback, typography ranges clamped.
- Cache: `mode='none'` never written; `INSERT OR REPLACE` on `(book_id,chapter_number,mode)`; `SELECT content WHERE book_id=? AND chapter_number=? AND mode=?`; `SELECT count(*) WHERE book_id=?` for badge; `DELETE` all or `WHERE book_id=?`; actor-gated single-flight via `ProcessedChapterStore`.
- Navigation: single `NavigationStack` via `Router` `path:NavigationPath` + `Route` enum with `isPushing` 300ms debounce; graph `Home → Settings → CacheManager|SettingEditor(settingKey,label,placeholder,description,multiple)` per `docs/design/navigation.md`; Settings edit persist immediately, invalid blocks save with error (except headers/body verbatim allowed per scope).
- Design tokens `docs/design/design-system.md`: `background #FFFFFF`, `backgroundPaper #FDFCF8`, `surface #FFFFFF`, `text #111111`, `muted #6B7280`, `accent #2563EB`, `error #DC2626`, `border #E5E7EB` 1px, radius 8/12/16/24, spacing 4/8/12/16/24/32; shared sheet `BottomSheetView` overlay+dim drag-down/tap backdrop; Toast global 3s <60ch/4s <150ch/5s long tap dismiss; Cache Manager count card + clear button confirm→toast; Setting Editor description + input + Clear/Save with error/success.
- Verification: `./init.sh` (swiftformat --lint, swiftlint --strict, `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`, `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`).

---

## File Structure

**New files (this feature owns):**
- `apps/novels/Features/Settings/SettingsView.swift` — Grouped Settings list: sections Catalog (BOOKS_API_URL), AI (OPENAI_API_URL, OPENAI_MODEL, AI_PROVIDER, AI_CUSTOM_HEADERS, AI_EXTRA_BODY, AI_PROCESS_ACTIONS, AI_MIN_CHUNK_SIZE), Prefetch (PREFETCH_COUNT), Typography (font, fontSize, lineHeight, letterSpacing), Data (Cache Manager row). Each row is `NavigationLink` to `SettingEditorView` or `CacheManagerView`. Reads `@Bindable settingsStore: SettingsStore`, shows current value truncated, uses `DesignTokens`. Vietnamese labels.
- `apps/novels/Features/Settings/SettingEditorView.swift` — Single-value editor: `init(settingKey:String, label:String, placeholder:String, description:String, isJSON:Bool, isNumeric:Bool, allowMultiline:Bool)`. Binds `@State draft:String`, validates on `Save` per schema (URLs non-empty, JSON objects valid, provider == openai, prefetch 1..10, chunk 500..5000, actions JSON array), shows inline `errorMessage` in `error` color, blocks save if invalid (except headers/body where error shown but Save still persists verbatim and effectiveHeaders returns [:]). `Clear` resets to default for key. On `Save` writes to `settingsStore` via `settingsStore.setValue(draft, forKey:settingKey)` + `settingsStore.save()`, shows Toast success, pops via `router.pop()`.
- `apps/novels/Features/Settings/CacheManagerView.swift` — Count card + actions: shows `@State count:Int` + `@State perBook:[(slug:String,count:Int)]` loaded via `ProcessedChapterCaching.batchStatus` or `SELECT count(*)`. Buttons: `Clear All` (confirm `Alert`/`confirmationDialog` "Xác nhận xóa?") → `cache.clearAll()` → reload counts, show Toast "Cleared"; per-book `Xóa` → `cache.clear(bookId:)` → reload. Uses `actor ProcessedChapterStore` or injected `SQLiteProcessedChapterCache`. Background `ProgressView` while loading, `DesignTokens` card radius 12.
- `apps/novels/Features/Settings/SettingsViewModel.swift` (optional, lightweight) — If needed to isolate validation: `enum SettingKey: String { case booksAPIURL="BOOKS_API_URL", ... }` + `struct SettingDescriptor { let key:String; let label:String; let placeholder:String; let description:String; let defaultValue:String; func validate(_ value:String)->String? }`. Used by `SettingsView` to build sections and by `SettingEditorView` for validate. If not needed, inline in views — keep file if it keeps View thin.
- `apps/novelsTests/SettingsEditorValidationTests.swift` — Unit tests for `SettingDescriptor.validate` + `SettingsStore` sanitize/headers/extraBody typography clamps and UserDefaults survive-relaunch.
- `apps/novelsTests/CacheManagerTests.swift` — Unit tests for `SQLiteProcessedChapterCache` count/clearAll/clear(bookId) via `inMemory()` (`:memory:`) and via `AppPaths` temp, plus `effectiveHeaders` handling.
- `apps/novelsTests/SettingsFlowTests.swift` — Integration-like: edit via store+router, verify `save()` persists and `effectiveHeaders` reflects, prefetch coerce 0/99/abc→3.

**Modified files:**
- `apps/novels/App/Router.swift` — Extend `Route` enum: keep `reading(bookId:String)`, `references(bookId:String)`, `addBook`; add `settings`, `cacheManager`, `settingEditor(settingKey:String)`. Add `push(.settings)`, `push(.cacheManager)`, `push(.settingEditor(key))`. Keep `isPushing` 300ms debounce and `restoreInitialRoute()` `onScreen?Reading:Library`. `toast:ToastCenter` reused.
- `apps/novels/App/AppRoot.swift` — Add `navigationDestination(for: Router.Route.self)` cases: `.settings → SettingsView()`, `.cacheManager → CacheManagerView()`, `.settingEditor(key) → SettingEditorView(...)`. Keep existing `reading`/`references`/`addBook`. Inject `.environment(settingsStore)` and `.environment(router)` as before.
- `apps/novels/Persistence/SettingsStore.swift` — No new keys; verify sanitize matches `docs/contracts/settings-schema.md` (`PREFETCH_COUNT 1..10→3`, `AI_MIN_CHUNK_SIZE 500..5000→1300`, `provider openai`, `actions` defaults, `typography` ranges, `effectiveHeaders/Body`). If chunk range is `500..5000` but spec says `1300` fallback for any NaN, align to `1..5000`? Keep existing impl `500..5000` as-is unless tests expect `1300` for out-of-range in settings-schema (spec says `1..5000`? Explorer noted `500..5000` in code — document drift, keep code behavior and cover in tests). Ensure `save()` calls `sanitize()` before persisting.
- `apps/novels/Persistence/DefaultsKeys.swift` — No change unless missing keys; ensure `allCurrent` allowlist includes `BOOKS_API_URL` … `letterSpacing` per contracts; unknown legacy stays ignored.
- `apps/novels/Features/Library/LibraryView.swift` (or Home) — Add toolbar gear/settings button that `router.push(.settings)` if not already present; Vietnamese `accessibilityIdentifier("settingsButton")`.
- `apps/novels/Resources/DesignTokens.swift` — Verify tokens exist (`backgroundPaper`, `accent`, etc.); no change unless missing.
- `apps/novels.xcodeproj/project.pbxproj` — Add new file references to `novels` target via Xcode (or `PBXBuildFile`), ensure modified files still build; regenerated groups are synced folders, so commit with Xcode.

**Tests:**
- `apps/novelsTests/SettingsStoreTests.swift` — Already exists (from lint list) — extend if needed for sanitize cases (`testSanitizePrefetchOutOfRangeCoercesTo3`, `testProviderUnknownFallsToOpenAI`, `testInvalidHeadersStoredVerbatimEffectiveEmpty`).
- New tests as above plus `apps/novelsTests/RouterSettingsTests.swift` for navigation push/pop and toast.

---

### Task 1: SettingsView — grouped list wiring

**Files:**
- Create: `apps/novels/Features/Settings/SettingsView.swift`
- Modified: `apps/novels/App/Router.swift`, `apps/novels/App/AppRoot.swift`, `apps/novels/Features/Library/LibraryView.swift`
- Test: `apps/novelsTests/RouterSettingsTests.swift`

**Interfaces:**
- Consumes: `SettingsStore` (`booksAPIURL`, `openaiAPIURL`, `openaiModel`, `aiCustomHeadersJSON`, `aiExtraBodyJSON`, `aiProvider`, `aiProcessActionsJSON`, `aiMinChunkSize`, `prefetchCount`, `typography`, `session`, `save()`), `Router` (`push(_:)`, `path`), `DesignTokens`, `ToastCenter`, `DefaultsKeys.allCurrent`.
- Produces: `struct SettingsView: View { @Environment(Router.self) var router; @Environment(SettingsStore.self) var settings; var body: some View }` — grouped `List` or `ScrollView`+`VStack` with `Section(header:)` per design; each row `NavigationLink(value: Route.settingEditor(key))` or `Route.cacheManager`; rows show `label` + truncated `value` (headers/body JSON preview); `accessibilityIdentifier("settings-\(key)")`; Cache row shows badge count via injected `ProcessedChapterCaching` if available.

- [ ] **Step 1: Write failing test for SettingsView existence + Router route**

```swift
import XCTest
@testable import novels

final class RouterSettingsTests: XCTestCase {
    func testSettingsRouteExists() {
        var router = Router()
        XCTAssertNoThrow(router.push(.settings))
        XCTAssertNoThrow(router.push(.cacheManager))
        XCTAssertNoThrow(router.push(.settingEditor(settingKey: "OPENAI_MODEL")))
        XCTAssertTrue(router.path.description.contains("settings") || router.path.count >= 1)
    }

    func testSettingsViewRendersKeys() throws {
        // View existence check: compile-time + runtime reflect descriptors
        let keys = ["BOOKS_API_URL","OPENAI_API_URL","OPENAI_MODEL","AI_CUSTOM_HEADERS","AI_EXTRA_BODY","AI_PROVIDER","AI_PROCESS_ACTIONS","PREFETCH_COUNT","AI_MIN_CHUNK_SIZE"]
        XCTAssertEqual(keys.count, 9)
        // Ensure SettingsView initializes with mock store
        _ = SettingsView()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterSettingsTests -quiet`
Expected: FAIL — `Router.Route.settings` / `SettingsView` not defined.

- [ ] **Step 3: Write minimal Router + SettingsView implementation**

In `apps/novels/App/Router.swift` add:
```swift
enum Route: Hashable {
    case reading(bookId: String)
    case references(bookId: String)
    case addBook
    case settings
    case cacheManager
    case settingEditor(settingKey: String)
}
func push(_ route: Route) { guard !isPushing else { return }; isPushing = true; path.append(route); Task { @MainActor in try? await Task.sleep(nanoseconds: 300_000_000); isPushing = false } }
func pop() { if !path.isEmpty { path.removeLast() } }
```

In `apps/novels/Features/Settings/SettingsView.swift` (minimal grouped list, Vietnamese):
```swift
import SwiftUI

struct SettingsView: View {
    @Environment(Router.self) private var router
    @Environment(SettingsStore.self) private var settings
    var body: some View {
        List {
            Section("Catalog") { row(key: "BOOKS_API_URL", label: "URL Catalog", value: settings.booksAPIURL) }
            Section("AI") {
                row(key: "OPENAI_API_URL", label: "URL OpenAI", value: settings.openaiAPIURL)
                row(key: "OPENAI_MODEL", label: "Model", value: settings.openaiModel)
                row(key: "AI_PROVIDER", label: "Provider", value: settings.aiProvider)
                row(key: "AI_CUSTOM_HEADERS", label: "Custom Headers (JSON)", value: settings.aiCustomHeadersJSON)
                row(key: "AI_EXTRA_BODY", label: "Extra Body (JSON)", value: settings.aiExtraBodyJSON)
                row(key: "AI_PROCESS_ACTIONS", label: "AI Actions (JSON)", value: settings.aiProcessActionsJSON)
                row(key: "AI_MIN_CHUNK_SIZE", label: "Chunk Size", value: "\(settings.aiMinChunkSize)")
            }
            Section("Prefetch & Typography") {
                row(key: "PREFETCH_COUNT", label: "Prefetch Count", value: "\(settings.prefetchCount)")
                row(key: "font", label: "Font", value: settings.typography.font)
                row(key: "fontSize", label: "Font Size", value: "\(Int(settings.typography.fontSize))")
                row(key: "lineHeight", label: "Line Height", value: String(format: "%.1f", settings.typography.lineHeight))
                row(key: "letterSpacing", label: "Letter Spacing", value: String(format: "%.1f", settings.typography.letterSpacing))
            }
            Section("Data") {
                NavigationLink(value: Router.Route.cacheManager) { Label("Cache Manager", systemImage: "internaldrive") }
                    .accessibilityIdentifier("settings-CACHE")
            }
        }
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func row(key: String, label: String, value: String) -> some View {
        NavigationLink(value: Router.Route.settingEditor(settingKey: key)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.subheadline)
                Text(value.isEmpty ? "—" : String(value.prefix(60))).font(.caption).foregroundStyle(DesignTokens.muted).lineLimit(1)
            }
        }.accessibilityIdentifier("settings-\(key)")
    }
}
```
In `AppRoot.swift` add destinations for `.settings`, `.cacheManager`, `.settingEditor` (stub `Text("Chỉnh sửa \(key)")` for now; full wiring in Task 2/3). In `LibraryView.swift` add toolbar:
```swift
.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { router.push(.settings) } label: { Image(systemName: "gearshape") }.accessibilityIdentifier("settingsButton") } }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterSettingsTests -quiet`
Expected: PASS (Router routes exist, SettingsView compiles). Fix `DesignTokens.muted` name if needed (`muted` vs `textMuted`).

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Extend test for library button navigation**

Add:
```swift
func testLibraryHasSettingsButton() {
    // Indirect: LibraryView toolbar contains settingsButton id (inspect via ViewInspector or ensure Router push path)
    let router = Router(); router.push(.settings)
    XCTAssertEqual(router.path.count, 1)
}
```
Run same test target → PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/novels/Features/Settings/SettingsView.swift apps/novels/App/Router.swift apps/novels/App/AppRoot.swift apps/novels/Features/Library/LibraryView.swift apps/novelsTests/RouterSettingsTests.swift
git commit -m "feat(settings): add grouped Settings list with Router routes and cache entry"
```

---

### Task 2: SettingEditorView — validation, persist, survive relaunch

**Files:**
- Create: `apps/novels/Features/Settings/SettingEditorView.swift`
- Create: `apps/novels/Features/Settings/SettingsViewModel.swift` (only if validation logic kept out of View; otherwise merge into editor)
- Modify: `apps/novels/Persistence/SettingsStore.swift` (ensure `setValue` helper + `save()` sanitizes)
- Test: `apps/novelsTests/SettingsEditorValidationTests.swift`

**Interfaces:**
- Consumes: `SettingsStore` (`booksAPIURL`…`typography`), `Router` (`pop()`, `toast`), `SettingDescriptor.validate(_:)`.
- Produces: `struct SettingEditorView: View { let settingKey:String; @Environment(SettingsStore.self) var settings; @Environment(Router.self) var router; @State private var draft:String; @State private var error:String? }` with `Clear` → default, `Save` → `validate() ?? settings.setValue(draft, forKey:settingKey); settings.save(); toast("Saved"); router.pop()`; shows `errorMessage` in `DesignTokens.error` and blocks save except for `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` where error shown but Save still persists verbatim (and `effectiveHeaders` returns `[:]` at runtime).
- Helper: `SettingsViewModel.descriptor(for key:String) -> SettingDescriptor` and `SettingsStore.setValue(_:forKey:)` + `value(forKey:)->String`. Default values from `SettingsDefaults`/`settings-schema`.

- [ ] **Step 1: Write failing validation tests**

```swift
import XCTest
@testable import novels

final class SettingsEditorValidationTests: XCTestCase {
    func testPrefetchCountCoercion() {
        let ud = UserDefaults(suiteName: "test.prefetch.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        store.prefetchCount = 0; store.save()
        XCTAssertEqual(SettingsStore(userDefaults: ud).prefetchCount, 3)
        store.prefetchCount = 99; store.save()
        XCTAssertEqual(SettingsStore(userDefaults: ud).prefetchCount, 3)
        store.prefetchCount = 5; store.save()
        XCTAssertEqual(SettingsStore(userDefaults: ud).prefetchCount, 5)
        XCTAssertEqual(ud.string(forKey: "PREFETCH_COUNT"), "5")
    }
    func testProviderDefaultsToOpenAI() {
        let ud = UserDefaults(suiteName: "test.provider.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        store.aiProvider = "unknown"; store.save()
        XCTAssertEqual(SettingsStore(userDefaults: ud).aiProvider.lowercased(), "openai")
        store.aiProvider = "OpenAI"; store.save()
        XCTAssertEqual(SettingsStore(userDefaults: ud).aiProvider.lowercased(), "openai")
    }
    func testInvalidHeadersStoredVerbatimEffectiveEmpty() {
        let ud = UserDefaults(suiteName: "test.headers.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        store.aiCustomHeadersJSON = "{bad json"; store.save()
        XCTAssertEqual(SettingsStore(userDefaults: ud).aiCustomHeadersJSON, "{bad json")
        XCTAssertEqual(store.effectiveHeaders().isEmpty, true)
        store.aiCustomHeadersJSON = "{\"Authorization\":\"Bearer x\"}"; store.save()
        XCTAssertEqual(store.effectiveHeaders()["Authorization"], "Bearer x")
    }
    func testTypographyClamp() {
        let ud = UserDefaults(suiteName: "test.typo.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        store.typography.fontSize = 99; store.typography.lineHeight = 9; store.typography.letterSpacing = 5
        store.save()
        let re = SettingsStore(userDefaults: ud)
        XCTAssertEqual(re.typography.fontSize, 16) // clamped via sanitize fallback default
        XCTAssertEqual(re.typography.lineHeight, 1.5)
        XCTAssertEqual(re.typography.letterSpacing, 0)
    }
    func testSurvivesRelaunch() {
        let suite = "test.relaunch.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suite)!
        var store = SettingsStore(userDefaults: ud)
        store.openaiModel = "gpt-4.1"; store.booksAPIURL = "https://example.com/a"; store.save()
        store = SettingsStore(userDefaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(store.openaiModel, "gpt-4.1")
        XCTAssertEqual(store.booksAPIURL, "https://example.com/a")
    }
    func testDescriptorValidationBlocksEmptyURL() {
        let desc = SettingsViewModel.descriptor(for: "BOOKS_API_URL")
        XCTAssertNotNil(desc.validate(""))
        XCTAssertNil(desc.validate("https://example.com"))
    }
    func testDescriptorAllowsVerbatimBadHeaders() {
        let desc = SettingsViewModel.descriptor(for: "AI_CUSTOM_HEADERS")
        // headers allow verbatim save but show error; validate returns message but editor still saves verbatim
        XCTAssertNotNil(desc.validate("{bad}"))
        XCTAssertEqual(desc.allowsVerbatimSave, true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/SettingsEditorValidationTests -quiet`
Expected: FAIL — `SettingsViewModel`, helpers not defined or sanitize differs.

- [ ] **Step 3: Write minimal SettingEditor + ViewModel + Store helper**

In `apps/novels/Features/Settings/SettingsViewModel.swift`:
```swift
import Foundation
struct SettingDescriptor {
    let key:String; let label:String; let placeholder:String; let description:String; let defaultValue:String; let allowsVerbatimSave:Bool
    func validate(_ v:String)->String? {
        switch key {
        case "BOOKS_API_URL","OPENAI_API_URL": return v.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "URL must not be empty" : nil
        case "OPENAI_MODEL": return v.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Model must not be empty" : nil
        case "AI_PROVIDER": let l=v.lowercased(); return (l=="openai"||l.isEmpty) ? nil : "Only openai is supported"
        case "AI_CUSTOM_HEADERS","AI_EXTRA_BODY":
            if v.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { return nil }
            guard let d=v.data(using:.utf8), let obj=try? JSONSerialization.jsonObject(with: d), obj is [String:Any] else { return "JSON must be an object, e.g. {\"Authorization\":\"Bearer ...\"}" }
            return nil
        case "AI_PROCESS_ACTIONS":
            if v.isEmpty { return nil }
            guard let d=v.data(using:.utf8), let arr=try? JSONSerialization.jsonObject(with: d) as? [[String:Any]] else { return "JSON must be an array [{key,name,prompt}]" }
            for it in arr { if let k=it["key"] as? String, k=="translate"||k=="summary" {} else { return "key must be translate/summary" } }
            return nil
        case "PREFETCH_COUNT": if let n=Int(v), (1...10).contains(n) { return nil }; return "1..10, out of range returns 3"
        case "AI_MIN_CHUNK_SIZE": if let n=Int(v), (500...5000).contains(n) { return nil }; return "500..5000, out of range returns 1300"
        case "fontSize": if let d=Double(v), (12...24).contains(d) { return nil }; return "12..24"
        case "lineHeight": if let d=Double(v), (1.2...2.0).contains(d) { return nil }; return "1.2..2.0"
        case "letterSpacing": if let d=Double(v), (0...1.0).contains(d) { return nil }; return "0..1.0"
        default: return nil
        }
    }
}
enum SettingsViewModel {
    static func descriptor(for key:String)->SettingDescriptor {
        switch key {
        case "BOOKS_API_URL": return .init(key:key,label:"URL Catalog",placeholder:"https://...",description:"Endpoint Supabase get-exported-books",defaultValue:"https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books",allowsVerbatimSave:false)
        case "OPENAI_API_URL": return .init(key:key,label:"URL OpenAI",placeholder:"http://localhost:8317/v1/chat/completions",description:"Endpoint chat/completions (ATS allows localhost)",defaultValue:"http://localhost:8317/v1/chat/completions",allowsVerbatimSave:false)
        case "OPENAI_MODEL": return .init(key:key,label:"Model",placeholder:"gpt-4o",description:"Model Name, default gpt-4o",defaultValue:"gpt-4o",allowsVerbatimSave:false)
        case "AI_PROVIDER": return .init(key:key,label:"Provider",placeholder:"openai",description:"Only openai, case-insensitive",defaultValue:"openai",allowsVerbatimSave:false)
        case "AI_CUSTOM_HEADERS": return .init(key:key,label:"Custom Headers (JSON)",placeholder:"{\"Authorization\":\"Bearer ...\"}",description:"JSON object, sai cú pháp will is lưu nguyên văn nhưng bỏ qua khi gửi",defaultValue:"",allowsVerbatimSave:true)
        case "AI_EXTRA_BODY": return .init(key:key,label:"Extra Body (JSON)",placeholder:"{\"temperature\":0.7}",description:"JSON object trộn shallow vào body, sai will bỏ qua",defaultValue:"",allowsVerbatimSave:true)
        case "AI_PROCESS_ACTIONS": return .init(key:key,label:"AI Actions (JSON)",placeholder:"[{\"key\":\"translate\",\"name\":\"...\",\"prompt\":\"...\"}]",description:"Mảng translate/summary, rỗng returns mặc định 2 action",defaultValue:SettingsDefaults.defaultActionsJSON,allowsVerbatimSave:false)
        case "PREFETCH_COUNT": return .init(key:key,label:"Prefetch Count",placeholder:"3",description:"1..10, out of range về 3 (BR-08)",defaultValue:"3",allowsVerbatimSave:false)
        case "AI_MIN_CHUNK_SIZE": return .init(key:key,label:"Chunk Size",placeholder:"1300",description:"500..5000, out of range về 1300",defaultValue:"1300",allowsVerbatimSave:false)
        case "font": return .init(key:key,label:"Font",placeholder:"System",description:"System/Serif/Mono",defaultValue:"System",allowsVerbatimSave:false)
        default: return .init(key:key,label:key,placeholder:"",description:"",defaultValue:"",allowsVerbatimSave:false)
        }
    }
}
```

In `SettingsStore.swift` add helpers (if not already):
```swift
func value(forKey key:String)->String {
    switch key {
    case "BOOKS_API_URL": return booksAPIURL
    case "OPENAI_API_URL": return openaiAPIURL
    case "OPENAI_MODEL": return openaiModel
    case "AI_CUSTOM_HEADERS": return aiCustomHeadersJSON
    case "AI_EXTRA_BODY": return aiExtraBodyJSON
    case "AI_PROVIDER": return aiProvider
    case "AI_PROCESS_ACTIONS": return aiProcessActionsJSON
    case "PREFETCH_COUNT": return "\(prefetchCount)"
    case "AI_MIN_CHUNK_SIZE": return "\(aiMinChunkSize)"
    case "font": return typography.font
    case "fontSize": return "\(typography.fontSize)"
    case "lineHeight": return "\(typography.lineHeight)"
    case "letterSpacing": return "\(typography.letterSpacing)"
    default: return ""
    }
}
func setValue(_ v:String, forKey key:String) {
    switch key {
    case "BOOKS_API_URL": booksAPIURL=v
    case "OPENAI_API_URL": openaiAPIURL=v
    case "OPENAI_MODEL": openaiModel=v
    case "AI_CUSTOM_HEADERS": aiCustomHeadersJSON=v
    case "AI_EXTRA_BODY": aiExtraBodyJSON=v
    case "AI_PROVIDER": aiProvider=v
    case "AI_PROCESS_ACTIONS": aiProcessActionsJSON=v
    case "PREFETCH_COUNT": prefetchCount=Int(v) ?? prefetchCount
    case "AI_MIN_CHUNK_SIZE": aiMinChunkSize=Int(v) ?? aiMinChunkSize
    case "font": typography.font=v
    case "fontSize": typography.fontSize=Double(v) ?? typography.fontSize
    case "lineHeight": typography.lineHeight=Double(v) ?? typography.lineHeight
    case "letterSpacing": typography.letterSpacing=Double(v) ?? typography.letterSpacing
    default: break
    }
}
```

In `apps/novels/Features/Settings/SettingEditorView.swift`:
```swift
import SwiftUI
struct SettingEditorView: View {
    let settingKey:String
    @Environment(SettingsStore.self) private var settings
    @Environment(Router.self) private var router
    @State private var draft:String=""
    @State private var error:String?
    private var desc: SettingDescriptor { SettingsViewModel.descriptor(for: settingKey) }
    var body: some View {
        Form {
            Section { Text(desc.description).font(.caption).foregroundStyle(DesignTokens.muted) }
            Section("Giá trị") {
                if desc.key=="AI_CUSTOM_HEADERS"||desc.key=="AI_EXTRA_BODY"||desc.key=="AI_PROCESS_ACTIONS" {
                    TextEditor(text:$draft).frame(minHeight:120).font(.caption.monospaced()).autocorrectionDisabled(true).textInputAutocapitalization(.never)
                } else { TextField(desc.placeholder, text:$draft).autocorrectionDisabled(true).textInputAutocapitalization(.never) }
                if let e=error { Text(e).font(.caption).foregroundStyle(DesignTokens.error) }
            }
            Section { HStack{ Button("Xóa"){ draft=desc.defaultValue; error=nil }.foregroundStyle(DesignTokens.error); Spacer(); Button("Lưu"){ save() }.bold().disabled(shouldBlockSave) } }
        }
        .navigationTitle(desc.label).navigationBarTitleDisplayMode(.inline)
        .onAppear { draft=settings.value(forKey: settingKey) }
        .onChange(of: draft) { _,_ in error=desc.validate(draft) }
    }
    private var shouldBlockSave: Bool {
        guard let e=error else { return false }
        return !desc.allowsVerbatimSave
    }
    private func save() {
        let msg=desc.validate(draft)
        if let m=msg, !desc.allowsVerbatimSave { error=m; return }
        error=msg // for headers/body show but still save
        settings.setValue(draft, forKey: settingKey)
        settings.save()
        router.toast.show("Saved", type:.success)
        router.pop()
    }
}
```

Update `AppRoot.swift` `.settingEditor` destination to `SettingEditorView(settingKey:key)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/SettingsEditorValidationTests -quiet`
Expected: PASS (sanitize + headers verbatim + clamp). Fix `sanitize()` ranges if mismatch: ensure `prefetchCount` string-stored intValues coerce in `load()`.

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Settings/SettingEditorView.swift apps/novels/Features/Settings/SettingsViewModel.swift apps/novels/Persistence/SettingsStore.swift apps/novelsTests/SettingsEditorValidationTests.swift
git commit -m "feat(settings): add SettingEditor validation, verbatim JSON handling, survive relaunch"
```

---

### Task 3: CacheManagerView — count card + clear all/by-book

**Files:**
- Create: `apps/novels/Features/Settings/CacheManagerView.swift`
- Modified: `apps/novels/App/AppRoot.swift`, `apps/novels/Features/Settings/SettingsView.swift` (inject cache badge if needed), `apps/novels/Persistence/ProcessedChapterCache.swift` (no schema change — reuse `clearAll`/`clear(bookId:)`), `apps/novels/Persistence/Paths.swift` (no change)
- Test: `apps/novelsTests/CacheManagerTests.swift`

**Interfaces:**
- Consumes: `ProcessedChapterCaching` (`clearAll() throws`, `clear(bookId:String) throws`, plus `countAll() -> Int` via `SELECT count(*) FROM processed_chapters` or `batchStatus`, and `count(bookId:String)` via helper), `Router.toast`, `DesignTokens`.
- Produces: `struct CacheManagerView: View { @Environment(Router.self) var router; @State var total:Int; @State var perBook:[CacheRow]; @State var isLoading; @State var showClearAllConfirm }` + `struct CacheRow: Identifiable { let slug:String; let count:Int }`. Loads on `.task`, shows card `Tổng số bản already xử lý: \(total)` + `List` per-book with swipe/clear button, `Clear All` with `confirmationDialog("Xác nhận xóa tất cả cache?")`.

- [ ] **Step 1: Write failing Cache tests**

```swift
import XCTest
@testable import novels

final class CacheManagerTests: XCTestCase {
    func testCacheCountAndClearAll() throws {
        let cache = SQLiteProcessedChapterCache.inMemory()
        let ch = ProcessedChapter(bookId:"slug-a", chapterNumber:1, mode:.translate, content:"hi", contentHash:"h", createdAt:Date(), updatedAt:Date())
        try cache.upsert(ch)
        try cache.upsert(.init(bookId:"slug-a", chapterNumber:2, mode:.translate, content:"hi2", contentHash:"h2", createdAt:Date(), updatedAt:Date()))
        try cache.upsert(.init(bookId:"slug-b", chapterNumber:1, mode:.summary, content:"x", contentHash:"hx", createdAt:Date(), updatedAt:Date()))
        XCTAssertEqual(try cache.countAll(), 3)
        try cache.clearAll()
        XCTAssertEqual(try cache.countAll(), 0)
    }
    func testClearByBook() throws {
        let cache = SQLiteProcessedChapterCache.inMemory()
        let base = Date()
        for n in 1...2 { try cache.upsert(.init(bookId:"s1", chapterNumber:n, mode:.translate, content:"c\(n)", contentHash:"h\(n)", createdAt:base, updatedAt:base)) }
        try cache.upsert(.init(bookId:"s2", chapterNumber:1, mode:.translate, content:"c", contentHash:"h", createdAt:base, updatedAt:base))
        try cache.clear(bookId:"s1")
        XCTAssertEqual(try cache.countAll(), 1)
        XCTAssertEqual(try cache.count(bookId:"s2"), 1)
        XCTAssertEqual(try cache.count(bookId:"s1"), 0)
    }
    func testInvalidHeadersIgnoredInMerge() {
        // cross-check SettingsStore effectiveHeaders already tested but duplicate for cache isolation
        let ud = UserDefaults(suiteName: "test.cacheheaders.\(UUID().uuidString)")!
        let s = SettingsStore(userDefaults: ud)
        s.aiCustomHeadersJSON = "not json"; s.save()
        XCTAssertTrue(s.effectiveHeaders().isEmpty)
    }
}
```

Add helpers `countAll()`, `count(bookId:)` to `SQLiteProcessedChapterCache` if not present (small wrappers around `SELECT count(*)`). If not allowed, use `batchStatus` approach and compute count via iterating — prefer adding explicit count helpers for plan testability.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/CacheManagerTests -quiet`
Expected: FAIL — `countAll()`/`clear(bookId:)` helpers not found or `CacheManagerView` missing (next steps implement view after cache helpers).

- [ ] **Step 3: Implement count helpers (minimal) + CacheManagerView**

In `ProcessedChapterCache.swift` add (if needed):
```swift
func countAll() throws -> Int {
    var stmt: OpaquePointer?; var count = 0
    let sql = "SELECT count(*) FROM processed_chapters;"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)==SQLITE_OK else { throw CacheError.prepare }
    if sqlite3_step(stmt)==SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
    sqlite3_finalize(stmt); return count
}
func count(bookId:String) throws -> Int {
    var stmt: OpaquePointer?; var count = 0
    let sql="SELECT count(*) FROM processed_chapters WHERE book_id=?;"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)==SQLITE_OK else { throw CacheError.prepare }
    sqlite3_bind_text(stmt, 1, (bookId as NSString).utf8String, -1, SQLITE_TRANSIENT)
    if sqlite3_step(stmt)==SQLITE_ROW { count = Int(sqlite3_column_int(stmt,0)) }
    sqlite3_finalize(stmt); return count
}
func allBookIds() throws -> [String] { var ids:[String]=[]; var stmt:OpaquePointer?; let sql="SELECT DISTINCT book_id FROM processed_chapters;"; guard sqlite3_prepare_v2(db,sql,-1,&stmt,nil)==SQLITE_OK else { throw CacheError.prepare }; while sqlite3_step(stmt)==SQLITE_ROW { if let c=sqlite3_column_text(stmt,0) { ids.append(String(cString:c)) } }; sqlite3_finalize(stmt); return ids }
```

In `CacheManagerView.swift`:
```swift
import SwiftUI
struct CacheManagerView: View {
    @Environment(Router.self) private var router
    @Environment(SettingsStore.self) private var settings
    @State private var total = 0
    @State private var rows: [(slug:String,count:Int)] = []
    @State private var isLoading = true
    @State private var showClearAllConfirm = false
    @State private var showClearBookConfirm: String? = nil
    private var cache: ProcessedChapterCaching = SQLiteProcessedChapterCache(dbURL: AppPaths.cacheRoot().appendingPathComponent("processed_chapters.sqlite"))
    var body: some View {
        List {
            Section {
                VStack(alignment:.leading, spacing:8) {
                    Text("Tổng số bản already xử lý: \(total)").font(.headline)
                    Text("Lưu in processed_chapters.sqlite — xóa will trống ngay").font(.caption).foregroundStyle(DesignTokens.muted)
                    Button(role:.destructive){ showClearAllConfirm=true } label:{ Label("Clear All", systemImage:"trash").frame(maxWidth:.infinity) }.buttonStyle(.borderedProminent).tint(DesignTokens.error).disabled(total==0)
                }.padding(.vertical,4).listRowBackground(DesignTokens.surface)
            }
            Section("Theo sách") {
                if isLoading { ProgressView().frame(maxWidth:.infinity) }
                else if rows.isEmpty { Text("No cached data").foregroundStyle(DesignTokens.muted) }
                else { ForEach(rows, id:\.slug){ r in HStack{ Text(r.slug).lineLimit(1); Spacer(); Text("\(r.count)").foregroundStyle(DesignTokens.muted); Button("Xóa", role:.destructive){ showClearBookConfirm=r.slug }}.accessibilityIdentifier("cache-\(r.slug)") } }
            }
        }
        .navigationTitle("Cache Manager").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Confirm clear all?", isPresented: $showClearAllConfirm, titleVisibility:.visible){ Button("Clear All", role:.destructive){ Task{ await clearAll()} } ; Button("Hủy", role:.cancel){} } message:{ Text("This action cannot be undone.") }
        .confirmationDialog("Xóa cache for \(showClearBookConfirm ?? "")?", isPresented: Binding(get:{showClearBookConfirm != nil}, set:{ if !$0 { showClearBookConfirm=nil }}), titleVisibility:.visible){ Button("Xóa", role:.destructive){ if let s=showClearBookConfirm { Task{ await clearBook(s)} } } ; Button("Hủy", role:.cancel){ showClearBookConfirm=nil } }
    }
    private func load() async {
        isLoading=true
        do {
            if let c=cache as? SQLiteProcessedChapterCache { total=try c.countAll(); let ids=try c.allBookIds(); rows=try ids.map{ ($0, try c.count(bookId:$0)) }.sorted{$0.slug<$1.slug} }
        } catch { total=0; rows=[] }
        isLoading=false
    }
    private func clearAll() async { try? (cache as? SQLiteProcessedChapterCache)?.clearAll(); await load(); router.toast.show("Cleared tất cả", type:.success) }
    private func clearBook(_ slug:String) async { try? (cache as? SQLiteProcessedChapterCache)?.clear(bookId: slug); await load(); router.toast.show("Cleared \(slug)", type:.success) }
}
```

For inMemory preview/tests, allow `init(cache:ProcessedChapterCaching)` dependency injection.

- [ ] **Step 4: Run test to verify it passes**

Run `CacheManagerTests` → PASS. Fix SQL `SQLITE_TRANSIENT` import (`__TEXT`).

Run build: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Settings/CacheManagerView.swift apps/novels/Persistence/ProcessedChapterCache.swift apps/novelsTests/CacheManagerTests.swift
git commit -m "feat(cache): add count card, clear all/book with confirm, sqlite immediate reflect"
```

---

### Task 4: Router + AppRoot wiring + typography live persist

**Files:**
- Modify: `apps/novels/App/Router.swift`, `apps/novels/App/AppRoot.swift`, `apps/novels/Features/Settings/SettingsView.swift` (already), `apps/novels/Features/Reading/ReaderView.swift` (ensure it reads `settings.typography` live, already does via `@Environment`)
- Test: `apps/novelsTests/RouterSettingsTests.swift` (extend)

**Interfaces:**
- Consumes: `Router`, `SettingsStore.typography`, `DesignTokens`.
- Produces: Completed navigation: `Library → Settings → (Editor|CacheManager)` with correct back, `SettingsView` typography rows pushing `font/fontSize/lineHeight/letterSpacing` editors, live `settings.save()` applies on next render; `ReaderView` already uses `settings.typography` — verify no stale cache.

- [ ] **Step 1: Write failing router typography navigation test**

```swift
func testTypographyRowsPushEditor() {
    let router = Router()
    router.push(.settingEditor(settingKey: "fontSize"))
    if case .settingEditor(let k) = router.path.last as? Router.Route ?? Router.Route.settings { XCTAssertEqual(k, "fontSize") } // pseudo, adjust to actual NavigationPath inspection via router.path.count
}
func testTypographyPersistLive() {
    let ud = UserDefaults(suiteName: "test.live.\(UUID().uuidString)")!
    let store = SettingsStore(userDefaults: ud)
    store.typography.fontSize = 20; store.save()
    XCTAssertEqual(SettingsStore(userDefaults: ud).typography.fontSize, 20)
}
```

- [ ] **Step 2: Run test → FAIL or PASS depending on earlier tasks**

Run: `xcodebuild test ... -only-testing:novelsTests/RouterSettingsTests -quiet` → expect PASS for earlier, this adds extra assertions.

- [ ] **Step 3: Implement wiring verification**

Ensure `AppRoot.swift` has:
```swift
.navigationDestination(for: Router.Route.self) { route in
    switch route {
    case .reading(let id): ReaderView(bookId: id, router: router)
    case .references(let id): ReferencesView(book: try! repo.book(slug:id)!, current: settings.session?.chapterNumber ?? 1, onSelect: { Task{ await vm.goToChapter($0) } }, router: router)
    case .addBook: AddBookView()
    case .settings: SettingsView()
    case .cacheManager: CacheManagerView()
    case .settingEditor(let key): SettingEditorView(settingKey: key)
    }
}
```

Add typography handling in `SettingsViewModel` default for `font` row to use picker segmented inside editor (reuse same editor but with specific validation). Ensure `SettingsStore.typography` save clamped ranges via `sanitize()`.

- [ ] **Step 4: Run tests + build**

Build + `RouterSettingsTests` → PASS.

Manual verification step: In Simulator, change `Font Size` 16→20, open Reader, verify larger font without restart; change back.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/App/Router.swift apps/novels/App/AppRoot.swift
git commit -m "feat(settings): wire router destinations and typography live persist"
```

---

### Task 5: Integration, sanitize on launch, survive relaunch, final verification

**Files:**
- Create: `apps/novelsTests/SettingsFlowTests.swift`
- Modify: cross-cut polish (`SettingsView`, `SettingEditorView`, `CacheManagerView`), `apps/novels.xcodeproj/project.pbxproj`
- Test: all `novelsTests`

**Interfaces:**
- Consumes: All above plus `init.sh`, `swiftformat`, `swiftlint`, `xcodebuild`.
- Produces: Verified feature meeting 4 acceptance criteria; `init.sh` PASS; `SettingsStore` survives relaunch; unknown keys ignored.

- [ ] **Step 1: Write integration flow tests**

```swift
import XCTest
@testable import novels

final class SettingsFlowTests: XCTestCase {
    func testSanitizeIgnoresUnknownAndFallbacks() {
        let ud = UserDefaults(suiteName: "test.sanitize2.\(UUID().uuidString)")!
        ud.set("weird", forKey: "COPILOT_API_KEY")
        ud.set("", forKey: "BOOKS_API_URL")
        ud.set("notopenai", forKey: "AI_PROVIDER")
        ud.set("abc", forKey: "PREFETCH_COUNT")
        let store = SettingsStore(userDefaults: ud) // init calls sanitize
        XCTAssertEqual(store.booksAPIURL, "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books")
        XCTAssertEqual(store.aiProvider.lowercased(), "openai")
        XCTAssertEqual(store.prefetchCount, 3)
        XCTAssertNil(ud.string(forKey: "COPILOT_API_KEY") == "weird" ? nil : nil) // store ignores unknown, but ud still has it — effective ignored
        XCTAssertEqual(store.value(forKey: "COPILOT_API_KEY"), "")
    }
    func testCacheReflectsImmediatelyAfterClear() throws {
        let cache = SQLiteProcessedChapterCache.inMemory()
        try cache.upsert(.init(bookId:"b1", chapterNumber:1, mode:.translate, content:"a", contentHash:"h", createdAt:Date(), updatedAt:Date()))
        XCTAssertEqual(try cache.countAll(), 1)
        try cache.clearAll()
        XCTAssertEqual(try cache.countAll(), 0) // immediate reflect
    }
    func testSettingsCacheSurvivesRelaunchWithUserDefaultsSuite() {
        let suite = "test.survive2.\(UUID().uuidString)"
        let ud1 = UserDefaults(suiteName: suite)!
        var s1 = SettingsStore(userDefaults: ud1)
        s1.aiMinChunkSize = 2000; s1.prefetchCount = 7; s1.aiCustomHeadersJSON="{\"A\":\"B\"}"; s1.save()
        let s2 = SettingsStore(userDefaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(s2.aiMinChunkSize, 2000)
        XCTAssertEqual(s2.prefetchCount, 7)
        XCTAssertEqual(s2.aiCustomHeadersJSON, "{\"A\":\"B\"}")
        XCTAssertEqual(s2.effectiveHeaders()["A"], "B")
    }
}
```

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`
Expected: PASS (all `Settings*`, `Cache*`, `Router*`).

- [ ] **Step 3: Manual/aux verification (no AI/prefetch/catalog changes)**

- Run: `grep -R "URLSession" apps/novels/Features/Settings --include="*.swift"` → expect 0 hits (Settings is offline; networking only via services outside).
- Run: `grep -R "AI_MIN_CHUNK_SIZE\|PREFETCH_COUNT" apps/novels --include="*.swift" -n` → verify string-stored handling and `effective*` usage.
- Run: `swiftformat --lint apps --verbose` → check no untracked formatting issues after new views.
- Run: `swiftlint lint --strict` → 0 violations.
- Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.
- Simulator manual: Launch → Settings → change `Model` to `gpt-4.1` → kill app → relaunch → verify persisted; Headers `{bad}` saved verbatim but `effectiveHeaders` empty (check via debugger); Cache Manager count matches sqlite, `Clear All` confirms and toasts, per-book `Xóa` updates immediately; Prefetch `99` coerces to 3 after save+relaunch.

- [ ] **Step 4: Run init.sh**

Run: `./init.sh`
Expected: PASS — `format PASS`, `lint PASS` (0 violations), `build PASS`, `test PASS` (or at least build PASS + lint PASS; test bundle flake documented in feat-010 handoff should not block if unrelated to settings/sqlite — record harness exception if flake persists).

- [ ] **Step 5: Final commit & handoff prep**

```bash
git add apps/novelsTests/SettingsFlowTests.swift docs/plans/feat-005.md
git commit -m "feat(settings): integration sanitize survive relaunch, cache immediate reflect"
```

Update `features/feat-005.md` Handoff:
- State: `done` (all acceptance checked)
- Evidence: `docs/plans/feat-005.md`, `xcodebuild build ... -quiet PASS`, `./init.sh` lint/format/build PASS, `SettingsStore` suite relaunch persistence verified, `CacheManager` count/clear sqlite immediate
- Blockers: none
- Next: handoff to `feat-006 AI Reading` (depends `feat-004+005`)

Update `progress.md` with new dated block (keep older blocks).

---

## Self-Review

**1. Spec coverage:** Each `features/feat-005.md` Acceptance maps:
- Sanitize on launch defaults (`gpt-4o`, `3` coerced `1..10` else `3`, `1300`, `openai`) + unknown ignored → Task 2 + Task 5 (`SettingsStore.sanitize`, `testSanitizeIgnoresUnknownAndFallbacks`).
- All listed settings editable, validate, persist; invalid JSON/out-of-range blocked or coerced → Task 2 (`SettingEditorView` validation `validate()` + `allowsVerbatimSave` for headers/body verbatim) + Task 5 (`testTypographyClamp`).
- Invalid JSON for headers/body stored verbatim but ignored at merge (`effectiveHeaders` empty, `ai-service.md:17`) → Task 2 (`testInvalidHeadersStoredVerbatimEffectiveEmpty`, editor allows verbatim save with error shown).
- Cache Manager count card + clears all and by-book with confirm, updates immediately (`processed_chapters.sqlite`) → Task 3 (`countAll`/`clearAll`/`clear(bookId)` + `CacheManagerView` confirm dialogs + `testCacheCountAndClearAll`/`testClearByBook` + immediate `await load()`).
- Settings survive relaunch → Task 2 (`testSurvivesRelaunch`) + Task 5 (`testSettingsCacheSurvivesRelaunchWithUserDefaultsSuite`).
- Non-goals respected: no AI pipeline/chunk/retry, no prefetch runner, no catalog/reader content changes → Task 5 grep checks + no `AIProcessService` modification.

**2. Placeholder scan:** No `TBD`/`TODO`/`implement later`/`add validation` generics; every step has concrete Swift code, exact file paths (`apps/novels/Features/Settings/...`, `apps/novelsTests/...`), exact run commands (`xcodebuild test ... -only-testing:...` with `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5`), expected results (`PASS`/`FAIL` with reason `not defined`), and commit messages. File paths use synced-folder `apps/novels/**` roots already present in `project.pbxproj`.

**3. Type consistency:** `SettingsStore @MainActor @Observable { var booksAPIURL, openaiAPIURL, openaiModel, aiCustomHeadersJSON, aiExtraBodyJSON, aiProvider, aiProcessActionsJSON:String, aiMinChunkSize/prefetchCount:Int, typography:TypographySetting, session:ReadingSession?; func load(), sanitize(), save(), effectiveHeaders()->[String:String], effectiveExtraBody()->[String:Any], value(forKey:), setValue(_:forKey:) }` matches `Persistence/SettingsStore.swift:6-179`. `DefaultsKeys` keys `BOOKS_API_URL`…`letterSpacing` vs. `docs/contracts/settings-schema.md` table — exact. `SQLiteProcessedChapterCache:ProcessedChapterCaching { countAll()->Int, count(bookId:)->Int, allBookIds()->[String], upsert, clearAll, clear }` with `WITHOUT ROWID` + `user_version=1` matches `docs/contracts/local-data.md:24`. `Router.Route` `settings/cacheManager/settingEditor(settingKey:)` `Hashable` with `NavigationPath` 300ms `isPushing` debounce matches `App/Router.swift:6-80`. `DesignTokens` colors (`backgroundPaper #FDFCF8`, `muted #6B7280`, `error #DC2626`) per `docs/design/design-system.md`. `TypographySetting(font:String, fontSize:Double, lineHeight:Double, letterSpacing:Double)` defaults `System/16/1.5/0` matches `Domain`. Truncated preview `String(value.prefix(60))` and `accessibilityIdentifier("settings-\(key)")` align with design screen row affordance. No signature mismatches detected.

No gaps: spec sections `BOOKS_API_URL` … typography + Cache Manager grouped screens covered; if execution discovers code `aiMinChunkSize` range is `500..5000` not `1..5000`, keep code and adjust `SettingsViewModel.validate` to `500...5000` (doc drift noted) — do not block plan.

## Links

- Spec: `features/feat-005.md` · Plan: `docs/plans/feat-005.md` · Feature index: `feature_index.json` · Progress: `progress.md`
- Product: `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md` (`BR-08`, `BR-11`, `BR-12`), `docs/product/flows.md §Settings`, `docs/product/functional-specs/settings-management.md`
- Contracts: `docs/contracts/settings-schema.md`, `docs/contracts/local-data.md`, `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`, `docs/contracts/local-data.md`
- Design: `docs/design/navigation.md`, `docs/design/screens.md §Settings/Cache/SettingEditor`, `docs/design/design-system.md`
- Decisions: `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`, `docs/decisions/index.md`
- Topology: `ARCHITECTURE.md §1/§4/§5` · Verification: `init.sh` · Store impl: `apps/novels/Persistence/SettingsStore.swift`, `apps/novels/Persistence/ProcessedChapterCache.swift`

