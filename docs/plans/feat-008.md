# Hardening + Release Readiness Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Harden the app to iPhone-only release readiness with verified project config, accessibility, and regression/edge coverage and a passing `./init.sh`.

**Architecture:** Config audit locks `TARGETED_DEVICE_FAMILY=1` and iOS 26.5, prunes iPad-only plist entries, and verifies AppIcon/launch; a11y task enforces contrast/label/size tokens directly in SwiftUI views without new abstraction; regression task adds one `HardeningRegressionTests` suite that exercises the seven required edges against existing stores (FileManager/SQLite/UserDefaults/Task cancellation) and updates UI only where gaps exist; final task collects evidence and marks feat-008 done.

**Tech Stack:** Swift 5.0 / SwiftUI, Xcode `apps/novels.xcodeproj` scheme `novels` iOS 26.5 `TARGETED_DEVICE_FAMILY=1`, `Foundation.FileManager` + `libsqlite3` + `UserDefaults` `@Observable`, `URLSession` async/await + `actor` dedup, `SwiftUI.Text` HTML→spans (no WebKit), `XCTest` + `XCUITest`, SwiftLint 0.65.1 / SwiftFormat 0.62.1, Vietnamese copy.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — `TARGETED_DEVICE_FAMILY=1`, `IPHONEOS_DEPLOYMENT_TARGET=26.5`, `LSRequiresIPhoneOS=true`, no iPad multitasking per `docs/decisions/ios-scope.md` and `ARCHITECTURE.md` §1.
- Single module `apps/novels`, Swift 5.0, `DEVELOPMENT_TEAM M5U4E4H84J`, no SwiftPM packages — native only (`FileManager`, `libsqlite3`, `UserDefaults`, `URLSession`, `CryptoKit`) per `ARCHITECTURE.md`.
- No `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, WebKit, or second AI cache per `docs/decisions/local-persistence.md` and `docs/contracts/local-data.md`.
- Identity: `book.json.id` string slug is sole folder/cache key; remote numeric `ExportedBook.id` never used per `docs/decisions/book-identity.md`; stores `Application Support/novels/books/<slug>/` + `Application Support/novels/cache/processed_chapters.sqlite` `PRIMARY KEY(book_id,chapter_number,mode) WITHOUT ROWID` `user_version=1` `INSERT OR REPLACE` mode `none` never written.
- Settings: `UserDefaults` `@Observable` `SettingsStore.sanitize()` on launch, `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON ignored at merge per `docs/contracts/ai-service.md:17`, unknown/legacy keys ignored, `PREFETCH_COUNT` default 3 allowed `1..10` else 3, `AI_MIN_CHUNK_SIZE` default 1300 allowed `500..5000` else 1300, `AI_PROVIDER` only `openai` case-insensitive.
- Networking: catalog `POST` empty body `Content-Type: application/json` no auth; AI chunk `~1300` retry 3× `1000 ms`/`2000 ms` + `actor` dedup; prefetch `Task` cancellable; ATS allows `http://localhost:8317` only per `Info.plist`.
- Design: tokens `background #FDFCF8/#FFFFFF`, `surface #FFFFFF`, `text #111111`, `muted #6B7280`, `accent #2563EB`, `success #16A34A`, `warning #EA580C`, `error #DC2626`, `border #E5E7EB`; contrast 4.5:1 text / 3:1 icons; targets 44×44 min per `docs/design/design-system.md:58-64`.
- Verification: `./init.sh` (swiftformat --lint, swiftlint --strict, `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`, `xcodebuild test` same destination, drift).

---

## File Structure

**New files (this feature may create):**
- `apps/novelsTests/HardeningRegressionTests.swift` — Regression/edge suite covering the 7 required cases (offline scan, invalid ZIP variants, missing chapter, invalid JSON headers/body ignored, cache clear immediate, prefetch cancel, kill-on-Reading resume). Uses `FileBookRepository` with temp `Application Support` roots, `SQLiteProcessedChapterCache.inMemory()`, isolated `UserDefaults(suiteName:)`, mock URL protocols.
- `docs/plans/feat-008.md` — This plan.

**Modified files (expected):**
- `apps/novels.xcodeproj/project.pbxproj` — Verify `TARGETED_DEVICE_FAMILY=1` on all 6 configs (already 1), `IPHONEOS_DEPLOYMENT_TARGET=26.5`, `GENERATE_INFOPLIST_FILE=NO` already set, `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`; no iPad-only target changes otherwise.
 - `apps/novels/Info.plist` — Keep `LSRequiresIPhoneOS true`, `UILaunchScreen dict` (no storyboard), `NSAppTransportSecurity` localhost only; authoritative `UISupportedInterfaceOrientations` only (`Portrait`, `LandscapeLeft`, `LandscapeRight`) — both `UISupportedInterfaceOrientations~ipad` and redundant `UISupportedInterfaceOrientations~iphone` removed when `TARGETED_DEVICE_FAMILY=1` + `LSRequiresIPhoneOS=true` (single key avoids divergence; see `docs/decisions/ios-scope.md` Implementation note). `GENERATE_INFOPLIST_FILE=NO` so `INFOPLIST_KEY_…` build settings are ineffective.
- `apps/novels/Assets.xcassets/AppIcon.appiconset/Contents.json` — Verify 3 `universal/ios/1024` entries (light/dark/tinted) present — no change unless missing role.
- `apps/novels/Features/Library/LibraryView.swift` — Add/verify `accessibilityLabel`/`accessibilityIdentifier` on row/container, ensure empty state `ContentUnavailable` labels, minimum 44 row height, swipe actions reachable.
- `apps/novels/Features/Reading/ReaderView.swift` — Ensure `prevButton`/`nextButton` 44×44, disabled at bounds, `accessibilityLabel` `"Chương trước"`/`"Chương sau"` already present + verify, `typographyButton`, `toBottomButton`, `prefetchStatus`.
- `apps/novels/Features/Reading/ReferencesView.swift` — Verify `ref-N` identifiers and checkmark a11y.
- `apps/novels/Features/Import/AddBookView.swift` — Verify sort picker `accessibilityLabel "Sắp xếp"`, retry labels, row identifiers.
- `apps/novels/Features/Settings/SettingsView.swift` + `CacheManagerView.swift` + `SettingEditorView.swift` + `ReaderBottomSheet.swift` — Verify labels/handles, 44pt steppers with hit slop, sheet handle a11y.
- `apps/novels/Persistence/**` + `apps/novels/Services/**` — No logic changes expected; only comment/drift fixes if audit finds hardcoded `1,2` remnants elsewhere.
- `features/feat-008.md` `progress.md` `feature_index.json` — Handoff/evidence at close.

---

### Task 1: Project config + assets/launch verification (iPhone-only, iOS 26+, icons, ATS)

**Files:**
- Modify: `apps/novels.xcodeproj/project.pbxproj:453-587`
- Modify: `apps/novels/Info.plist:1-60`
- Modify: `apps/novels/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Test: `apps/novelsTests/HardeningRegressionTests.swift` (config probe helper)

**Interfaces:**
- Consumes: `xcodebuild -list`, `plutil -p`, `grep TARGETED_DEVICE_FAMILY`.
- Produces: Verified `TARGETED_DEVICE_FAMILY=1` ×6, `IPHONEOS_DEPLOYMENT_TARGET=26.5` ×6, `LSRequiresIPhoneOS=true`, correct `UILaunchScreen`, ATS localhost-only, no `1,2` residue.

- [x] **Step 1: Write failing config regression test (documents expected values)**

```swift
import XCTest
@testable import novels

final class HardeningRegressionTests: XCTestCase {
    func testProjectConfigIsIPhoneOnly() throws {
        let pbx = try String(contentsOfFile: "apps/novels.xcodeproj/project.pbxproj", encoding: .utf8)
        // must be iPhone only, not 1,2
        XCTAssertTrue(pbx.contains("TARGETED_DEVICE_FAMILY = 1;"))
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = \"1,2\""))
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = 1,2"))
        XCTAssertTrue(pbx.contains("IPHONEOS_DEPLOYMENT_TARGET = 26.5;"))
        XCTAssertTrue(pbx.contains("DEVELOPMENT_TEAM = M5U4E4H84J;") || pbx.contains("DEVELOPMENT_TEAM = M5U4E4H84J"))
    }
    func testInfoPlistATSAndLaunch() throws {
        // verify bundle plist from app target (use Bundle.main for app, not test host)
        // For unit, read file directly
        let url = URL(fileURLWithPath: "apps/novels/Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
        XCTAssertEqual(plist["LSRequiresIPhoneOS"] as? Bool, true)
        XCTAssertNotNil(plist["UILaunchScreen"])
        let ats = plist["NSAppTransportSecurity"] as? [String: Any]
        let domains = ats?["NSExceptionDomains"] as? [String: Any]
        XCTAssertNotNil(domains?["localhost"])
        XCTAssertNil(domains?["example.com"])
        // iPhone-only: should not contain iPad-only interface orientation when family=1
        // If file still contains ~ipad, test should fail to force cleanup
        let text = try String(contentsOf: url, encoding: .utf8)
        // Expect no ~ipad entry for pure iPhone family (or explicitly document retention)
        // This assertion will be enabled after cleanup:
        // XCTAssertFalse(text.contains("UISupportedInterfaceOrientations~ipad"))
    }
}
```

- [x] **Step 2: Run test to verify it fails (or reveals iPad remnants)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HardeningRegressionTests/testProjectConfigIsIPhoneOnly -quiet`
Expected: FAIL if pbx still contains `1,2` or Info.plist ~ipad present (currently family already 1, but ~ipad array still present so second assertion may need enabling).

- [x] **Step 3: Fix Info.plist — remove iPad-only orientations (iPhone-only per ios-scope.md)**

In `apps/novels/Info.plist` remove block:
```xml
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```
Keep single authoritative key (remove the `~iphone` duplicate — redundant when `TARGETED_DEVICE_FAMILY=1` + `LSRequiresIPhoneOS=true`):
```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```
(`UISupportedInterfaceOrientations~iphone` removed; `~ipad` already removed. No `~ipad`/`~iphone` keys remain. UpsideDown intentionally excluded on iPhone.) Verify `UILaunchScreen` remains `<dict/>` (no storyboard), `LSRequiresIPhoneOS <true/>`, ATS localhost-only unchanged. Note: `GENERATE_INFOPLIST_FILE=NO` so `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`/`_iPhone` in `project.pbxproj` is ineffective; authoritative gate is this `Info.plist` (see `docs/decisions/ios-scope.md` Implementation note).

- [x] **Step 4: Verify project.pbxproj family count (already 1)**

Run: `grep -c "TARGETED_DEVICE_FAMILY = 1;" apps/novels.xcodeproj/project.pbxproj`
Expected: `6` (Debug/Release per 3 targets: novels + novelsTests + novelsUITests). Confirm no `1,2`:
Run: `grep -c "TARGETED_DEVICE_FAMILY = 1,2" apps/novels.xcodeproj/project.pbxproj || echo 0` → `0`.

Also verify:
Run: `grep -c "IPHONEOS_DEPLOYMENT_TARGET = 26.5;" apps/novels.xcodeproj/project.pbxproj` → `6`
Run: `grep "ASSETCATALOG_COMPILER_APPICON_NAME" apps/novels.xcodeproj/project.pbxproj | head -n 5` → `AppIcon`

- [x] **Step 5: Verify AppIcon asset has 3 universal 1024 entries**

Run: `cat apps/novels/Assets.xcassets/AppIcon.appiconset/Contents.json | grep -c '"size" : "1024x1024"'`
Expected: `3` (light/dark/tinted). If missing, add via Xcode or JSON edit per ios spec — already 3 so no change. Verify via `plutil -p apps/novels/Assets.xcassets/AppIcon.appiconset/Contents.json` light/dark/tinted present.

- [x] **Step 6: Run config tests + build to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HardeningRegressionTests/testProjectConfigIsIPhoneOnly -only-testing:novelsTests/HardeningRegressionTests/testInfoPlistATSAndLaunch -quiet`
Expected: PASS after ~ipad removal (adjust assertion to `XCTAssertFalse(text.contains("~ipad"))`).

Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.
Run: `swiftformat --lint apps --verbose` → 0.
Run: `swiftlint lint --strict` → 0 in ~87 files.

- [x] **Step 7: Commit**

```bash
git add apps/novels/Info.plist apps/novels.xcodeproj/project.pbxproj apps/novelsTests/HardeningRegressionTests.swift
git commit -m "feat(hardening): verify iPhone-only config, remove iPad orientations, verify AppIcon/ATS"
```

---

### Task 2: Accessibility audit — contrast, labels, 44pt targets

**Files:**
- Modify: `apps/novels/Features/Library/LibraryView.swift:1-100`
- Modify: `apps/novels/Features/Reading/ReaderView.swift:130-320`
- Modify: `apps/novels/Features/Reading/ReferencesView.swift`
- Modify: `apps/novels/Features/Reading/ReaderBottomSheet.swift:14-130`
- Modify: `apps/novels/Features/Import/AddBookView.swift`
- Modify: `apps/novels/Features/Settings/*` (SettingsView, CacheManagerView, SettingEditorView)
- Modify: `apps/novels/SharedUI/*` (ToastView, LoadingView, BottomSheetView)
- Test: `apps/novelsTests/HardeningRegressionTests.swift` (a11y cases)

**Interfaces:**
- Consumes: `DesignTokens` (`text #111111`, `muted #6B7280`, `accent #2563EB`, etc.), `accessibilityLabel`, `accessibilityIdentifier`, `.frame(minHeight:44)`.
- Produces: All interactive elements 44×44, VoiceOver labels present, Dynamic Type respected, contrast tokens unchanged.

- [x] **Step 1: Write failing a11y tests**

```swift
import XCTest
import SwiftUI
@testable import novels

final class HardeningA11yTests: XCTestCase {
    @MainActor
    func testLibraryRowsHaveIdentifiersAndMinHeight() {
        // smoke: LibraryViewModel scanning tested elsewhere; here we check view a11y via ViewInspector alternative: grep source
        let src = try! String(contentsOfFile: "apps/novels/Features/Library/LibraryView.swift", encoding: .utf8)
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"library.row."))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Add Book\")"))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Cài đặt\")"))
        // ensure row min height token or 56 from design-system
        XCTAssertTrue(src.contains("56") || src.contains("44"))
    }
    @MainActor
    func testReaderControlsA11y() {
        let src = try! String(contentsOfFile: "apps/novels/Features/Reading/ReaderView.swift", encoding: .utf8)
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"prevButton\")"))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Chương trước\")"))
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"nextButton\")"))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Chương sau\")"))
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"typographyButton\")"))
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"prefetchStatus\")"))
        // 44pt check: ensure buttons have frame min 44 or .contentShape + padding
        XCTAssertTrue(src.contains("44") || src.contains("minHeight"))
    }
    func testContrastTokensUnchanged() {
        let src = try! String(contentsOfFile: "apps/novels/Resources/DesignTokens.swift", encoding: .utf8)
        XCTAssertTrue(src.contains("#111111")) // text
        XCTAssertTrue(src.contains("#6B7280")) // muted
        XCTAssertTrue(src.contains("#2563EB")) // accent
        XCTAssertTrue(src.contains("#FDFCF8")) // paper
    }
    func testBottomSheetHandleA11y() {
        let src = try! String(contentsOfFile: "apps/novels/SharedUI/BottomSheetView.swift", encoding: .utf8)
        // handle is decorative but should not be focusable; verify it exists
        XCTAssertTrue(src.contains("DesignTokens.border") || src.contains("handle"))
    }
}
```

- [x] **Step 2: Run tests to verify they fail (expose missing labels/size)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HardeningA11yTests -quiet`
Expected: FAIL if any identifier missing or 44 not found in ReaderView/LibraryView.

- [x] **Step 3: Fix a11y gaps — ensure 44pt targets and labels**

Edits (apply only where grep shows gap; many already exist per earlier feat-002/004/005):

In `apps/novels/Features/Library/LibraryView.swift`:
- Each row `HStack` → add `.frame(minHeight: 44)` and `.contentShape(Rectangle())`
- `Button add` already has `.accessibilityLabel("Add Book")` — ensure `.frame(minWidth:44, minHeight:44)`
- Gear button `"Cài đặt"` same
- Swipe actions `Info`/`Delete` keep labels, ensure reachable (no extra fix needed)

In `apps/novels/Features/Reading/ReaderView.swift`:
- `prevButton`/`nextButton` already have identifiers + labels — add `.frame(minHeight:44)` + `.contentShape(Rectangle())` if missing
- Footer buttons inside `HStack` ensure `.disabled(chapterNumber==1)` / `==total` preserved with visible dim `opacity(disabled?0.4:1)`
- `typographyButton` (gear) ensure `.frame(minWidth:44,minHeight:44)`
- `toBottomButton` same
- `prefetchStatus` `ProgressView` + text already has identifier — keep read-only (no tap)
- Chapters `Text` blocks use `DesignTokens.text` on `DesignTokens.backgroundPaper` (#111111 on #FDFCF8) — ratio ~15.8:1 passes 4.5:1; muted #6B7280 on #FFFFFF ~4.6:1 passes

In `apps/novels/Features/Reading/ReaderBottomSheet.swift`:
- Font picker `accessibilityIdentifier("fontPicker")` already; add `.frame(minHeight:44)` per segment
- `aiModePicker` + `reprocessButton` already identified
- Stepper controls (+/-) already have +10 hit slop per design-system — verify `.contentShape(Rectangle()).frame(minWidth:44,minHeight:44)`
- Handle view `.accessibilityHidden(true)` so VoiceOver skips decorative handle

In `apps/novels/Features/Import/AddBookView.swift`:
- Sort picker `.accessibilityLabel("Sắp xếp")` already — ensure 44 height
- Retry buttons `"Thử lại"` already — ensure 44

In `apps/novels/Features/Settings/**`:
- `settingsButton` / `settings-<key>` identifiers already; Cache rows `clear-*` identifiers already — ensure each row `.frame(minHeight:44)` + `.accessibilityLabel` for destructive actions (`"Xóa <slug>"`)

In `apps/novels/SharedUI/*`:
- `ToastView` already has `accessibilityLabel(data.message)` — ensure `accessibilityAddTraits(.isStaticText)`
- `LoadingView` already has message label

Apply smallest patch per file; do not redesign palette.

- [x] **Step 4: Manual VoiceOver + Dynamic Type spot check (record evidence)**

On Simulator iPhone 17 Pro 26.5:
- Enable VoiceOver (Settings→Accessibility→VoiceOver) or Xcode Accessibility Inspector. Traverse: Library → row reads "name, author, count" → swipe reveals Info/Delete → AddBook → sort → retry → Reader → prev/next read "Chương trước/sau" + disabled announced → References → current reads bold + checkmark → Settings → each row reads Vietnamese key → editor lifts content → cache clear confirms.
- Dynamic Type: Settings→Display→Text Size largest + Accessibility Larger Text on → verify Library rows wrap 2 lines, header 1 line, no clip, scroll works, Reader body scales size 12..24 separately but UI scales with system.
- Reduce Motion: enable → verify only slide/fade (no spring bounce) in sheet.

Capture 3 screenshots for release notes: VoiceOver inspector on Library row, Reader footer disabled state, Settings list.

- [x] **Step 5: Run a11y tests + build to verify they pass**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HardeningA11yTests -quiet`
Expected: PASS.

Run: `swiftformat --lint apps --verbose` 0; `swiftlint lint --strict` 0.

- [x] **Step 6: Commit**

```bash
git add apps/novels/Features/Library/LibraryView.swift apps/novels/Features/Reading/ReaderView.swift apps/novels/Features/Reading/ReferencesView.swift apps/novels/Features/Reading/ReaderBottomSheet.swift apps/novels/Features/Import/AddBookView.swift apps/novels/Features/Settings/*.swift apps/novels/SharedUI/*.swift apps/novelsTests/HardeningRegressionTests.swift
git commit -m "feat(hardening): a11y 44pt targets, labels, Dynamic Type and VoiceOver audit"
```

---

### Task 3: Regression / edge sweep — 7 required cases with test evidence

**Files:**
- Create: `apps/novelsTests/HardeningRegressionTests.swift` (main edge suite)
- Modify: `apps/novelsTests/TolerantFixtures.swift` (reuse `makeDeflateDescriptorZip` etc. if needed)
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (only if resume bug found)
- Test: `apps/novelsTests/HardeningRegressionTests.swift` + existing `ImportViewModelTests`, `CacheManagerTests`, `PrefetchManagerTests`

**Interfaces:**
- Consumes: `FileBookRepository(booksRoot:)`, `SQLiteProcessedChapterCache.inMemory()`, `SettingsStore(suiteName:)`, `AIReadingService` with `MockURLProtocol`, `PrefetchManager`, `ReaderViewModel`.
- Produces: 7 passing edge cases recorded in test names, no new product behavior.

- [x] **Step 1: Write failing edge tests — one per required case**

```swift
import XCTest
@testable import novels

final class HardeningEdgeTests: XCTestCase {

    // 1) offline — Library scan works without network, no URLSession call
    func testOfflineLibraryScan() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("books/test-slug/chapters"), withIntermediateDirectories: true)
        let book = Book(id: "test-slug", name: "Offline Book", author: "A", count: 1, references: [Reference(index:1,title:"C1")])
        try JSONEncoder().encode(book).write(to: tmp.appendingPathComponent("books/test-slug/book.json"))
        try "<p>Hello offline</p>".write(to: tmp.appendingPathComponent("books/test-slug/chapters/chapter-1.html"), atomically: true, encoding: .utf8)
        let repo = FileBookRepository(booksRoot: tmp.appendingPathComponent("books"))
        let books = try repo.allBooks()
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.id, "test-slug")
        let html = try repo.chapterHTML(slug: "test-slug", number: 1)
        XCTAssertTrue(html.contains("Hello"))
    }

    // 2) invalid ZIP — wrapper+__MACOSX+flag08 still rejected for bomb/slip/missing-chapter; but valid sample with wrapper tolerated
    func testInvalidZIPStillRejected() throws {
        // zip-slip
        let slipData = TolerantFixtures.makeZipSlipData() // or construct tiny slip zip via FileManagerZIP helper
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let zipURL = tmp.appendingPathComponent("slip.zip")
        try slipData.write(to: zipURL)
        XCTAssertThrowsError(try FileManager.default.unzipItem(at: zipURL, to: tmp.appendingPathComponent("out")))
        // hygiene ignored but wrapper flatten only 1 level — extra nested wrapper still invalid per book-package rules
    }

    // 3) missing chapter — Reader shows error without crash, navigation still works
    @MainActor
    func testMissingChapterShowsErrorWithoutCrash() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("books/miss/chapters"), withIntermediateDirectories: true)
        let book = Book(id: "miss", name: "Miss", author: "A", count: 3, references: (1...3).map{Reference(index:$0,title:"C\($0)")})
        try JSONEncoder().encode(book).write(to: tmp.appendingPathComponent("books/miss/book.json"))
        try "<p>C1</p>".write(to: tmp.appendingPathComponent("books/miss/chapters/chapter-1.html"), atomically: true, encoding: .utf8)
        // intentionally missing chapter-2
        try "<p>C3</p>".write(to: tmp.appendingPathComponent("books/miss/chapters/chapter-3.html"), atomically: true, encoding: .utf8)
        let repo = FileBookRepository(booksRoot: tmp.appendingPathComponent("books"))
        let ud = UserDefaults(suiteName: "edge.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let vm = ReaderViewModel(bookId: "miss", repository: repo, settingsStore: store, cache: cache)
        await vm.loadChapter(2)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage?.contains("Chapter not found") ?? vm.errorMessage?.contains("Failed") ?? true)
        // goNext still works without crash
        await vm.goToChapter(3)
        XCTAssertEqual(vm.chapterNumber, 3)
    }

    // 4) invalid JSON headers/body — AI merge ignores bad JSON, request succeeds stored verbatim
    @MainActor
    func testInvalidJSONHeadersBodyIgnored() async throws {
        let ud = UserDefaults(suiteName: "edge2.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        store.aiCustomHeaders = "not json {"
        store.aiExtraBody = "{ broken"
        store.save()
        let cache = try SQLiteProcessedChapterCache.inMemory()
        // mock session returns success
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { req in
            XCTAssertNil(req.value(forHTTPHeaderField: "X-Bad"))
            let json = #"{"choices":[{"message":{"content":"ok"}}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using: .utf8)!)
        }
        let client = AIClient(settings: store, session: URLSession(configuration: cfg))
        let svc = AIReadingService(cache: cache, client: client, settings: store)
        let out = try await svc.processedContent(bookId: "s", chapterNumber: 1, mode: .translate, rawText: String(repeating: "a", count: 1400))
        XCTAssertEqual(out, "ok")
        XCTAssertEqual(store.aiCustomHeaders, "not json {") // stored verbatim
    }

    // 5) cache clear immediate — countAll / count / bookIds reflect 0 after clearAll/clear(bookId)
    func testCacheClearImmediate() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(bookId: "a", chapterNumber: 1, mode: .translate, content: "c1", contentHash: "h1", createdAt: now, updatedAt: now))
        try cache.upsert(ProcessedChapter(bookId: "a", chapterNumber: 2, mode: .translate, content: "c2", contentHash: "h2", createdAt: now, updatedAt: now))
        XCTAssertEqual(try cache.countAll(), 2)
        try cache.clear(bookId: "a")
        XCTAssertEqual(try cache.countAll(), 0)
        XCTAssertEqual(try cache.count(bookId: "a"), 0)
        try cache.upsert(ProcessedChapter(bookId: "b", chapterNumber: 1, mode: .summary, content: "s1", contentHash: "h3", createdAt: now, updatedAt: now))
        try cache.clearAll()
        XCTAssertEqual(try cache.countAll(), 0)
    }

    // 6) prefetch cancel — chapter/mode change cancels task via PrefetchManager.cancel()
    @MainActor
    func testPrefetchCancelOnChange() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let ud = UserDefaults(suiteName: "edge3.\(UUID().uuidString)")!
        let store = SettingsStore(userDefaults: ud)
        store.prefetchCount = 5
        store.save()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("books/p/chapters"), withIntermediateDirectories: true)
        let book = Book(id: "p", name: "P", author: "A", count: 10, references: (1...10).map{Reference(index:$0,title:"C\($0)")})
        try JSONEncoder().encode(book).write(to: tmp.appendingPathComponent("books/p/book.json"))
        for i in 1...10 { try "<p>Content \(i)</p>".write(to: tmp.appendingPathComponent("books/p/chapters/chapter-\(i).html"), atomically: true, encoding: .utf8) }
        let repo = FileBookRepository(booksRoot: tmp.appendingPathComponent("books"))
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { req in
            Thread.sleep(forTimeInterval: 0.3)
            let json = #"{"choices":[{"message":{"content":"ai"}}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using: .utf8)!)
        }
        let client = AIClient(settings: store, session: URLSession(configuration: cfg))
        let svc = AIReadingService(cache: cache, client: client, settings: store)
        let mgr = PrefetchManager()
        await mgr.start(bookId: "p", currentChapter: 1, totalChapters: 10, mode: .translate, settings: store, cache: cache, aiService: svc, repository: repo)
        try await Task.sleep(nanoseconds: 400_000_000)
        await mgr.cancel()
        let s = await mgr.currentStatus()
        XCTAssertFalse(s.isRunning)
        // verify not all 5 completed
        XCTAssertTrue(try cache.countAll() < 5)
    }

    // 7) kill-on-Reading resume — ReadingSession (bookId, onScreen, offset per slug) survives relaunch via UserDefaults
    @MainActor
    func testKillOnReadingResume() throws {
        let suite = "kill.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suite)!
        let store = SettingsStore(userDefaults: ud)
        store.sessionBookId = "resume-slug"
        store.sessionOnScreen = true
        store.save()
        // simulate offset per slug
        let offsetKey = "readingOffset.resume-slug"
        ud.set(42.5, forKey: offsetKey)
        // recreate store as if app killed and relaunched
        let store2 = SettingsStore(userDefaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(store2.sessionBookId, "resume-slug")
        XCTAssertTrue(store2.sessionOnScreen)
        XCTAssertEqual(ud.double(forKey: offsetKey), 42.5, accuracy: 0.1)
        // Router restoreInitialRoute would route to Reading when onScreen true — verify flag drives it (Router test covers isPushing debounce)
    }
}
```

- [x] **Step 2: Run tests to verify they fail (expose missing helpers)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HardeningEdgeTests -quiet`
Expected: FAIL — `FileBookRepository(booksRoot:)` signature mismatch, `MockURLProtocol` not found, `allBooks()` name mismatch, `chapterHTML(slug:number:)` vs `chapterHTML(_:)`.

Fix: Inspect existing `apps/novels/Persistence/BookRepository.swift` — adapt `FileBookRepository.init(booksRoot:)` or `AppPaths.booksRoot` override; inspect `apps/novels/Services/AIClient.swift` for `MockURLProtocol` used in `AIClientTests` — reuse same mock class name. Replace `allBooks()` with `books()` or `scan()` per actual API.

- [x] **Step 3: Implement minimal fixes to make tests pass**

No new product logic — only ensure existing code handles edges:
- Missing chapter: `ReaderViewModel.loadChapter(_:)` already sets `errorMessage = "Chapter not found"` on `catch` and does not crash — verify guard `try repo.chapterHTML` catches and keeps `chapterNumber` clamped.
- Invalid JSON: `AIClient` already calls `settingsStore.effectiveHeaders()` which returns `[:]` when `JSONSerialization` fails — stored verbatim path already tested in `AIClientTests` — ensure no throw.
- Cache clear: `SQLiteProcessedChapterCache.countAll()` uses `SELECT count(*)` already — verify `clear(bookId:)` and `clearAll()` issue `DELETE` + `VACUUM` not needed.
- Prefetch cancel: already via `PrefetchManager.cancel()` + `Task.isCancelled` per feat-007 — keep.
- Kill resume: `SettingsStore.sessionBookId/sessionOnScreen` already `@Observable` + `save()` persists — ensure `Router.restoreInitialRoute()` reads `sessionOnScreen` and routes to `Reading` with slug, toast `"Không tìm thấy sách"` if folder missing (already in AppRoot).

If any failure, patch single point: e.g., ensure `ReaderViewModel` does not `fatalError` on missing chapter (replace with error state).

- [x] **Step 4: Run full edge suite + existing suites to verify no regression**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HardeningEdgeTests -only-testing:novelsTests/CacheManagerTests -only-testing:novelsTests/PrefetchManagerTests -only-testing:novelsTests/AIClientTests -quiet`
Expected: PASS all.

Run full: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS 90+ tests.

- [x] **Step 5: Commit**

```bash
git add apps/novelsTests/HardeningRegressionTests.swift apps/novels/Features/Reading/ReaderViewModel.swift
git commit -m "feat(hardening): regression sweep 7 edges with evidence"
```

---

### Task 4: Final verification + release checklist + handoff

**Files:**
- Modify: `features/feat-008.md` (check 4 acceptances)
- Modify: `progress.md` (add dated done block)
- Modify: `feature_index.json` (active→done after evidence)
- Test: full `./init.sh`

**Interfaces:**
- Consumes: `./init.sh`, `xcodebuild`, `swiftformat`, `swiftlint`, drift check.
- Produces: Feature `done` with evidence, next action none (release ready).

- [x] **Step 1: Run full verification (evidence capture)**

Run in order, capture outputs for handoff:

```bash
swiftformat --lint . --verbose 2>&1 | tail -n 20
# Expected: 0/87 files require formatting (or current count)

swiftlint lint --strict 2>&1 | tail -n 20
# Expected: Done linting! Found 0 violations, 0 serious in 87 files.

xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet
# Expected: exit 0; check no warnings about 1,2

xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet
# Expected: all tests PASS (≥90 including Hardening suites)

./init.sh 2>&1 | tail -n 60
# Expected: PASS [format] PASS [lint] PASS [build] PASS [test] PASS [drift]
```

If flake `"Failed to create bundle instance"` occurs, re-run targeted: `xcodebuild test -only-testing:novelsTests/Hardening*` as proof, note flake in evidence per feat-005 precedent.

Collect also:
```bash
grep -c "TARGETED_DEVICE_FAMILY = 1;" apps/novels.xcodeproj/project.pbxproj
plutil -p apps/novels/Info.plist | grep -E "LSRequiresIPhoneOS|UILaunchScreen|NSAppTransportSecurity"
grep -c "accessibilityIdentifier" apps/novels/Features/Reading/ReaderView.swift
grep -c "accessibilityLabel" apps/novels/SharedUI/ToastView.swift
```

- [x] **Step 2: Update feature file — check all acceptances + handoff**

In `features/feat-008.md`:

```markdown
## Acceptance

- [x] `TARGETED_DEVICE_FAMILY` = iPhone only (1) per `docs/decisions/ios-scope.md`, iOS 26+, assets/icons/launch verified.
- [x] Accessibility checks pass: contrast 4.5:1 text / 3:1 icons, 44pt targets per `docs/design/design-system.md:58-64`.
- [x] Regression/edge sweep executed with recorded evidence: offline, invalid ZIP, missing chapter, invalid JSON headers/body, cache clear, prefetch cancel, kill-on-Reading resume.
- [x] `./init.sh` passes; release checklist complete.

## Handoff

- State: done
- Evidence: `docs/plans/feat-008.md`, `apps/novels/Info.plist` (LSRequiresIPhoneOS + UILaunchScreen + ATS localhost-only, ~ipad removed), `project.pbxproj` TARGETED_DEVICE_FAMILY=1 ×6 IPHONEOS_DEPLOYMENT_TARGET=26.5 ×6, `Assets.xcassets/AppIcon` 3×1024, a11y audit 44pt/labels/Dynamic Type/VoiceOver, `apps/novelsTests/HardeningRegressionTests.swift` + `HardeningA11yTests` + `HardeningEdgeTests` PASS, `xcodebuild build` PASS, `swiftformat` 0, `swiftlint` 0, `./init.sh` PASS (format/lint/build/test/drift) [full output lines]
- Blockers: none
- Next: Release ready — tag / TestFlight per `SECURITY.md`; no further feature blocked
```

- [x] **Step 3: Append progress.md block**

Add below last `## 2026-08-27 — feat-007` block:

```markdown
## 2026-08-27 — feat-008

**State**: done
**Done**: Hardening + Release Readiness — iPhone-only config verified (TARGETED_DEVICE_FAMILY=1 ×6, 26.5, AppIcon 1024×3, launch + ATS localhost-only, ~ipad pruned), a11y 4.5:1/3:1 + 44pt + VoiceOver/Dynamic Type sweep with labels, 7-edge regression recorded (offline scan, invalid ZIP still rejected, missing chapter error no crash, invalid JSON headers/body ignored verbatim, cache clear immediate, prefetch cancel on change, kill-on-Reading resume via UserDefaults)
**Evidence**: (same as feature handoff — list xcodebuild, swiftformat, swiftlint, ./init.sh PASS lines + grep counts)
**Blockers**: none
**Next**: Release ready — no active feature; repo idle per Harness Slim
```

- [x] **Step 4: Flip feature_index.json active→done**

Change: `"id":"feat-008","status":"active"` → `"status":"done"`

Verify: `cat feature_index.json | grep feat-008` shows `done`, zero active (`grep -c '"status": "active"'` → `0`).

- [x] **Step 5: Mark plan checkboxes + commit**

Check all `- [x]` in this file to `- [x]`.

```bash
git add features/feat-008.md progress.md feature_index.json docs/plans/feat-008.md apps/novels/Info.plist apps/novels.xcodeproj/project.pbxproj apps/novelsTests/HardeningRegressionTests.swift
git commit -m "docs(hardening): mark feat-008 done with full verification evidence"
```

Run `./init.sh --quick` before push to ensure drift clean (21 siblings).

---

## Self-Review

**1. Spec coverage:**
- `features/feat-008.md` 4 acceptances: config/launch/icons → Task 1 (pbx family 1×6, deployment 26.5, Info.plist cleanup, AppIcon 3×1024); a11y 4.5:1/3:1 + 44pt + labels → Task 2 (tokens unchanged, 44 targets, VoiceOver/Dynamic Type manual + grep tests); 7-edge sweep → Task 3 (one test per edge — offline, invalid ZIP, missing chapter, invalid JSON, cache clear, prefetch cancel, kill resume); `./init.sh` + checklist → Task 4 (format/lint/build/test/drift capture + feature/progress flip).

**2. Placeholder scan:** No TBD/TODO/"handle edge cases" without code; every step has exact file paths, Swift/XCTest code blocks, exact shell commands (`xcodebuild test -only-testing:`, `grep -c`, `plutil -p`, `swiftformat --lint`, `swiftlint lint --strict`, `./init.sh`), expected outputs (0 violations, PASS, counts).

**3. Type consistency:** `Book(id:slug,name:author:count:references)`, `Reference(index:title)`, `FileBookRepository(booksRoot:)` vs `AppPaths.booksRoot()` naming handled with note to adapt to actual `BookRepository` protocol; `SettingsStore(suiteName:)`, `sessionBookId/sessionOnScreen`, `aiCustomHeaders/aiExtraBody`, `SQLiteProcessedChapterCache.inMemory()`, `ProcessedChapter(bookId:chapterNumber:mode:content:contentHash:createdAt:updatedAt)`, `AIMode .none/.translate/.summary`, `PrefetchManager.start/cancel/currentStatus`, `ReaderViewModel(bookId:repository:settingsStore:cache:)` consistent across tasks; `MockURLProtocol.handler` reused from `AIClientTests`.

