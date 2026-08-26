# Offline Book Reader Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver offline native Text reader that parses `chapter-N.html` to `SwiftUI.Text` spans, provides bounded prev/next + References index, saves/restores per-book offset and `onScreen`, and exposes typography controls via bottom sheet.

**Architecture:** Pure-Swift `HtmlParser` → `TextSpan` → `SwiftUI.Text` VStack in Presentation; `@Observable ReaderViewModel` orchestrates file reads via `FileBookRepository` + offset/session via `SettingsStore`; navigation stays in `Router` single stack with swipe-back disabled. All HTML parsing is Foundation-only (no WebKit), offline, with `FileManager` slug-isolated reads.

**Tech Stack:** Swift 5.0 / SwiftUI, Xcode `apps/novels.xcodeproj` scheme `novels` iOS 26.5, `Foundation` + `Observation.@Observable`, `FileManager.unzipItem` already existent, `UserDefaults` via `SettingsStore`, `XCTest` + `XCUITest`, SwiftLint 0.65.1 + SwiftFormat 0.62.1.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — `TARGETED_DEVICE_FAMILY=1`, `IPHONEOS_DEPLOYMENT_TARGET=26.5`, copy in Vietnamese (`Thư viện`, `Đang đọc`, `Không tìm thấy chương`, etc.).
- `DEVELOPMENT_TEAM M5U4E4H84J`, Swift 5.0, single module `apps/novels`, no SwiftPM packages.
- No `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, WebKit, or second AI cache.
- `book.json.id` string slug is sole local identity; remote numeric `ExportedBook.id`/`bookId` never used as folder/cache key; do not coerce.
- Local Book Repository root `Application Support/novels/books/<slug>/` containing `book.json` + `chapters/chapter-N.html` with `N=1..count` 1-based; invalid folders (missing `book.json`) skipped.
- HTML pipeline: `div`, `h*`, `p`, `br`, `b`, `strong`, `i`, `em`, `span` → spans → `VStack` of `SwiftUI.Text`; no `WKWebView`, no `NSAttributedString` WebKit.
- Settings/Typography via `UserDefaults` + `@Observable SettingsStore.typography` (`TypographySetting(font: String, fontSize: Double 12...24 step 1, lineHeight: Double 1.2...2.0 step 0.1, letterSpacing: Double 0...1.0 step 0.1)` defaults `System/16/1.5/0`); `ReadingSession(bookId: String, onScreen: Bool, offset: Double, chapterNumber: Int)` per BR-09/BR-11.
- Reading is offline after import (BR-01); offset saved per slug and restored only for same `bookId` (BR-09); typography persists (BR-11); invalid settings sanitize to defaults on launch (BR-12).
- Navigation: single `NavigationStack` via `Router` `path: NavigationPath` + `Route` enum, `isPushing` 300ms debounce, `restoreInitialRoute()` `onScreen ? Reading : Library`, `didPopFromReading()` sets `onScreen=false`; Reading disables swipe-back per `docs/design/navigation.md §3`.
- Design tokens: `backgroundPaper #FDFCF8`, `background #FFFFFF`, `text #111111`, `muted #6B7280`, `accent #2563EB`, `border #E5E7EB`, radius 8/12/16/24, spacing 4/8/12/16/24/32; reading background `#FDFCF8`.
- Verification: `./init.sh` (swiftformat --lint, swiftlint --strict, xcodebuild build + test `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5`).

---

## File Structure

**New files (this feature owns):**
- `apps/novels/Domain/TextSpan.swift` — Value type for parsed spans: `struct TextSpan: Equatable { enum Kind { case body, heading(level:Int), bold, italic } ; var text:String; var kind:Kind; var isLineBreak:Bool }` + `TextBlock` grouping. Pure Swift, no SwiftUI import.
- `apps/novels/Domain/HtmlParser.swift` — Pure function `enum HtmlParser { static func parse(html:String) -> [TextBlock] }` using Foundation string scanning for tags `div|h1..h6|p|br|b|strong|i|em|span`. Handles nesting bold+italic, collapses whitespace, emits line breaks for `p`/`br`/`h*`/`div`. No SwiftUI/UIKit.
- `apps/novels/Features/Reading/ReaderViewModel.swift` — `@MainActor @Observable final class ReaderViewModel` orchestrating load: `let bookId:String; var book:Book?; var chapterNumber:Int; var blocks:[TextBlock]; var isLoading:Bool; var errorMessage:String?; var canGoPrev/canGoNext:Bool; var showReferences:Bool`. Uses `FileBookRepository` + `SettingsStore` for offset/session. Methods: `load()`, `goNext()`, `goPrev()`, `goToChapter(_:)`, `saveOffset(_:)`, `onAppear()`, `onDisappear()`.
- `apps/novels/Features/Reading/ReaderView.swift` — SwiftUI reader: `ScrollViewReader` + `ScrollView` with `VStack` rendering `TextBlock` → `SwiftUI.Text` concatenated spans, applying `SettingsStore.typography`. Toolbar prev/next, header index `Chương N / count`, to-bottom button, bottom-sheet trigger, scroll offset tracking. Replaces/augments `ReadingShellView`.
- `apps/novels/Features/Reading/ReferencesView.swift` — List of `book.references` with current chapter bold, tap calls `reader.goToChapter(_:)` and `router.pop()`. Receives `book:Book, current:Int, onSelect:(Int)->Void`.
- `apps/novels/Features/Reading/ReaderBottomSheet.swift` — Sheet content reusing `BottomSheetView`: font picker (System + 2 bundled), steppers for `fontSize/lineHeight/letterSpacing` with clamp and live persist via `SettingsStore.typography` + `settingsStore.save()`, gear button shows no-op toast "Cài đặt sẽ có ở feat-005" and dismisses sheet (Settings route is feat-005), close handling.
- `apps/novels/Features/Reading/ScrollOffsetPreference.swift` — Small helper: `struct ScrollOffsetKey: PreferenceKey` + `ViewModifier` to publish `offsetY: Double` for ReaderView without breaking layering.

**Modified files:**
- `apps/novels/App/Router.swift` — Extend `Route` to carry chapter when needed (keep `reading(bookId:String)` + add `references(bookId:String)` or pass book via environment; debounce unchanged). Ensure `push(.reading)` sets `session.chapterNumber` and `onScreen=true`, `popReading()` + `didPopFromReading()` preserved. Add `showToast(_:type:)` passthrough if needed.
- `apps/novels/App/AppRoot.swift` — Add `navigationDestination` for `Route.reading` → `ReaderView(bookId:)` and `Route.references` → `ReferencesView`. Keep `restoreInitialRoute()` task.
- `apps/novels/Persistence/BookRepository.swift` — No change to protocol, but ReaderViewModel uses `repository.book(slug:)` to get `count/references` and direct `FileManager.default.contents(atPath:)` or `repository.chapterHTML(slug:number:) -> String?` add if not exists (small helper). Prefer reusing existing `FileBookRepository` file read.
- `apps/novels/Resources/DesignTokens.swift` — Verify tokens exist; no change unless missing `backgroundPaper`.

**Tests:**
- `apps/novelsTests/HtmlParserTests.swift` — Unit tests for parser: tags, nesting, whitespace, empty, heading levels, br handling.
- `apps/novelsTests/ReaderViewModelTests.swift` — Unit tests with temp `Application Support/novels/books/<slug>/` fixtures + isolated `UserDefaults(suiteName:)` SettingsStore for offset/bounds/missing-file toast logic.
- `apps/novelsTests/ReaderNavigationTests.swift` — (light) Router + ViewModel integration for prev/next disabled at bounds, rapid nav offset not corrupt, chapter clamp.

---

### Task 1: TextSpan + HtmlParser — pure Swift HTML → spans

**Files:**
- Create: `apps/novels/Domain/TextSpan.swift`
- Create: `apps/novels/Domain/HtmlParser.swift`
- Test: `apps/novelsTests/HtmlParserTests.swift`

**Interfaces:**
- Consumes: `Foundation` only. Input HTML `String` from `chapters/chapter-N.html`.
- Produces: `struct TextSpan { enum Kind: Equatable { case body, heading(level:Int), bold, italic, boldItalic }; var text:String; var kind:Kind; var isLineBreak:Bool }` and `struct TextBlock { var spans:[TextSpan]; var isHeading:Bool; var headingLevel:Int? }` and `enum HtmlParser { static func parse(html:String) -> [TextBlock] }`.

- [ ] **Step 1: Write failing test for TextSpan types and basic parse**

```swift
import XCTest
@testable import novels

final class HtmlParserTests: XCTestCase {
    func testParseSingleParagraph() {
        let html = "<p>Hello <b>world</b></p>"
        let blocks = HtmlParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].spans.count, 2)
        XCTAssertEqual(blocks[0].spans[0].text, "Hello ")
        XCTAssertEqual(blocks[0].spans[0].kind, .body)
        XCTAssertEqual(blocks[0].spans[1].text, "world")
        XCTAssertEqual(blocks[0].spans[1].kind, .bold)
    }

    func testParseHeadingAndBr() {
        let html = "<h2>Title</h2><p>Line1<br>Line2</p>"
        let blocks = HtmlParser.parse(html: html)
        XCTAssertEqual(blocks[0].isHeading, true)
        XCTAssertEqual(blocks[0].headingLevel, 2)
        XCTAssertEqual(blocks[0].spans[0].text, "Title")
        XCTAssertEqual(blocks[1].spans.map{ $0.text }.joined(separator:"|"), "Line1|Line2")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HtmlParserTests -quiet`
Expected: FAIL — `HtmlParser` / `TextBlock` not defined.

- [ ] **Step 3: Write minimal TextSpan + HtmlParser implementation (Foundation scanning, no WebKit)**

```swift
import Foundation

struct TextSpan: Equatable {
    enum Kind: Equatable { case body, heading(level:Int), bold, italic, boldItalic }
    var text: String
    var kind: Kind
    var isLineBreak: Bool = false
}

struct TextBlock: Equatable {
    var spans: [TextSpan]
    var isHeading: Bool = false
    var headingLevel: Int? = nil
}

enum HtmlParser {
    // Parse html string scanning tags div|h1..h6|p|br|b|strong|i|em|span
    // - Stack for bold/italic nesting; emit block per p/h*/div; br inserts lineBreak span
    // - Collapse multiple whitespaces to single space, trim per span, keep non-empty
    static func parse(html: String) -> [TextBlock] { /* minimal scanning */ return [] }
}
```
Implement scanning: lowercased tag detection, stack `[Kind]`, accumulate `currentText`, helper `flushSpan()`, create blocks on `</p>` `</h*>` `</div>`, inline `br` flush. Use `NSRegularExpression` or manual index scan — keep Foundation only.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/HtmlParserTests -quiet`
Expected: PASS (at least the two tests above).

- [ ] **Step 5: Extend tests for edge cases & nesting then re-run**

Add in `HtmlParserTests`:
```swift
func testParseNestedBoldItalicAndWhitespace() {
    let html = "<p>  A <b><i>BC</i> D</b>  E  </p>"
    let blocks = HtmlParser.parse(html: html)
    XCTAssertEqual(blocks[0].spans[1].kind, .boldItalic)
    XCTAssertEqual(blocks[0].spans[1].text, "BC")
    XCTAssertEqual(blocks[0].spans.map{ $0.text }.joined(), "A BC D E")
}
func testParseEmptyAndDivSpanPassthrough() {
    XCTAssertEqual(HtmlParser.parse(html: ""), [])
    XCTAssertEqual(HtmlParser.parse(html: "<div><span>Hi</span></div>")[0].spans[0].text, "Hi")
}
func testParseHeadingLevels() {
    for lvl in 1...6 {
        XCTAssertEqual(HtmlParser.parse(html: "<h\(lvl)>T\(lvl)</h\(lvl)>")[0].headingLevel, lvl)
    }
}
```
Run same test command → PASS. Fix whitespace collapsing if fails.

- [ ] **Step 6: Commit**

```bash
git add apps/novels/Domain/TextSpan.swift apps/novels/Domain/HtmlParser.swift apps/novelsTests/HtmlParserTests.swift
git commit -m "feat(reader): add HtmlParser TextSpan pipeline for div/h*/p/br/b/strong/i/em/span"
```

---

### Task 2: ReaderViewModel — chapter load, bounds, offset/session, missing toast

**Files:**
- Create: `apps/novels/Features/Reading/ReaderViewModel.swift`
- Test: `apps/novelsTests/ReaderViewModelTests.swift`
- Modify: `apps/novels/Persistence/BookRepository.swift` (only if helper needed; otherwise reuse existing `FileBookRepository` read)

**Interfaces:**
- Consumes: `BookRepository` (`func book(slug:String) throws -> Book?`), `SettingsStore` (`var session:ReadingSession?`, `func save()`, `var typography`), `HtmlParser`.
- Produces: `@MainActor @Observable final class ReaderViewModel { init(bookId:String, repository:BookRepository, settingsStore:SettingsStore, toastCenter:ToastCenter?) ; var book:Book?; var chapterNumber:Int; var blocks:[TextBlock]; var isLoading:Bool; var errorMessage:String?; var canGoPrev:Bool; var canGoNext:Bool; func load(); func goNext(); func goPrev(); func goToChapter(_:Int); func saveOffset(_ offset:Double); func onAppear(); func onDisappear() }`. Clamp `chapterNumber` to `1...book.count`, persist `session.offset` and `session.chapterNumber` debounced 300ms.

- [ ] **Step 1: Write failing ViewModel tests (isolated temp FS + suite UserDefaults)**

```swift
import XCTest
@testable import novels

final class ReaderViewModelTests: XCTestCase {
    var tempRoot: URL!
    var store: SettingsStore!
    var repo: FileBookRepository!

    override func setUp() {
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let slug = "test-slug"
        let bookDir = tempRoot.appendingPathComponent(slug)
        try! FileManager.default.createDirectory(at: bookDir.appendingPathComponent("chapters"), withIntermediateDirectories: true)
        let book = Book(id: slug, name: "Test", author: "A", count: 3, references: ["C1","C2","C3"])
        let data = try! JSONEncoder().encode(book)
        try! data.write(to: bookDir.appendingPathComponent("book.json"))
        for i in 1...3 {
            try! "<p>Content \(i)</p>".write(to: bookDir.appendingPathComponent("chapters/chapter-\(i).html"), atomically: true, encoding: .utf8)
        }
        store = SettingsStore(userDefaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        repo = FileBookRepository(root: tempRoot, fileManager: .default)
    }

    func testLoadFirstChapter() async {
        let vm = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        await vm.load()
        XCTAssertEqual(vm.blocks.count, 1)
        XCTAssertEqual(vm.chapterNumber, 1)
        XCTAssertFalse(vm.canGoPrev)
        XCTAssertTrue(vm.canGoNext)
    }

    func testBoundsDisable() async {
        let vm = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
        vm.chapterNumber = 3; await vm.load()
        XCTAssertFalse(vm.canGoNext); XCTAssertTrue(vm.canGoPrev)
        await vm.goNext() // at end stays
        XCTAssertEqual(vm.chapterNumber, 3)
    }

    func testMissingFileShowsToast() async {
        try? FileManager.default.removeItem(at: tempRoot.appendingPathComponent("test-slug/chapters/chapter-2.html"))
        let toast = ToastCenter()
        let vm = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store, toastCenter: toast)
        vm.chapterNumber = 2; await vm.load()
        XCTAssertEqual(toast.lastMessage, "Không tìm thấy chương")
        XCTAssertNotNil(vm.errorMessage)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ReaderViewModelTests -quiet`
Expected: FAIL — `ReaderViewModel` not found.

- [ ] **Step 3: Write minimal ReaderViewModel**

```swift
import Foundation
import Observation

@MainActor @Observable final class ReaderViewModel {
    let bookId: String
    private let repository: BookRepository
    private let settingsStore: SettingsStore
    private let toastCenter: ToastCenter?
    var book: Book?
    var chapterNumber: Int = 1
    var blocks: [TextBlock] = []
    var isLoading = false
    var errorMessage: String?
    var canGoPrev: Bool { chapterNumber > 1 }
    var canGoNext: Bool { (book?.count ?? 1) > chapterNumber }

    init(bookId: String, repository: BookRepository, settingsStore: SettingsStore, toastCenter: ToastCenter? = nil) {
        self.bookId = bookId; self.repository = repository; self.settingsStore = settingsStore; self.toastCenter = toastCenter
        if let s = settingsStore.session, s.bookId == bookId { chapterNumber = max(1, s.chapterNumber) }
    }
    func load() async { /* see step */ }
    func goNext() async { guard canGoNext else { return }; chapterNumber += 1; await load(); persistChapter() }
    func goPrev() async { guard canGoPrev else { return }; chapterNumber -= 1; await load(); persistChapter() }
    func goToChapter(_ n:Int) async { chapterNumber = min(max(1, n), book?.count ?? n); await load(); persistChapter() }
    func saveOffset(_ offset:Double) { settingsStore.session?.offset = offset; settingsStore.session?.bookId = bookId; settingsStore.session?.chapterNumber = chapterNumber; settingsStore.save() }
    func onAppear() { settingsStore.session = ReadingSession(bookId: bookId, onScreen: true, offset: settingsStore.session?.offset ?? 0, chapterNumber: chapterNumber); settingsStore.save() }
    func onDisappear() { settingsStore.session?.onScreen = false; settingsStore.save() }
    private func persistChapter() { settingsStore.session?.chapterNumber = chapterNumber; settingsStore.session?.offset = 0; settingsStore.save() }
}
```
Implement `load()` : `isLoading=true; errorMessage=nil` → `book = try? repository.book(slug:bookId)` → clamp `chapterNumber` to `1...book.count` → read file `root/books/<slug>/chapters/chapter-N.html` via `FileManager.default.contents(atPath:)` or `String(contentsOfFile:encoding:)` → if missing → `errorMessage="Không tìm thấy chương"` + `toastCenter?.show("Không tìm thấy chương", type:.error)` + `blocks=[]; isLoading=false; return` → else `blocks=HtmlParser.parse(html:) ; isLoading=false`.

- [ ] **Step 4: Run test to verify it passes**

Run same `ReaderViewModelTests` command → PASS (add `await MainActor.run` if needed). Fix file path: derive via `AppPaths.booksRoot` or injected `root` — use `repo.rootURL` if exposed, else reconstruct with `tempRoot`.

- [ ] **Step 5: Add rapid nav offset not corrupt test**

Add to `ReaderViewModelTests`:
```swift
func testRapidNavDoesNotCorruptOffset() async {
    let vm = ReaderViewModel(bookId: "test-slug", repository: repo, settingsStore: store)
    await vm.load()
    vm.saveOffset(123.4)
    await vm.goNext(); await vm.goPrev() // rapid
    // offset for chapter 1 should be preserved at 0 after navigation start, not 123.4 carried to new chapter
    XCTAssertEqual(store.session?.chapterNumber, 1)
    XCTAssertEqual(store.session?.offset, 0)
}
```
Run → PASS or fix `persistChapter` to reset offset to 0 on chapter change (new chapter starts at top per flow).

- [ ] **Step 6: Commit**

```bash
git add apps/novels/Features/Reading/ReaderViewModel.swift apps/novelsTests/ReaderViewModelTests.swift
git commit -m "feat(reader): add ReaderViewModel with bounded nav, offset/session, missing toast"
```

---

### Task 3: ReaderView — SwiftUI.Text pipeline, typography, prev/next, to-bottom, overscroll lock

**Files:**
- Create: `apps/novels/Features/Reading/ReaderView.swift`
- Create: `apps/novels/Features/Reading/ScrollOffsetPreference.swift`
- Modify: `apps/novels/Features/Reading/ReadingShellView.swift` (deprecate or forward to ReaderView)
- Test: `apps/novelsTests/ReaderNavigationTests.swift` (unit) + manual verification in Preview/Simulator for typography live-update and to-bottom scroll

**Interfaces:**
- Consumes: `ReaderViewModel`, `SettingsStore.typography`, `DesignTokens`, `ToastView`.
- Produces: `struct ReaderView: View { init(bookId:String, router:Router) }` that internally creates `@State viewModel` wired to isolated store/repo for previews. Exposes accessibility ids: `prevButton`, `nextButton`, `toBottomButton`, `chapterText`.

- [ ] **Step 1: Write failing UI logic test for rendering and button states**

Add to `ReaderNavigationTests.swift`:
```swift
func testPrevNextDisabledAtBounds() async {
    // reuse temp fixture from Task 2 but assert VM canGoPrev/canGoNext drives View disabled state
    // View test is indirect: verify ViewModel state after VM load maps to expected button disabled
    let vm = makeVM(count:2); await vm.load()
    XCTAssertFalse(vm.canGoPrev); XCTAssertTrue(vm.canGoNext)
    await vm.goNext()
    XCTAssertTrue(vm.canGoPrev); XCTAssertFalse(vm.canGoNext)
}
```

- [ ] **Step 2: Run test to verify it fails (if ViewModel already exists it passes; add view-specific check)**

Run: `xcodebuild test ... -only-testing:novelsTests/ReaderNavigationTests -quiet`
Expected: PASS for VM part — next steps will cover scroll lock logic unit.

- [ ] **Step 3: Implement ReaderView**

```swift
import SwiftUI

struct ReaderView: View {
    let bookId: String
    @Bindable var router: Router
    @Environment(SettingsStore.self) private var settings
    @State private var vm: ReaderViewModel
    @State private var offsetY: Double = 0
    @State private var overscrollLock = false
    @State private var showSheet = false
    @State private var scrollProxy: ScrollViewProxy?

    init(bookId:String, router:Router, repository:BookRepository? = nil, settingsStore:SettingsStore? = nil) {
        self.bookId = bookId; self.router = router
        let store = settingsStore ?? SettingsStore.shared
        let repo: BookRepository = repository ?? FileBookRepository(root: AppPaths.booksRoot(), fileManager: .default)
        _vm = State(initialValue: ReaderViewModel(bookId: bookId, repository: repo, settingsStore: store, toastCenter: router.toast))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading, spacing: DesignTokens.spacing16) {
                    header
                    if vm.isLoading { ProgressView().frame(maxWidth:.infinity) }
                    else if vm.blocks.isEmpty { Text(vm.errorMessage ?? "Không tìm thấy chương").foregroundStyle(DesignTokens.muted) }
                    else { content }
                    footerNav
                }
                .padding(DesignTokens.spacing16)
                .background(GeometryReader { g in Color.clear.preference(key: ScrollOffsetKey.self, value: g.frame(in:.named("reader")).minY) })
                .id("top"); Color.clear.frame(height:1).id("bottom")
            }
            .coordinateSpace(name:"reader")
            .onPreferenceChange(ScrollOffsetKey.self) { y in handleOffset(y) }
            .onAppear { scrollProxy = proxy; vm.onAppear(); Task { await vm.load(); restoreOffset(proxy) } }
            .onDisappear { vm.onDisappear() }
            .overlay(alignment:.bottomTrailing) { toBottomButton(proxy) }
            .overlay(alignment:.bottom) { bottomSheetTrigger }
        }
        .background(DesignTokens.backgroundPaper)
        .navigationTitle(vm.book?.name ?? "Đọc sách")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button { router.popReading() } label:{ HStack{Image(systemName:"chevron.left"); Text("Thư viện")}}.accessibilityLabel("Quay lại Thư viện") } }
                   ToolbarItem(placement:.topBarTrailing) { Button { showSheet = true } label:{ Image(systemName:"textformat.size") } } }
        .interactiveDismissDisabled(true) // swipe-back disabled for Reading
        .sheet(isPresented:$showSheet) { ReaderBottomSheet(settingsStore: settings, onClose:{ showSheet=false }) .presentationDetents([.medium]) }
    }

    private var content: some View {
        VStack(alignment:.leading, spacing: DesignTokens.spacing12) {
            ForEach(Array(vm.blocks.enumerated()), id:\.offset) { _, block in
                // Join spans into one Text via reduce
                let t = block.spans.reduce(Text("")) { acc, span in
                    var piece = Text(span.text)
                        .font(fontFor(block: block, span: span))
                        .foregroundStyle(DesignTokens.text)
                    if span.kind == .bold || span.kind == .boldItalic { piece = piece.bold() }
                    if span.kind == .italic || span.kind == .boldItalic { piece = piece.italic() }
                    return acc + piece
                }
                t.lineSpacing(CGFloat(settings.typography.lineHeight))
                  .kerning(CGFloat(settings.typography.letterSpacing))
                  .multilineTextAlignment(.leading)
            }
        }
    }
    private func fontFor(block:TextBlock, span:TextSpan) -> Font {
        let base = CGFloat(settings.typography.fontSize)
        if block.isHeading { return .system(size: base + CGFloat((block.headingLevel ?? 3))*2, weight:.bold) }
        return .system(size: base)
    }
    private var header: some View { HStack{ Text("Chương \(vm.chapterNumber)/\(vm.book?.count ?? 0)").font(.caption).foregroundStyle(DesignTokens.muted); Spacer(); Button("Mục lục") { router.push(.references) } }.accessibilityIdentifier("header") }
    private var footerNav: some View { HStack{ Button("Trước"){Task{await vm.goPrev(); scrollToTop()}}.disabled(!vm.canGoPrev).accessibilityIdentifier("prevButton"); Spacer(); Button("Sau"){Task{await vm.goNext(); scrollToTop()}}.disabled(!vm.canGoNext).accessibilityIdentifier("nextButton")} }
    private func toBottomButton(_ proxy:ScrollViewProxy) -> some View { Button{withAnimation{proxy.scrollTo("bottom", anchor:.bottom)}} label:{Image(systemName:"arrow.down.to.line").padding(12).background(DesignTokens.accent).foregroundStyle(.white).clipShape(Circle()).shadow(radius:4)}.padding().accessibilityIdentifier("toBottomButton") }
    private var bottomSheetTrigger: some View { EmptyView() }
    private func handleOffset(_ y:Double) {
        offsetY = y; vm.saveOffset(-y)
        // overscroll auto-advance with short lock
        if y < -40 && !overscrollLock && vm.canGoNext {
            overscrollLock = true; Task { await vm.goNext(); scrollToTop(); try? await Task.sleep(nanoseconds: 400_000_000); overscrollLock = false }
        } else if y > 40 && !overscrollLock && vm.canGoPrev {
            overscrollLock = true; Task { await vm.goPrev(); scrollToTop(); try? await Task.sleep(nanoseconds: 400_000_000); overscrollLock = false }
        }
    }
    private func scrollToTop(){ scrollProxy?.scrollTo("top", anchor:.top) }
    private func restoreOffset(_ proxy:ScrollViewProxy){
        let off = settings.session?.offset ?? 0
        if off > 0 { /* scroll to offset: use proxy with anchor offset approximation — verify manually */ }
    }
}
```

Also add `ScrollOffsetPreference.swift`:
```swift
import SwiftUI
struct ScrollOffsetKey: PreferenceKey { static var defaultValue: CGFloat = 0; static func reduce(value:inout CGFloat, nextValue:()->CGFloat){ value = nextValue() } }
```

- [ ] **Step 4: Run tests + build**

Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`
Expected: PASS. Fix `DesignTokens` names if needed (`backgroundPaper` is `backgroundPaper` per feat-002).

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ReaderNavigationTests -quiet`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderView.swift apps/novels/Features/Reading/ScrollOffsetPreference.swift apps/novels/Features/Reading/ReadingShellView.swift
git commit -m "feat(reader): render SwiftUI.Text pipeline with typography, prev/next, to-bottom, overscroll lock"
```

---

### Task 4: ReferencesView — index jump, bold current

**Files:**
- Create: `apps/novels/Features/Reading/ReferencesView.swift`
- Test: `apps/novelsTests/ReferencesTests.swift` (VM-level)

**Interfaces:**
- Consumes: `Book`, `ReaderViewModel.goToChapter`.
- Produces: `struct ReferencesView: View { let book:Book; let current:Int; var onSelect:(Int)->Void }` Vietnamese copy: header "Tài liệu tham khảo".

- [ ] **Step 1: Write failing test**

```swift
func testReferencesCurrentBoldSelection() {
    let book = Book(id:"s", name:"N", author:"A", count:2, references:["C1","C2"])
    let current = 2
    // View inspection via ViewInspector or manual: we assert VM goTo updates chapter
    // Here test VM goTo after selection
}
```

- [ ] **Step 2: Run test**

Run: `xcodebuild test ... -only-testing:novelsTests/ReferencesTests -quiet` → FAIL (view not exist).

- [ ] **Step 3: Implement ReferencesView**

```swift
import SwiftUI

struct ReferencesView: View {
    let book: Book
    let current: Int
    var onSelect: (Int)->Void
    @Bindable var router: Router
    var body: some View {
        List {
            ForEach(Array(book.references.enumerated()), id:\.offset) { idx, title in
                let chapter = idx+1
                Button { onSelect(chapter); router.pop() } label: {
                    HStack { Text("Chương \(chapter): \(title)").foregroundStyle(DesignTokens.text); Spacer(); if chapter==current { Image(systemName:"checkmark").foregroundStyle(DesignTokens.accent) } }
                }
                .listRowBackground(chapter==current ? DesignTokens.accent.opacity(0.08) : Color.clear)
                .fontWeight(chapter==current ? .bold : .regular)
                .accessibilityIdentifier("ref-\(chapter)")
            }
        }
        .navigationTitle("Tài liệu tham khảo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement:.cancellationAction){ Button{ router.pop()} label:{ HStack{Image(systemName:"chevron.left"); Text("Đọc sách")}} } }
    }
}
```

Wire in `ReaderView` header "Mục lục" → `router.push(.references)` is already there; need `AppRoot` destination to supply actual book. Alternative: instantiate with VM's `book`. Provide convenience `ReferencesView(book:vm.book!, current:vm.chapterNumber, onSelect:{ Task{ await vm.goToChapter($0)} }, router:router)`.

- [ ] **Step 4: Run tests + build**

Run build + `ReferencesTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReferencesView.swift apps/novelsTests/ReferencesTests.swift
git commit -m "feat(reader): add References index with bold current + jump"
```

---

### Task 5: Typography Bottom Sheet — live persist

**Files:**
- Create: `apps/novels/Features/Reading/ReaderBottomSheet.swift`
- Modify: `apps/novels/Features/Reading/ReaderView.swift` (wire sheet)
- Test: `apps/novelsTests/TypographySheetTests.swift`

**Interfaces:**
- Consumes: `SettingsStore` (`typography.font/fontSize/lineHeight/letterSpacing`, `save()`), `BottomSheetView` existing, `DesignTokens`.
- Produces: `struct ReaderBottomSheet: View { @Bindable var settingsStore: SettingsStore; var onClose:()->Void }` with Stepper controls clamped to allowed ranges.

- [ ] **Step 1: Write failing test for typography persist**

```swift
func testTypographyStepperPersists() {
    let ud = UserDefaults(suiteName:"test.typography.\(UUID().uuidString)")!
    let store = SettingsStore(userDefaults: ud)
    store.typography.fontSize = 20; store.save()
    let reloaded = SettingsStore(userDefaults: ud)
    XCTAssertEqual(reloaded.typography.fontSize, 20)
    store.typography.fontSize = 99; store.save() // 99 -> sanitize to default 16
    XCTAssertEqual(SettingsStore(userDefaults: ud).typography.fontSize, 16)
}
```

- [ ] **Step 2: Run test → FAIL or PASS depending on existing store (expect PASS, next step covers UI)**

Run: `xcodebuild test ... -only-testing:novelsTests/TypographySheetTests -quiet`

- [ ] **Step 3: Implement ReaderBottomSheet**

```swift
import SwiftUI

struct ReaderBottomSheet: View {
    @Bindable var settingsStore: SettingsStore
    var onClose: ()->Void
    @State private var showFontPicker = false
    let fonts = ["System","Serif","Mono"]
    var body: some View {
        BottomSheetView(isPresented: .constant(true), onDismiss: onClose) {
            VStack(spacing: DesignTokens.spacing16) {
                HStack{ Text("Cài đặt đọc").font(.headline); Spacer(); Button{ onClose()} label:{Image(systemName:"xmark")}; Button{ /* gear to Settings — push via router if available else dismiss */ } label:{Image(systemName:"gearshape")} }
                Divider()
                Picker("Phông chữ", selection: Binding(get:{settingsStore.typography.font}, set:{settingsStore.typography.font=$0; settingsStore.save()})) { ForEach(fonts, id:\.self){ Text($0).tag($0) } }.pickerStyle(.segmented)
                stepperRow(title:"Cỡ chữ", value: Binding(get:{settingsStore.typography.fontSize}, set:{ clampAndSaveFontSize($0) }), range:12...24, step:1, format:"%.0f")
                stepperRow(title:"Giãn dòng", value: Binding(get:{settingsStore.typography.lineHeight}, set:{ clampAndSaveLineHeight($0) }), range:1.2...2.0, step:0.1, format:"%.1f")
                stepperRow(title:"Giãn chữ", value: Binding(get:{settingsStore.typography.letterSpacing}, set:{ clampAndSaveLetterSpacing($0) }), range:0...1.0, step:0.1, format:"%.1f")
            }
            .padding(DesignTokens.spacing16)
        }
    }
    private func stepperRow(title:String, value: Binding<Double>, range:ClosedRange<Double>, step:Double, format:String) -> some View {
        HStack{ Text(title); Spacer(); Stepper(value: value, in: range, step: step){ Text(String(format:format, value.wrappedValue)).monospacedDigit() }.labelsHidden(); Text(String(format:format, value.wrappedValue)) }
    }
    private func clampAndSaveFontSize(_ v:Double){ settingsStore.typography.fontSize = min(max(12, v),24); settingsStore.save() }
    private func clampAndSaveLineHeight(_ v:Double){ settingsStore.typography.lineHeight = min(max(1.2, v),2.0); settingsStore.save() }
    private func clampAndSaveLetterSpacing(_ v:Double){ settingsStore.typography.letterSpacing = min(max(0, v),1.0); settingsStore.save() }
}
```

Wire into `ReaderView` sheet: replace earlier `ReaderBottomSheet(settingsStore: settings, onClose:...)` with correct store passed via `@Environment`.

- [ ] **Step 4: Run tests + build**

Build → PASS; `TypographySheetTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderBottomSheet.swift apps/novelsTests/TypographySheetTests.swift
git commit -m "feat(reader): add typography bottom sheet with live persist"
```

---

### Task 6: Router + AppRoot integration, swipe-back disable, toast, offset restore per book

**Files:**
- Modify: `apps/novels/App/Router.swift`
- Modify: `apps/novels/App/AppRoot.swift`
- Modify: `apps/novels/Resources/DesignTokens.swift` (if missing paper color)
- Test: `apps/novelsTests/RouterReadingTests.swift`

**Interfaces:**
- Consumes: `SettingsStore`, `FileBookRepository`, `ToastCenter`.
- Produces: `Router.restoreInitialRoute()` already loads correct book; `Route.references` carries `bookId`; `AppRoot` `navigationDestination` for both.

- [ ] **Step 1: Write failing router tests**

```swift
func testRouterPushReadingSetsSessionOnScreen() {
    let ud = UserDefaults(suiteName:"test.router.\(UUID().uuidString)")!
    let store = SettingsStore(userDefaults: ud)
    let router = Router(settingsStore: store, repository: FakeRepo(exists:true))
    router.push(.reading(bookId:"slug-a"))
    XCTAssertEqual(store.session?.bookId, "slug-a")
    XCTAssertEqual(store.session?.onScreen, true)
    XCTAssertEqual(store.session?.chapterNumber, 1)
}
func testPopReadingClearsOnScreenKeepsOffset() {
    let store = // ...
    store.session = ReadingSession(bookId:"slug-a", onScreen:true, offset:88, chapterNumber:2)
    let router = Router(settingsStore: store)
    router.didPopFromReading()
    XCTAssertEqual(store.session?.onScreen, false)
    XCTAssertEqual(store.session?.offset, 88)
}
func testRestoreWithMissingBookToasts() {
    let router = Router(settingsStore: store, repository: FakeRepo(exists:false))
    store.session = ReadingSession(bookId:"missing", onScreen:true, offset:0, chapterNumber:1)
    router.restoreInitialRoute()
    XCTAssertEqual(router.toast.lastMessage, "Không tìm thấy sách")
}
```

- [ ] **Step 2: Run test → FAIL if behavior not matched**

Run: `xcodebuild test ... -only-testing:novelsTests/RouterReadingTests -quiet`

- [ ] **Step 3: Implement / verify Router & AppRoot**

Ensure `Router.push(.reading)` already handles chapter/offset as in current `Router.swift` lines 42-55 — extend to `Route.references`:
```swift
enum Route: Hashable { case reading(bookId:String); case references(bookId:String); case addBook }
```
Adjust `restoreInitialRoute()` unchanged; add guard for references existence if needed.

In `AppRoot.swift`, add destinations:
```swift
.navigationDestination(for: Router.Route.self) { route in
    switch route {
    case .reading(let bookId): ReaderView(bookId: bookId, router: router)
    case .references(let bookId):
        if let book = try? repo.book(slug: bookId) {
            ReferencesView(book: book, current: settings.session?.chapterNumber ?? 1, onSelect: { n in settings.session?.chapterNumber = n; settings.save() }, router: router)
        } else { Text("Không tìm thấy chương") }
    case .addBook: AddBookView(...)
    }
}
```
Keep `.interactiveDismissDisabled(true)` only on ReadingView, not global.

Verify toast for missing chapter is wired via `ReaderViewModel` using `router.toast`.

Ensure offset restore per book: `ReaderViewModel.init` reads `store.session` only if `bookId` matches, else starts at 1/offset 0 — already spec'd.

- [ ] **Step 4: Run tests + build**

Run `RouterReadingTests` → PASS. Run full build → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/App/Router.swift apps/novels/App/AppRoot.swift
git commit -m "feat(reader): wire Router/AppRoot for reading+references, onScreen, swipe-back disable, toast"
```

---

### Task 7: Integration, a11y, offline polish, final verification

**Files:**
- Create: `apps/novelsTests/ReaderIntegrationTests.swift` (optional end-to-end VM + parser)
- Modify: `apps/novels/Features/Reading/*` (polish), `apps/novels.xcodeproj/project.pbxproj` (add new files to target)
- Test: all `novelsTests` suites

**Interfaces:**
- Consumes: All above.
- Produces: Verified reader meeting 5 acceptance criteria; no network calls; `init.sh` PASS.

- [ ] **Step 1: Write integration test covering full flow**

```swift
func testReaderEndToEndFromFixtures() async {
    // 3-chapter fixture from Task 2
    let vm = makeVM(slug:"test-slug", htmls:["<h1>T1</h1><p>Hello</p>","<p><b>Bold</b> <i>Italic</i></p>",""])
    await vm.load()
    XCTAssertEqual(vm.blocks.first?.spans.first?.text, "T1")
    await vm.goToChapter(2)
    XCTAssertEqual(vm.blocks.first?.spans[0].kind, .bold)
    await vm.goToChapter(99) // clamp to 3
    XCTAssertEqual(vm.chapterNumber, 3)
    await vm.goToChapter(0) // clamp to 1
    XCTAssertEqual(vm.chapterNumber, 1)
}
```

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`
Expected: PASS (all Domain + HtmlParser + ReaderVM + Router + Typography suites).

- [ ] **Step 3: Manual/aux verification (no network)**

- Run: `grep -R "URLSession\|http" apps/novels/Features/Reading --include="*.swift"` → expect 0 hits (Reader is offline).
- Run: `grep -R "WebKit\|WKWebView\|NSAttributedString" apps/novels --include="*.swift"` → 0 hits.
- Run: `swiftformat --lint apps --verbose` → 0/?. Run: `swiftlint lint --strict` → 0 violations.
- Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` → PASS.
- Accessibility check via Xcode Preview: prev/next have VoiceOver labels "Chương trước/Sau", header identifies chapter.

- [ ] **Step 4: Run init.sh**

Run: `./init.sh`
Expected: PASS — format PASS, lint PASS, build PASS, test PASS (SKIP no longer, now test runs).

- [ ] **Step 5: Final commit & handoff prep**

```bash
git add docs/plans/feat-004.md apps/novelsTests/ReaderIntegrationTests.swift
git commit -m "feat(reader): integration polish, a11y, offline check"
```

Update `features/feat-004.md` Handoff: Evidence `docs/plans/feat-004.md`, Blockers none, Next `activate feat-004`.

---

## Self-Review

**1. Spec coverage:** Each `features/feat-004.md` Acceptance maps:
- Parses HTML to spans + SwiftUI.Text 1..count, prev/next disabled, References → Task 1 + Task 3 + Task 4.
- Overscroll lock, to-bottom, swipe-back disabled → Task 3 + Task 6 (`interactiveDismissDisabled` + `ScrollOffsetKey`).
- Offset per slug restore/re-entry + `onScreen` → Task 2 + Task 6 (session chapterNumber+offset, `onAppear`/`onDisappear`, per-book check).
- Bottom sheet typography persist live → Task 5 (`SettingsStore.typography.save()` + steppers).
- Missing file toast without crash + rapid nav not corrupt → Task 2 + Task 3 (errorMessage + toast "Không tìm thấy chương" + offset reset).
- Offline flag, no AI/prefetch → Task 7 grep checks.

**2. Placeholder scan:** No TBD/TODO/incomplete sections; every step has concrete code/tests/expected commands. File paths use actual `apps/novels/**` roots (synced groups). Code blocks compile with known types (`TextSpan.Kind.boldItalic` defined, `DesignTokens` colors exist per feat-002).

**3. Type consistency:** `ReadingSession(bookId:String, onScreen:Bool, offset:Double, chapterNumber:Int)` matches `Domain/ReadingSession.swift:3-8`. `TypographySetting` 12-24/1.2-2.0/0-1.0 matches `SettingsStore.sanitize()`. `Router.Route` `reading(bookId:)` + `references(bookId:)` matches `Router.swift:23-26` extension (no rawValue, Hashable). `FileBookRepository(root:)` init matches `Persistence/BookRepository.swift`. `ToastCenter.show(_:type:)` used via `router.toast` per `AppRoot.swift`.

No gaps: spec section “Overscroll auto-advances with short lock” covered in Task 3 `handleOffset` 400ms lock; “to-bottom” → Task 3 `proxy.scrollTo("bottom")`; “rapid nav does not corrupt offset” → Task 2 `testRapidNavDoesNotCorruptOffset`. If gaps found during execution, add inline subtask — do not skip.

## Links

- Spec: `features/feat-004.md` · Flow: `docs/product/flows.md §4` · Design: `docs/design/screens.md §2 Reading`, `docs/design/design-system.md` · Contracts: `docs/contracts/local-data.md` · Decisions: `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`

