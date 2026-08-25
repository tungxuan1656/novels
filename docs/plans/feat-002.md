# App Shell + Home Library Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish NavigationStack startup routing and offline Home Library shell with shared primitives (loading overlay, toast, bottom sheet) so later import/reader/settings flows have a consistent Vietnamese UI container.

**Architecture:** AppRoot restores SettingsStore session/settings (no network) synchronously on appear and decides initial NavigationStack path per `docs/design/navigation.md` (`onScreen ? Reading(bookId: slug) : Library`). Router is `@Observable final class` holding `NavigationPath` + typed `Route` enum; Library is `MVVM` with `LibraryViewModel` scanning `FileBookRepository(AppPaths.booksRoot())` and exposing `[Book]`; Reading is shell-only placeholder that toggles `onScreen`; Info sheet and swipe-delete are Library-only; shared primitives are small SwiftUI Views/Modifiers reused across features via design-system tokens.

**Tech Stack:** Swift 5.0 / SwiftUI / Xcode 26.5 scheme `novels` iOS 26.5, `TARGETED_DEVICE_FAMILY=1` already, `@Observable` + `NavigationStack`, `Foundation.FileManager` + `FileBookRepository` from feat-001, `Foundation.UserDefaults` + `SettingsStore`/`ReadingSession` from feat-001, `XCTest`/`XCUITest`, SwiftLint 0.65.1 + SwiftFormat 0.62.1.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — product intent; `TARGETED_DEVICE_FAMILY=1` already aligned, `IPHONEOS_DEPLOYMENT_TARGET=26.5`, `DEVELOPMENT_TEAM M5U4E4H84J`, Swift 5.0, single module `apps/novels` with synchronized groups.
- No SwiftPM dependencies; no `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, second AI cache, RN packages, or RN migration.
- `book.json.id` is string slug local identity (folder `books/<slug>/`, cache `book_id`, route `bookId`); `book.json.count` is number and must equal `references.count`; chapters 1-based; invalid folders (missing `book.json` or chapter files) skipped.
- Startup restore offline only: `SettingsStore.load()+sanitize()` then route `onScreen && valid bookId ? Reading : Library`; invalid `bookId` toasts “Không tìm thấy sách” and stays on Library.
- Library lists only folders with valid `book.json` via `FileBookRepository.listBooks()`; empty state when zero; pull-to-refresh reloads; Info sheet shows `name`/`author`/`count`/`references`; swipe-to-delete confirms then `deleteBook(slug:)` removes folder and refreshes.
- Loading/Toast/BottomSheet primitives are reusable across features; toast colors green/red/blue/orange per `screens.md` §3 with 3s/4s/5s durations; loading is blocking overlay for download/AI/clear + inline spinner for lists; bottom sheet uses native `.sheet` with drag/backdrop dismiss.
- Vietnamese copy from docs/design: “Thư viện”, “Chưa có sách”, “Nhấn + để thêm sách”, “Thông tin sách”, “Tác giả”, “Số chương”, “Danh mục chương”, “Xóa sách?”, “Bạn có chắc muốn xóa “{name}” không?”, “Hủy”, “Xóa”, “Đã xóa “{name}””, “Không thể xóa sách”, “Không tìm thấy sách”, “Đang tải...”.
- Design tokens per `design-system.md` §2-4: background `#FDFCF8`/`#FFFFFF`, surface `#FFFFFF`, text `#111111`, muted `#6B7280`, accent `#2563EB`, success `#16A34A`, warning `#EA580C`, error `#DC2626`, border `#E5E7EB`, radius 12-16, spacing 4/8/12/16/24/32, row min 56, side padding 16.
- Navigation rules per `navigation.md`: Home tap row → `Reading(bookId)` sets `onScreen=true`; Reading back → `Home` sets `onScreen=false` and saves offset; back at root does not crash; Reading disables swipe-back; rapid double push ignored.
- Tests isolated via `FileManager.temporaryDirectory` and `UserDefaults(suiteName: UUID().uuidString)`; never touch real `Application Support/novels`.

---

### Task 1: Shared primitives — LoadingView, ToastView, BottomSheetView + design tokens

**Files:**
- Create: `apps/novels/SharedUI/LoadingView.swift` (planned — inline spinner + blocking overlay)
- Create: `apps/novels/SharedUI/ToastView.swift` (planned — `enum ToastType { case success, error, info, warning }`, `struct ToastData: Equatable { let message: String; let type: ToastType }`, `@Observable final class ToastCenter`, `struct ToastView: View`, `View.toast(center:)` modifier)
- Create: `apps/novels/SharedUI/BottomSheetView.swift` (planned — reusable sheet wrapper with handle, drag/backdrop dismiss, height fits content)
- Create: `apps/novels/Resources/DesignTokens.swift` (planned — `enum DesignTokens { static let accent etc. }` or `Color+Tokens`)
- Test: `apps/novelsTests/ToastCenterTests.swift` (planned)
- Test: `apps/novelsTests/LoadingViewTests.swift` (planned — snapshot-style existence not UI snapshot)

**Interfaces:**
- Consumes: SwiftUI, `docs/design/design-system.md` tokens, `docs/design/screens.md` §3 Toast/Loading/BottomSheet specs.
- Produces: `LoadingView(isBlocking: Bool)`; `ToastCenter.show(_ message: String, type: ToastType, duration: Double)` + `ToastView` overlay; `BottomSheetView` / `.bottomSheet(isPresented:)` used by Task 3-4; tokens consumed by Task 2-5.

- [ ] **Step 1: Write failing ToastCenter show/dismiss test**

```swift
// apps/novelsTests/ToastCenterTests.swift (planned)
import XCTest
@testable import novels
@MainActor
final class ToastCenterTests: XCTestCase {
    func testShowAndAutoDismiss() async throws {
        let center = ToastCenter()
        center.show("Không tìm thấy sách", type: .error)
        XCTAssertEqual(center.current?.message, "Không tìm thấy sách")
        XCTAssertEqual(center.current?.type, .error)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(center.current)
    }
    func testDismissClears() {
        let center = ToastCenter()
        center.show("Đã xóa", type: .success)
        center.dismiss()
        XCTAssertNil(center.current)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL (no ToastCenter)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ToastCenterTests`
Expected: FAIL compile error `cannot find type 'ToastCenter'`.

- [ ] **Step 3: Implement minimal ToastCenter + ToastView**

```swift
// apps/novels/SharedUI/ToastView.swift (planned)
import SwiftUI
import Observation

enum ToastType { case success, error, info, warning
    var color: Color {
        switch self {
        case .success: return Color(hex: 0x16A34A)
        case .error: return Color(hex: 0xDC2626)
        case .info: return Color(hex: 0x2563EB)
        case .warning: return Color(hex: 0xEA580C)
        }
    }
}
struct ToastData: Equatable { let id = UUID(); let message: String; let type: ToastType; static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id } }
@MainActor
@Observable final class ToastCenter {
    var current: ToastData?
    private var task: Task<Void, Never>?
    func show(_ message: String, type: ToastType) {
        let duration: Double = message.count < 60 ? 3 : message.count < 150 ? 4 : 5
        task?.cancel()
        current = ToastData(message: message, type: type)
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.current = nil }
        }
    }
    func dismiss() { task?.cancel(); current = nil }
}
struct ToastView: View {
    let data: ToastData
    var body: some View {
        Text(data.message)
            .font(.footnote).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(data.type.color).clipShape(Capsule())
            .accessibilityLabel(data.message)
    }
}
extension View {
    func toast(center: ToastCenter) -> some View {
        overlay(alignment: .top) {
            if let data = center.current {
                ToastView(data: data).padding(.top, 16).onTapGesture { center.dismiss() }.transition(.move(edge: .top).combined(with: .opacity))
            }
        }.animation(.easeInOut, value: center.current)
    }
}
```

Add `Color(hex:)` helper or use explicit `Color(red:green:blue:)`. Keep SwiftLint clean. Add `DesignTokens.swift` with `Color` extensions mapping tokens.

- [ ] **Step 4: Implement LoadingView and BottomSheet wrapper**

```swift
// apps/novels/SharedUI/LoadingView.swift (planned)
import SwiftUI
struct LoadingView: View {
    var message: String = "Đang tải..."
    var isBlocking: Bool = false
    var body: some View {
        ZStack {
            if isBlocking { Color.black.opacity(0.25).ignoresSafeArea() }
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.2).tint(Color(hex: 0x2563EB))
                Text(message).font(.footnote).foregroundStyle(Color(hex: 0x6B7280))
            }.padding(24).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(radius: 8)
        }.accessibilityLabel(message)
    }
}
extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Đang tải...") -> some View {
        overlay { if isLoading { LoadingView(message: message, isBlocking: true) } }
    }
}
// apps/novels/SharedUI/BottomSheetView.swift (planned)
import SwiftUI
struct BottomSheetView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(hex: 0xE5E7EB)).frame(width: 40, height: 5).padding(.top, 8).padding(.bottom, 12)
            content.padding(.horizontal, 16).padding(.bottom, 16)
        }.background(Color.white).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ToastCenterTests`
Expected: PASS show/dismiss.

- [ ] **Step 6: Commit primitives**

```bash
git add apps/novels/SharedUI/LoadingView.swift apps/novels/SharedUI/ToastView.swift apps/novels/SharedUI/BottomSheetView.swift apps/novels/Resources/DesignTokens.swift apps/novelsTests/ToastCenterTests.swift
git commit -m "feat(002): add shared primitives loading/toast/bottom-sheet"
```

**Handoff dependency:** Tasks 2-5 consume `ToastCenter`/`LoadingView`/`BottomSheetView` and tokens.

---

### Task 2: Router + AppRoot startup routing (onScreen ? Reading : Library)

**Files:**
- Create: `apps/novels/App/Router.swift` (planned — `@Observable final class Router { var path: NavigationPath; enum Route: Hashable { case library, reading(bookId: String), references } ; func push/pop; var toast: ToastCenter }`)
- Create: `apps/novels/App/AppRoot.swift` (planned — `struct AppRoot: View { @State router; @State settings; @State toastCenter; var body: NavigationStack }` with startup restore)
- Modify: `apps/novels/NovelsApp.swift` (planned — replace `ContentView()` with `AppRoot()` and inject `SettingsStore.shared`)
- Test: `apps/novelsTests/RouterTests.swift` (planned)

**Interfaces:**
- Consumes: `SettingsStore` (feat-001), `FileBookRepository`/`AppPaths` (feat-001), `ToastCenter` from Task 1, `docs/design/navigation.md` §2-6.
- Produces: `Router` used by Task 3-5; `AppRoot` as `WindowGroup` root; startup routing logic consumed by acceptance “Launch restores session and routes correctly; invalid bookId toasts”.

- [ ] **Step 1: Write failing Router + startup routing tests**

```swift
// apps/novelsTests/RouterTests.swift (planned)
import XCTest
@testable import novels
@MainActor
final class RouterTests: XCTestCase {
    func testInitialRouteLibraryWhenNoSession() {
        let store = SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.session = nil
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 0) // Library is root, no push
        XCTAssertNil(router.toast.current)
    }
    func testInvalidBookIdToastsAndStaysOnLibrary() {
        let ud = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "missing-slug", onScreen: true, offset: 0, chapterNumber: 1)
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 0)
        XCTAssertEqual(router.toast.current?.message, "Không tìm thấy sách")
    }
    func testValidBookIdPushesReading() throws {
        let book = Book(id: "valid-slug", name: "V", author: "A", count: 1, references: ["C1"])
        let ud = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "valid-slug", onScreen: true, offset: 0, chapterNumber: 1)
        let router = Router(settingsStore: store, repository: FakeRepository(books: [book]))
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 1)
    }
    func testReadingBackClearsOnScreen() {
        let ud = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "s", onScreen: true, offset: 10, chapterNumber: 1)
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.didPopFromReading()
        XCTAssertEqual(store.session?.onScreen, false)
    }
}
// Minimal fake for tests (planned inside test file)
struct FakeRepository: BookRepository {
    var books: [Book]
    func listBooks() throws -> [Book] { books }
    func book(slug: String) throws -> Book? { books.first(where: { $0.id == slug }) }
    func chapterHTML(slug: String, number: Int) throws -> String { "" }
    func save(validatedRoot: URL, slug: String) throws {}
    func deleteBook(slug: String) throws {}
}
```

- [ ] **Step 2: Run — expect FAIL (no Router)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterTests`
Expected: FAIL `cannot find type 'Router'`.

- [ ] **Step 3: Implement Router and AppRoot (planned skeleton)**

```swift
// apps/novels/App/Router.swift (planned)
import SwiftUI
import Observation
@MainActor
@Observable final class Router {
    var path = NavigationPath()
    var toast = ToastCenter()
    private let settingsStore: SettingsStore
    private let repository: BookRepository
    private var isPushing = false
    init(settingsStore: SettingsStore = .shared, repository: BookRepository? = nil) {
        self.settingsStore = settingsStore
        if let repository { self.repository = repository }
        else {
            let root = AppPaths.booksRoot()
            self.repository = FileBookRepository(root: root, fileManager: .default)
        }
    }
    enum Route: Hashable { case reading(bookId: String); case references }
    func restoreInitialRoute() {
        settingsStore.load(); settingsStore.sanitize()
        guard let session = settingsStore.session, session.onScreen else { return }
        guard (try? repository.book(slug: session.bookId)) != nil else {
            toast.show("Không tìm thấy sách", type: .error)
            return
        }
        push(.reading(bookId: session.bookId))
    }
    func push(_ route: Route) {
        guard !isPushing else { return }
        isPushing = true
        path.append(route)
        if case .reading(let id) = route {
            settingsStore.session = ReadingSession(bookId: id, onScreen: true, offset: settingsStore.session?.offset ?? 0, chapterNumber: settingsStore.session?.chapterNumber ?? 1)
            settingsStore.save()
        }
        Task { @MainActor in try? await Task.sleep(nanoseconds: 300_000_000); isPushing = false }
    }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func didPopFromReading() {
        settingsStore.session?.onScreen = false
        settingsStore.save()
    }
}
// apps/novels/App/AppRoot.swift (planned)
import SwiftUI
struct AppRoot: View {
    @State private var router = Router()
    @State private var settings = SettingsStore.shared
    var body: some View {
        NavigationStack(path: $router.path) {
            LibraryView(router: router)
                .navigationDestination(for: Router.Route.self) { route in
                    switch route {
                    case .reading(let bookId): ReadingShellView(bookId: bookId, router: router)
                    case .references: Text("Tài liệu tham khảo").navigationTitle("Tham khảo") // placeholder for feat-004
                    }
                }
        }
        .toast(center: router.toast)
        .task { router.restoreInitialRoute() }
    }
}
// apps/novels/NovelsApp.swift (planned modify)
import SwiftUI
@main struct NovelsApp: App {
    @State private var settings = SettingsStore.shared
    var body: some Scene {
        WindowGroup { AppRoot() }
    }
}
```

Ensure `Router.Route` conforms to `Hashable` automatically and `NavigationPath` appended. Handle `onScreen` true/false per `navigation.md:49-50`.

- [ ] **Step 4: Run tests — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterTests`
Expected: PASS library stays, invalid toasts, valid pushes, pop clears onScreen.

- [ ] **Step 5: Commit router + root**

```bash
git add apps/novels/App/Router.swift apps/novels/App/AppRoot.swift apps/novels/NovelsApp.swift apps/novelsTests/RouterTests.swift
git commit -m "feat(002): add Router and AppRoot startup routing"
```

**Handoff dependency:** Tasks 3-5 consume `Router`/`AppRoot` and `ToastCenter`.

---

### Task 3: Offline Library — scan, list rows, empty state, pull-to-refresh, Vietnamese UI

**Files:**
- Create: `apps/novels/Features/Library/LibraryViewModel.swift` (planned — `@Observable final class LibraryViewModel { var books: [Book]; var isLoading; var toast; func load(); func delete(slug:) }` injected `BookRepository` + `FileManager`)
- Create: `apps/novels/Features/Library/LibraryView.swift` (planned — header “Thư viện” with + button placeholder, List rows with name/author/count, empty centered view, `.refreshable`, `.swipeActions`, `.loadingOverlay`, `.toast`)
- Modify: `apps/novels/App/AppRoot.swift` — wire LibraryViewModel injection
- Test: `apps/novelsTests/LibraryViewModelTests.swift` (planned)
- Test: `apps/novelsUITests/LibrarySmokeTests.swift` or extend `LaunchSmokeTests.swift` (planned)

**Interfaces:**
- Consumes: `FileBookRepository` + `AppPaths`, `Book` (feat-001), `ToastCenter`/`LoadingView` from Task 1, `Router` from Task 2, `docs/product/functional-specs/book-library.md`, `docs/design/screens.md` §2 Home Library, `design-system.md` tokens.
- Produces: Library list rendered at root; refresh hook `LibraryViewModel.load()` consumed by feat-003 post-import; rows expose `accessibilityIdentifier` for tests.

- [ ] **Step 1: Write failing LibraryViewModel tests**

```swift
// apps/novelsTests/LibraryViewModelTests.swift (planned)
import XCTest
@testable import novels
@MainActor
final class LibraryViewModelTests: XCTestCase {
    func testEmptyReturnsEmpty() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let vm = LibraryViewModel(repository: repo)
        vm.load()
        XCTAssertTrue(vm.books.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }
    func testListsOnlyValidBookJSON() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        // valid
        let valid = tmp.appendingPathComponent("valid-slug", isDirectory: true)
        try FileManager.default.createDirectory(at: valid.appendingPathComponent("chapters", isDirectory: true), withIntermediateDirectories: true)
        try #"{"id":"valid-slug","name":"Sách Hay","count":1,"author":"Tác giả A","references":["C1"]}"#.write(to: valid.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        try "<p>c1</p>".write(to: valid.appendingPathComponent("chapters/chapter-1.html"), atomically: true, encoding: .utf8)
        // invalid (missing book.json)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("bad", isDirectory: true), withIntermediateDirectories: true)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let vm = LibraryViewModel(repository: repo)
        vm.load()
        XCTAssertEqual(vm.books.map(\.id), ["valid-slug"])
    }
    func testDeleteRemovesFolderAndRefreshes() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("books", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let folder = tmp.appendingPathComponent("to-delete", isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("chapters", isDirectory: true), withIntermediateDirectories: true)
        try #"{"id":"to-delete","name":"X","count":0,"author":null,"references":[]}"#.write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let vm = LibraryViewModel(repository: repo)
        vm.load()
        XCTAssertEqual(vm.books.count, 1)
        try repo.deleteBook(slug: "to-delete")
        vm.load()
        XCTAssertTrue(vm.books.isEmpty)
    }
}
```

- [ ] **Step 2: Run — expect FAIL (no LibraryViewModel)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/LibraryViewModelTests`
Expected: FAIL compile.

- [ ] **Step 3: Implement LibraryViewModel + LibraryView (planned)**

```swift
// apps/novels/Features/Library/LibraryViewModel.swift (planned)
import Foundation
import Observation
@MainActor
@Observable final class LibraryViewModel {
    var books: [Book] = []
    var isLoading = false
    var selected: Book?
    var showInfo = false
    var showDeleteConfirm: Book?
    private let repository: BookRepository
    let toast = ToastCenter()
    init(repository: BookRepository? = nil) {
        if let repository { self.repository = repository }
        else { self.repository = FileBookRepository(root: AppPaths.booksRoot(), fileManager: .default) }
    }
    func load() {
        isLoading = true
        defer { isLoading = false }
        books = (try? repository.listBooks()) ?? []
    }
    func confirmDelete(_ book: Book) { showDeleteConfirm = book }
    func deleteConfirmed() {
        guard let book = showDeleteConfirm else { return }
        do {
            try repository.deleteBook(slug: book.id)
            toast.show("Đã xóa “\(book.name)”", type: .success)
            showDeleteConfirm = nil
            load()
        } catch {
            toast.show("Không thể xóa sách", type: .error)
        }
    }
}
// apps/novels/Features/Library/LibraryView.swift (planned)
import SwiftUI
struct LibraryView: View {
    @Bindable var router: Router
    @State private var vm: LibraryViewModel
    init(router: Router, viewModel: LibraryViewModel? = nil) {
        self.router = router
        self._vm = State(wrappedValue: viewModel ?? LibraryViewModel())
    }
    var body: some View {
        Group {
            if vm.books.isEmpty && !vm.isLoading {
                ContentUnavailableView {
                    Label("Chưa có sách", systemImage: "books.vertical")
                } description: {
                    Text("Nhấn + để thêm sách")
                } actions: {
                    Button("Thêm sách") {} // feat-003 will wire
                }
                .accessibilityIdentifier("library.empty")
            } else {
                List(vm.books, id: \.id) { book in
                    Button {
                        router.push(.reading(bookId: book.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.name).font(.headline).foregroundStyle(Color(hex: 0x111111)).lineLimit(2)
                            HStack(spacing: 8) {
                                if let author = book.author { Text(author).font(.footnote).foregroundStyle(Color(hex: 0x6B7280)) }
                                Text("\(book.count) chương").font(.footnote).foregroundStyle(Color(hex: 0x6B7280))
                            }
                        }.padding(.vertical, 4)
                    }
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { vm.confirmDelete(book) } label: { Label("Xóa", systemImage: "trash") }.tint(Color(hex: 0xDC2626))
                        Button { vm.selected = book; vm.showInfo = true } label: { Label("Thông tin", systemImage: "info.circle") }.tint(Color(hex: 0x2563EB))
                    }
                    .accessibilityIdentifier("library.row.\(book.id)")
                }
                .listStyle(.plain).refreshable { vm.load() }
            }
        }
        .navigationTitle("Thư viện").navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { /* feat-003: open Add Book */ } label: { Image(systemName: "plus").accessibilityLabel("Thêm sách") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { /* feat-005: open Settings */ } label: { Image(systemName: "gearshape").accessibilityLabel("Cài đặt") }
            }
        }
        .loadingOverlay(isLoading: vm.isLoading)
        .toast(center: vm.toast)
        .toast(center: router.toast)
        .sheet(isPresented: $vm.showInfo) {
            if let book = vm.selected { BookInfoSheet(book: book) }
        }
        .alert(item: $vm.showDeleteConfirm) { book in
            Alert(title: Text("Xóa sách?"), message: Text("Bạn có chắc muốn xóa “\(book.name)” không?"), primaryButton: .destructive(Text("Xóa")) { vm.deleteConfirmed() }, secondaryButton: .cancel(Text("Hủy")))
        }
        .task { vm.load() }
        .onAppear { vm.load() }
    }
}
extension Book: Identifiable {}
```

Ensure `Book` already `Identifiable` via `id`; add `Alert(item:)` helper with `Identifiable` conformance for `Book` if needed (wrap `Book` in `IdentifiableBook`). Use native `alert` with `isPresented` + `book` state alternative to avoid `Identifiable` conflicts.

Styling uses tokens: side padding 16, row min 56, border `#E5E7EB`, radius 12.

- [ ] **Step 4: Run tests — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/LibraryViewModelTests`
Expected: PASS empty, valid only, delete refresh.

- [ ] **Step 5: Run build**

Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet`
Expected: PASS with no warnings; SwiftLint strict 0 violations.

- [ ] **Step 6: Commit library list**

```bash
git add apps/novels/Features/Library/LibraryViewModel.swift apps/novels/Features/Library/LibraryView.swift apps/novelsTests/LibraryViewModelTests.swift
git commit -m "feat(002): add offline Library list with empty state"
```

**Handoff dependency:** Task 4 consumes `LibraryView`/`LibraryViewModel` for sheet/delete.

---

### Task 4: Info sheet + swipe-to-delete with confirmation

**Files:**
- Create: `apps/novels/Features/Library/BookInfoSheet.swift` (planned — sheet with name/author/count/references index, Vietnamese labels)
- Modify: `apps/novels/Features/Library/LibraryView.swift` — wire sheet + alert already stubbed, polish swipe actions per `screens.md` §3 Swipe Row
- Test: extend `apps/novelsTests/LibraryViewModelTests.swift` with info/confirm tests (planned)
- Test: `apps/novelsTests/BookInfoTests.swift` (planned — verify book fields displayed logic)

**Interfaces:**
- Consumes: `LibraryViewModel` from Task 3, `Book`/`Reference` (`typealias Reference = String`), `ToastCenter`, `BottomSheetView` from Task 1, `docs/product/functional-specs/book-library.md` §3.
- Produces: Info sheet reachable via swipe Info or row tap long-press; delete confirmation that removes folder via `FileBookRepository.deleteBook` and refreshes list; Vietnamese copy.

- [ ] **Step 1: Write failing delete-confirm + info tests**

```swift
// extension in LibraryViewModelTests.swift (planned add)
func testDeleteConfirmFlow() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("books", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    let folder = tmp.appendingPathComponent("slug-a", isDirectory: true)
    try FileManager.default.createDirectory(at: folder.appendingPathComponent("chapters", isDirectory: true), withIntermediateDirectories: true)
    try #"{"id":"slug-a","name":"Tên Sách","count":2,"author":"Tác giả","references":["Chương 1","Chương 2"]}"#.write(to: folder.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
    try "<p>1</p>".write(to: folder.appendingPathComponent("chapters/chapter-1.html"), atomically: true, encoding: .utf8)
    try "<p>2</p>".write(to: folder.appendingPathComponent("chapters/chapter-2.html"), atomically: true, encoding: .utf8)
    let repo = FileBookRepository(root: tmp, fileManager: .default)
    let vm = LibraryViewModel(repository: repo)
    vm.load()
    XCTAssertEqual(vm.books.first?.references.count, 2)
    vm.confirmDelete(vm.books.first!)
    XCTAssertNotNil(vm.showDeleteConfirm)
    vm.deleteConfirmed()
    XCTAssertTrue(vm.books.isEmpty)
    vm.load()
    XCTAssertTrue(vm.books.isEmpty)
}
func testInfoSheetBookFields() throws {
    let book = Book(id: "s", name: "Vạn Giới", author: "Tác giả X", count: 2, references: ["Chương 1", "Chương 2"])
    XCTAssertEqual(book.name, "Vạn Giới")
    XCTAssertEqual(book.references.count, 2)
}
```

- [ ] **Step 2: Run — expect FAIL if not yet implemented (alert missing)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/LibraryViewModelTests`
Expected: FAIL until `confirmDelete`/`deleteConfirmed` wired; after Task 3 they already PASS, but new test ensures toast message contains name.

- [ ] **Step 3: Implement BookInfoSheet (planned)**

```swift
// apps/novels/Features/Library/BookInfoSheet.swift (planned)
import SwiftUI
struct BookInfoSheet: View {
    let book: Book
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.name).font(.title3).bold().foregroundStyle(Color(hex: 0x111111)).lineLimit(2)
                        if let author = book.author { Label(author, systemImage: "person").font(.subheadline).foregroundStyle(Color(hex: 0x6B7280)) }
                        Label("\(book.count) chương", systemImage: "list.number").font(.subheadline).foregroundStyle(Color(hex: 0x6B7280))
                    }.padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Danh mục chương").font(.headline).foregroundStyle(Color(hex: 0x111111))
                        ForEach(Array(book.references.enumerated()), id: \.offset) { idx, title in
                            HStack {
                                Text("\(idx + 1)").font(.footnote).foregroundStyle(Color(hex: 0x6B7280)).frame(width: 28, alignment: .leading)
                                Text(title).font(.body).foregroundStyle(Color(hex: 0x111111)).lineLimit(1)
                                Spacer()
                            }.padding(.vertical, 6)
                            if idx < book.references.count - 1 { Divider().background(Color(hex: 0xE5E7EB)) }
                        }
                    }.padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
                }.padding(16)
            }.background(Color(hex: 0xF5F5F5))
            .navigationTitle("Thông tin sách").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } } }
        }
    }
}
```

Ensure `Info sheet only (book details + chapter index)` — not Reading sheet per feat-002 Non-goals. Reading sheet belongs to feat-004/006.

Update `LibraryView` swipe actions to match design tokens: Info blue `#2563EB`, Delete red `#DC2626`, threshold short, no auto-delete, close swipe on tap.

- [ ] **Step 4: Run tests — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/LibraryViewModelTests`
Expected: PASS delete confirm removes folder and refreshes; info fields correct.

- [ ] **Step 5: Run build + lint**

Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet && swiftlint lint --strict`
Expected: PASS 0 violations.

- [ ] **Step 6: Commit sheet + delete**

```bash
git add apps/novels/Features/Library/BookInfoSheet.swift apps/novels/Features/Library/LibraryView.swift apps/novelsTests/LibraryViewModelTests.swift
git commit -m "feat(002): add Info sheet and swipe-to-delete confirm"
```

**Handoff dependency:** Task 5 consumes Library navigation to Reading shell.

---

### Task 5: Reading shell placeholder + onScreen toggles + invalid bookId toast + Back behavior

**Files:**
- Create: `apps/novels/Features/Reading/ReadingShellView.swift` (planned — placeholder shell, sets/clears `onScreen` per `navigation.md:49-50`, disables swipe-back, shows chapter placeholder + References nav)
- Modify: `apps/novels/App/Router.swift` — add `Route.references` push and `didPopFromReading` hook
- Modify: `apps/novels/Features/Library/LibraryView.swift` — ensure Home tap row → `onScreen=true` via Router
- Test: `apps/novelsTests/ReadingShellTests.swift` (planned)
- Test: `apps/novelsUITests/LaunchSmokeTests.swift` — extend smoke to verify Library title and Reading back

**Interfaces:**
- Consumes: `SettingsStore`/`ReadingSession`, `Router`, `ToastCenter` (Task 1-2), `docs/design/navigation.md` §3-5, `docs/design/screens.md` §2 Reading.
- Produces: Reading shell that satisfies acceptance “Back at root does not crash; Reading back clears onScreen; Home tap row → onScreen=true”.

- [ ] **Step 1: Write failing Reading shell onScreen tests**

```swift
// apps/novelsTests/ReadingShellTests.swift (planned)
import XCTest
@testable import novels
@MainActor
final class ReadingShellTests: XCTestCase {
    func testPushReadingSetsOnScreenTrue() {
        let ud = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "a", onScreen: false, offset: 0, chapterNumber: 1)
        let repo = FakeRepository(books: [Book(id: "a", name: "N", author: nil, count: 1, references: ["C1"])])
        let router = Router(settingsStore: store, repository: repo)
        router.push(.reading(bookId: "a"))
        XCTAssertEqual(store.session?.onScreen, true)
        XCTAssertEqual(store.session?.bookId, "a")
    }
    func testPopReadingClearsOnScreen() {
        let ud = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(userDefaults: ud)
        store.session = ReadingSession(bookId: "a", onScreen: true, offset: 5, chapterNumber: 1)
        let router = Router(settingsStore: store, repository: FakeRepository(books: []))
        router.didPopFromReading()
        XCTAssertEqual(store.session?.onScreen, false)
        XCTAssertEqual(store.session?.offset, 5) // offset preserved
    }
    func testBackAtRootDoesNotCrash() {
        let router = Router(settingsStore: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!), repository: FakeRepository(books: []))
        router.pop() // path empty
        XCTAssertEqual(router.path.count, 0)
        router.pop()
        XCTAssertEqual(router.path.count, 0)
    }
}
```

- [ ] **Step 2: Run — expect FAIL if hooks missing**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ReadingShellTests`
Expected: FAIL until `push` sets onScreen and `didPopFromReading` implemented; after Task 2 most PASS but this verifies.

- [ ] **Step 3: Implement ReadingShellView (planned)**

```swift
// apps/novels/Features/Reading/ReadingShellView.swift (planned)
import SwiftUI
struct ReadingShellView: View {
    let bookId: String
    @Bindable var router: Router
    @State private var settings = SettingsStore.shared
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Đang đọc: \(bookId)").font(.headline).foregroundStyle(Color(hex: 0x111111))
                Text("Nội dung sẽ hiển thị ở feat-004 (HTML → SwiftUI.Text)").font(.body).foregroundStyle(Color(hex: 0x6B7280)).multilineTextAlignment(.center).padding()
                Button("Tài liệu tham khảo") { router.push(.references) }.buttonStyle(.bordered).tint(Color(hex: 0x2563EB))
                Spacer(minLength: 200)
            }.padding(16)
        }
        .background(Color(hex: 0xFDFCF8))
        .navigationTitle("Đọc sách").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { router.didPopFromReading(); router.pop() } label: { HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Thư viện") } }.accessibilityLabel("Quay lại Thư viện")
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear { settings.session?.onScreen = true; settings.save() }
        .onDisappear { /* onScreen cleared only via back, not chapter change */ }
    }
}
```

Ensure Reading disables swipe-back per `navigation.md` §3: use `.interactiveDismissDisabled` or `.navigationBarBackButtonHidden` + custom back; verify back at root does not crash via `Router.pop` guard `if !path.isEmpty`.

- [ ] **Step 4: Run tests — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ReadingShellTests -only-testing:novelsTests/RouterTests`
Expected: PASS onScreen toggles, back guard.

- [ ] **Step 5: Run UI smoke**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsUITests/LaunchSmokeTests`
Expected: PASS app launches and Library header "Thư viện" exists (update smoke to check `app.navigationBars["Thư viện"].exists`).

- [ ] **Step 6: Commit reading shell**

```bash
git add apps/novels/Features/Reading/ReadingShellView.swift apps/novels/App/Router.swift
git commit -m "feat(002): add Reading shell with onScreen toggles"
```

**Handoff dependency:** Task 6 consumes all.

---

### Task 6: Verification, iPhone-only, Vietnamese strings, and handoff

**Files:**
- Modify: `features/feat-002.md` — fill Evidence with paths and commands (planned)
- Modify: `progress.md` — add done block after `./init.sh` PASS (planned, keep todo until orchestrator marks)
- Modify: `apps/novelsTests/Info.plist` / `apps/novelsUITests/Info.plist` if needed (no change expected)
- Test: all `apps/novelsTests/*` + `apps/novelsUITests/*` (planned)

**Interfaces:**
- Consumes: Tasks 1-5 outputs.
- Produces: green `./init.sh` + `xcodebuild test` + project verification that device family is 1, Vietnamese copy present, back-at-root safe, toast works.

- [ ] **Step 1: Run full unit and UI suites**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS all — `ToastCenterTests`, `RouterTests`, `LibraryViewModelTests`, `ReadingShellTests`, `DomainCodableTests` etc. + `LaunchSmokeTests`.

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: PASS — format `swiftformat --lint` 0/XX require formatting, lint `swiftlint lint --strict` 0 violations, build PASS iPhone 17 Pro 26.5, test PASS.

- [ ] **Step 3: Verify iPhone-only + Vietnamese copy + no forbidden imports**

Run: `grep -R "TARGETED_DEVICE_FAMILY" apps/novels.xcodeproj/project.pbxproj | grep "\"1\""` → should show `TARGETED_DEVICE_FAMILY = "1";`
Run: `grep -R "Thư viện\|Chưa có sách\|Thông tin sách\|Xóa sách\|Không tìm thấy sách" --include="*.swift" apps/novels`
Expected: hits in `LibraryView.swift`/`BookInfoSheet.swift`/`Router.swift`/`Toast`.

Run: `grep -R "SwiftData\|Core Data\|Keychain\|BGTaskScheduler\|WebKit" --include="*.swift" apps/novels/App apps/novels/Features apps/novels/SharedUI`
Expected: no output (Reader HTML parsing not in feat-002).

Run: `grep -R "Application Support/novels" --include="*.swift" apps/novelsTests | head`
Expected: only via `AppPaths`/`FileBookRepository` injection, not hard-coded real path assertions.

- [ ] **Step 4: Verify non-goals — no catalog/ZIP/reader/AI**

Run: `grep -R "catalog-api\|ai-service\|Prefetch\|ProcessedChapter" --include="*.swift" apps/novels/App apps/novels/Features | head`
Expected: no AI/prefetch import; only `ProcessedChapter` reference in repository boundary not used.

- [ ] **Step 5: Update feature handoff (after Task 1-5 actually done)**

Update `features/feat-002.md` Evidence with exact paths: `apps/novels/App/AppRoot.swift, Router.swift`, `apps/novels/SharedUI/LoadingView.swift, ToastView.swift, BottomSheetView.swift`, `apps/novels/Features/Library/LibraryView.swift, LibraryViewModel.swift, BookInfoSheet.swift`, `apps/novels/Features/Reading/ReadingShellView.swift`, `apps/novels/Resources/DesignTokens.swift`, tests `apps/novelsTests/*Tests.swift`, `xcodebuild test` PASS, `./init.sh` PASS. Keep State `todo` until user approves activation; do not mark `done`/`active` here in plan (orchestrator marks).

- [ ] **Step 6: Record final handoff**

Changed paths (planned): `features/feat-002.md` Evidence section, `progress.md` new block below template. Verify `swiftformat` and `swiftlint` clean.

**Rollback:** If NavigationStack path type mismatches, revert `Router.Route` to `String` rawValue; if sheet swipe conflicts, fallback to `alert` only for delete; if device family change breaks CI, keep `1` but ensure both Debug/Release aligned.

**Links:** `ARCHITECTURE.md`, `docs/decisions/ios-scope.md`, `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`, `docs/contracts/local-data.md`, `docs/contracts/book-package.md`, `docs/product/functional-specs/book-library.md`, `docs/product/flows.md` §1/§3, `docs/product/business-rules.md` BR-01/BR-10

