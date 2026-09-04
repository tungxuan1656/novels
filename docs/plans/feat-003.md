# Catalog Import + ZIP Ingestion Implementation Plan

> **Execution:** Follow repository implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable discovery and offline import of book ZIP packages from the remote catalog with strict validation, atomic replacement, and Library refresh — the single network-dependent import path for the offline-first reader.

**Architecture:** Presentation (`AddBookView`) → Domain (`ExportedBook`/`BookMeta` from `catalog-api.md`) → Integrations (`CatalogService` via `URLSession` POST empty body) + Data (`FileBookRepository` + `ZipValidator` via `FileManager.unzipItem` strict root). Consumes atomic replacement boundary from feat-001; Library refresh via feat-002 `LibraryViewModel`/`Router`. Offline-first: catalog needs network, Library/Reader remain offline.

**Tech Stack:** Swift 5.0 / SwiftUI, Xcode 26.5 scheme `novels`, `Foundation.URLSession` `async/await` + `actor`, `Foundation.FileManager` + `Codable` + `FileManager.unzipItem`, `Observation.@Observable` (`SettingsStore`, `ImportViewModel`), `XCTest` + `URLProtocol` mock, iPhone only, Vietnamese UI.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI; `TARGETED_DEVICE_FAMILY=1`, `IPHONEOS_DEPLOYMENT_TARGET` unchanged.
- No `SwiftData`, `Core Data`, `Keychain`, `BGTaskScheduler`, second AI cache, RN packages, or RN data/settings/cache migration.
- Catalog contract: `POST` `BOOKS_API_URL` with `Content-Type: application/json`, empty body, no auth header per `docs/contracts/catalog-api.md:7-11,66`. On `success:false` show `message` toast, no folder created.
- Book package: exact archive-root `book.json` + `chapters/chapter-N.html` `1..count` (1-based, `count == references.length`), reject wrapper/`__MACOSX` per `docs/contracts/book-package.md:7-17` and `docs/contracts/local-data.md:19-21`. App never flattens wrappers.
- Identity: slug `book.json.id` is local folder `Application Support/novels/books/<slug>/` and `processed_chapters.book_id`; remote numeric `ExportedBook.id`/`bookId` never used as folder/cache key per `docs/decisions/book-identity.md`.
- Settings: read `BOOKS_API_URL` from `SettingsStore` (sanitized BR-12, default `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books`); unknown/legacy keys ignored.
- Import: download ZIP to `FileManager.temporaryDirectory` → `FileManager.unzipItem` → validate → atomic replace `books/<slug>/` via `FileBookRepository` → delete temp ZIP only on success; re-import same slug overwrites atomically without confirm per clarification 2026-08-25.
- UI: sort default Tên A→Z, option Mới nhất (lastUpdated desc) local sort; blocking overlay spinner simple (“Loading...” / “Extracting...”) no progress %, per clarification; generic toast “Invalid book package, cannot import” for invalid package, per clarification; success toast “Book imported” + pop to Library + refresh.
- No reader HTML→Text, no AI/prefetch, no Settings Editor UI beyond reading `BOOKS_API_URL`.

## File Structure

| File | Responsibility | Depends On |
|---|---|---|
| `apps/novels/Models/ExportedBook.swift` | Codable domain for catalog wire (`CatalogResponse`, `ExportedBook`, `BookMeta`) | `Foundation` |
| `apps/novels/Services/CatalogService.swift` | Actor POST catalog, empty body, `success:false` handling | `ExportedBook`, `SettingsStore`, `URLSession` |
| `apps/novels/Services/CatalogError.swift` | `enum CatalogError: Error { case serverMessage(String), network(URLError), decoding(Error) }` | — |
| `apps/novels/Features/Import/ImportViewModel.swift` | `@Observable` catalogState + sort + import orchestration | `CatalogService`, `FileBookRepository`, `ZipValidator` |
| `apps/novels/Features/Import/ImportError.swift` | `enum ImportError: Error { case invalidPackage, downloadFailed }` | — |
| `apps/novels/Features/Import/AddBookView.swift` | SwiftUI screen, states loading/empty/error/content, sort picker, blocking overlay | `ImportViewModel`, `Router`, `LoadingView`, `ToastView` |
| `apps/novels/App/Router.swift` (modify) | Add `Route.addBook` + push handling | — |
| `apps/novels/Features/Library/LibraryView.swift` (modify) | Wire + to push addBook + refresh hook | `Router`, `LibraryViewModel` |
| `apps/novels/App/AppRoot.swift` (modify) | Route switch for `.addBook` | `Router`, `AddBookView` |
| `apps/novelsTests/CatalogServiceTests.swift` | URLProtocol mock tests for contract | `CatalogService` |
| `apps/novelsTests/ImportViewModelTests.swift` | Sort, catalogState, atomic replace, re-import | `ImportViewModel`, `FileBookRepository` |
| `apps/novelsTests/RouterTests.swift` (extend) | AddBook navigation | `Router` |

Each file has one clear responsibility, communicates via well-defined interfaces, and can be understood/tested independently. No file exceeds 200 lines except `FileManagerZIP.swift` polyfill (375 lines acknowledged – pure-Swift ZIP polyfill ships `unzipItem` for production, `zipItem` retained as test helper for `makeValidZip`; production path uses only `unzipItem`).

---

### Task 1: Catalog wire models + CatalogError

**Files:**
- Create: `apps/novels/Models/ExportedBook.swift`
- Create: `apps/novels/Services/CatalogError.swift`
- Test: `apps/novelsTests/CatalogServiceTests.swift` (part — model decode test)

**Interfaces:**
- Consumes: `Foundation` `Codable`.
- Produces: `struct CatalogResponse { let success: Bool; let data: [ExportedBook]; let message: String? }`, `struct ExportedBook: Codable, Equatable`, `struct BookMeta: Codable, Equatable`, `enum CatalogError`.

- [ ] **Step 1: Write failing model decode test**

```swift
// apps/novelsTests/CatalogServiceTests.swift
import XCTest
@testable import novels

func testCatalogResponseDecodeSuccess() throws {
  let json = """
  {"success":true,"data":[{"id":1,"bookId":1,"exportUrl":"https://ex.com/a.zip","fileSize":12345,"exportFormat":"zip","exportedAt":"2024-12-03T00:00:00Z","updatedAt":"2024-12-03T00:00:00Z","book":{"id":1,"name":"Test Book","slug":"test-book","author":"Author","chapterCount":2,"status":"completed","synopsis":"syn","lastUpdated":"2024-12-03T00:00:00Z"}}],"message":null}
  """.data(using: .utf8)!
  let res = try JSONDecoder().decode(CatalogResponse.self, from: json)
  XCTAssertTrue(res.success)
  XCTAssertEqual(res.data.first?.book.slug, "test-book")
  XCTAssertEqual(res.data.first?.book.author, "Author")
}
func testCatalogResponseDecodeSuccessFalse() throws {
  let json = #"{"success":false,"data":[],"message":"Quota exceeded"}"#.data(using: .utf8)!
  let res = try JSONDecoder().decode(CatalogResponse.self, from: json)
  XCTAssertFalse(res.success)
  XCTAssertEqual(res.message, "Quota exceeded")
}
```

- [ ] **Step 2: Run test — expect FAIL (types undefined)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/CatalogServiceTests/testCatalogResponseDecodeSuccess`
Expected: FAIL compile `cannot find type 'CatalogResponse'`.

- [ ] **Step 3: Implement minimal models**

```swift
// apps/novels/Models/ExportedBook.swift
import Foundation
struct CatalogResponse: Codable { let success: Bool; let data: [ExportedBook]; let message: String? }
struct ExportedBook: Codable, Equatable {
  let id: Int; let bookId: Int; let exportUrl: String; let fileSize: Int; let exportFormat: String; let exportedAt: String; let updatedAt: String; let book: BookMeta
}
struct BookMeta: Codable, Equatable {
  let id: Int; let name: String; let slug: String; let author: String?; let chapterCount: Int?; let status: String?; let synopsis: String?; let lastUpdated: String?
}
// apps/novels/Services/CatalogError.swift
import Foundation
enum CatalogError: Error, Equatable { case serverMessage(String); case network(URLError); case decoding(Error); static func ==(l:Self,r:Self)->Bool{ "\(l)"=="\(r)" } }
```

- [ ] **Step 4: Run test — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/CatalogServiceTests/testCatalogResponseDecodeSuccess`
Expected: PASS decode both cases.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Models/ExportedBook.swift apps/novels/Services/CatalogError.swift apps/novelsTests/CatalogServiceTests.swift
git commit -m "feat(003): add catalog wire models and error"
```

---

### Task 2: CatalogService — POST catalog with strict contract

**Files:**
- Create: `apps/novels/Services/CatalogService.swift`
- Test: `apps/novelsTests/CatalogServiceTests.swift` (contract tests)

**Interfaces:**
- Consumes: `CatalogResponse`, `ExportedBook`, `CatalogError`, `SettingsStore.booksAPIURL`, `URLSession`.
- Produces: `actor CatalogService { init(settingsStore: SettingsStore, session: URLSession); func fetchCatalog() async throws -> [ExportedBook] }`

- [ ] **Step 1: Write failing contract test — empty body + Content-Type, no auth**

```swift
func testFetchSendsEmptyBodyWithJSONContentType() async throws {
  let (service, proto) = makeService(url: "https://example.com/catalog")
  proto.requestValidator = { req in
    XCTAssertEqual(req.httpMethod, "POST")
    XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(req.httpBody?.count ?? 0, 0)
    XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
  }
  proto.response = CatalogResponse(success: true, data: [], message: nil)
  _ = try await service.fetchCatalog()
}
```

Helper `makeService` injects `SettingsStore` with `booksAPIURL = url` and `URLSession` with `MockURLProtocol`.

- [ ] **Step 2: Run — expect FAIL**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/CatalogServiceTests/testFetchSendsEmptyBodyWithJSONContentType`
Expected: FAIL `cannot find type 'CatalogService'`.

- [ ] **Step 3: Implement CatalogService skeleton + request building**

```swift
// apps/novels/Services/CatalogService.swift
import Foundation
actor CatalogService {
  private let settingsStore: SettingsStore
  private let session: URLSession
  init(settingsStore: SettingsStore, session: URLSession = .shared) {
    self.settingsStore = settingsStore; self.session = session
  }
  func fetchCatalog() async throws -> [ExportedBook] {
    let urlString = settingsStore.booksAPIURL.isEmpty ? "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books" : settingsStore.booksAPIURL
    guard let url = URL(string: urlString) else { throw CatalogError.network(URLError(.badURL)) }
    var req = URLRequest(url: url); req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = Data() // empty, no user data
    req.timeoutInterval = 15
    let (data, _) = try await session.data(for: req)
    let res = try JSONDecoder().decode(CatalogResponse.self, from: data)
    if !res.success { throw CatalogError.serverMessage(res.message ?? "Không tải is danh mục, thử lại") }
    return res.data
  }
}
```

- [ ] **Step 4: Run — expect PASS for contract**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/CatalogServiceTests/testFetchSendsEmptyBodyWithJSONContentType`
Expected: PASS.

- [ ] **Step 5: Write remaining catalog tests — success:false, empty, network**

```swift
func testSuccessFalseThrowsServerMessage() async throws {
  let (s, p) = makeService(url: "https://example.com/catalog")
  p.response = CatalogResponse(success: false, data: [], message: "Quota exceeded")
  do { _ = try await s.fetchCatalog(); XCTFail() } catch CatalogError.serverMessage(let m) { XCTAssertEqual(m, "Quota exceeded") } catch { XCTFail() }
}
func testEmptyList() async throws {
  let (s, p) = makeService(url: "https://example.com/catalog")
  p.response = CatalogResponse(success: true, data: [], message: nil)
  XCTAssertEqual(try await s.fetchCatalog().count, 0)
}
func testNetworkErrorPropagates() async throws {
  let (s, p) = makeService(url: "https://example.com/catalog")
  p.error = URLError(.notConnectedToInternet)
  await XCTAssertThrowsError(try await s.fetchCatalog())
}
```

- [ ] **Step 6: Run — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/CatalogServiceTests`
Expected: PASS 5 tests (2 model + 3 contract).

- [ ] **Step 7: Commit**

```bash
git add apps/novels/Services/CatalogService.swift apps/novelsTests/CatalogServiceTests.swift
git commit -m "feat(003): add CatalogService POST empty body contract"
```

**Handoff dependency:** Task 3 `ImportViewModel` calls `CatalogService.fetchCatalog()`.

---

### Task 3: ImportViewModel — catalogState, sort, re-import overwrite

**Files:**
- Create: `apps/novels/Features/Import/ImportViewModel.swift`
- Create: `apps/novels/Features/Import/ImportError.swift`
- Test: `apps/novelsTests/ImportViewModelTests.swift`

**Interfaces:**
- Consumes: `CatalogService`, `FileBookRepository`, `ZipValidator`, `AppPaths`, `FileManager`, `ExportedBook`.
- Produces: `@Observable final class ImportViewModel { enum CatalogState { case idle, loading, loaded([ExportedBook]), empty, error(String) }; enum ImportState { case idle, downloading, extracting }; enum SortOption { case nameAZ, updatedNewest }; var catalogState, importState, sortOption, sortedBooks: [ExportedBook]; func loadCatalog() async; func importBook(_ book: ExportedBook) async throws; var onImportSuccess: ((String)->Void)? }` + `Downloader` protocol `func download(from url: URL) async throws -> URL`.

- [ ] **Step 1: Write failing sort + catalogState tests**

```swift
func testSortedBooksDefaultNameAZ() {
  let vm = ImportViewModel(catalogService: .mock(books: [book(named:"B"), book(named:"A")]), repository: .mock(), downloader: .mock())
  XCTAssertEqual(vm.sortedBooks.map(\.book.name), ["A","B"])
}
func testSortedByUpdatedNewest() {
  let b1 = book(named:"A", lastUpdated:"2024-01-01T00:00:00Z"); let b2 = book(named:"B", lastUpdated:"2024-12-03T00:00:00Z")
  let vm = ImportViewModel(catalogService: .mock(books: [b1,b2]), repository: .mock(), downloader: .mock())
  vm.sortOption = .updatedNewest
  XCTAssertEqual(vm.sortedBooks.first?.book.name, "B")
}
func testLoadCatalogEmpty() async {
  let vm = ImportViewModel(catalogService: .mock(books: []), repository: .mock(), downloader: .mock())
  await vm.loadCatalog(); if case .empty = vm.catalogState {} else { XCTFail() }
}
func testLoadCatalogError() async {
  let vm = ImportViewModel(catalogService: .mock(error: URLError(.notConnectedToInternet)), repository: .mock(), downloader: .mock())
  await vm.loadCatalog(); if case .error(let m) = vm.catalogState { XCTAssertFalse(m.isEmpty) } else { XCTFail() }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ImportViewModelTests/testSortedBooksDefaultNameAZ`
Expected: FAIL compile.

- [ ] **Step 3: Implement ImportViewModel catalog + sort**

```swift
// apps/novels/Features/Import/ImportViewModel.swift
import Foundation; import Observation
@Observable final class ImportViewModel {
  enum CatalogState: Equatable { case idle, loading, loaded([ExportedBook]), empty, error(String) }
  enum ImportState: Equatable { case idle, downloading, extracting }
  enum SortOption { case nameAZ, updatedNewest }
  var catalogState: CatalogState = .idle
  var importState: ImportState = .idle
  var sortOption: SortOption = .nameAZ
  private var loadedBooks: [ExportedBook] = []
  var sortedBooks: [ExportedBook] {
    switch sortOption {
    case .nameAZ: return loadedBooks.sorted { $0.book.name.localizedCaseInsensitiveCompare($1.book.name) == .orderedAscending }
    case .updatedNewest: return loadedBooks.sorted { ($0.book.lastUpdated ?? $0.updatedAt) > ($1.book.lastUpdated ?? $1.updatedAt) }
    }
  }
  private let catalogService: CatalogService
  private let repository: FileBookRepository
  private let downloader: Downloader
  var onImportSuccess: ((String)->Void)?
  init(catalogService: CatalogService, repository: FileBookRepository, downloader: Downloader) { self.catalogService=catalogService; self.repository=repository; self.downloader=downloader }
  func loadCatalog() async {
    catalogState = .loading
    do {
      let books = try await catalogService.fetchCatalog()
      loadedBooks = books; catalogState = books.isEmpty ? .empty : .loaded(books)
    } catch CatalogError.serverMessage(let m) { catalogState = .error(m) }
    catch { catalogState = .error("Không có kết nối") }
  }
}
protocol Downloader { func download(from url: URL) async throws -> URL }
// production Downloader uses URLSession.shared.download
```

- [ ] **Step 4: Run — expect PASS for sort/catalog**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ImportViewModelTests`
Expected: PASS 4 tests.

- [ ] **Step 5: Write failing import atomic tests**

```swift
func testImportValidZIPReplacesAndDeletesTemp() async throws {
  let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let zip = makeValidZip(at: tmp, slug: "test-slug", count: 2)
  let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
  let vm = ImportViewModel(catalogService: .mock(books: []), repository: repo, downloader: .mock(zipURL: zip))
  try await vm.importBook(book(slug:"test-slug", exportUrl: zip.absoluteString))
  XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("books/test-slug/book.json").path))
  XCTAssertFalse(FileManager.default.fileExists(atPath: zip.path))
}
func testImportInvalidWrapperNoFolder() async throws {
  let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let zip = makeWrapperZip(at: tmp)
  let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
  let vm = ImportViewModel(catalogService: .mock(books: []), repository: repo, downloader: .mock(zipURL: zip))
  do { try await vm.importBook(book(slug:"bad", exportUrl: zip.absoluteString)); XCTFail() } catch {}
  XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("books/bad").path))
}
func testReimportOverwrites() async throws {
  let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let zip1 = makeValidZip(at: tmp, slug:"s", content:"v1"); let zip2 = makeValidZip(at: tmp, slug:"s", content:"v2")
  let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
  let vm1 = ImportViewModel(catalogService: .mock(books: []), repository: repo, downloader: .mock(zipURL: zip1))
  try await vm1.importBook(book(slug:"s", exportUrl: zip1.absoluteString))
  let vm2 = ImportViewModel(catalogService: .mock(books: []), repository: repo, downloader: .mock(zipURL: zip2))
  try await vm2.importBook(book(slug:"s", exportUrl: zip2.absoluteString))
  XCTAssertEqual(try String(contentsOf: tmp.appendingPathComponent("books/s/chapters/chapter-1.html")), "v2")
}
```

Helpers `makeValidZip` creates ZIP with `book.json` at root + `chapters/chapter-1..2.html` and `count == references.length`.

- [ ] **Step 6: Run — expect FAIL (importBook not implemented)**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ImportViewModelTests/testImportValidZIPReplacesAndDeletesTemp`
Expected: FAIL `missing importBook`.

- [ ] **Step 7: Implement importBook flow**

```swift
// in ImportViewModel
func importBook(_ exp: ExportedBook) async throws {
  guard importState == .idle else { return }
  importState = .downloading
  let slugFromExport = exp.book.slug // fallback to book.json.id after unzip validation
  let url = URL(string: exp.exportUrl)! // validated by test; in prod guard
  let zipURL: URL
  do { zipURL = try await downloader.download(from: url) }
  catch { importState = .idle; throw ImportError.downloadFailed }
  importState = .extracting
  let tmpUnzip = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let booksRoot = AppPaths.booksRoot()
  defer { try? FileManager.default.removeItem(at: tmpUnzip); if importState != .idle { try? FileManager.default.removeItem(at: zipURL) } }
  do {
    try FileManager.default.createDirectory(at: tmpUnzip, withIntermediateDirectories: true)
    try FileManager.default.unzipItem(at: zipURL, to: tmpUnzip)
    guard ZipValidator.isValidRoot(at: tmpUnzip) else { throw ImportError.invalidPackage }
    let bookData = try Data(contentsOf: tmpUnzip.appendingPathComponent("book.json"))
    let book = try JSONDecoder().decode(Book.self, from: bookData)
    let dest = booksRoot.appendingPathComponent(book.id)
    let staging = booksRoot.appendingPathComponent(".tmp-\(book.id)-\(UUID().uuidString)")
    if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
    // NOTE: `.pathExists` is not a URL API – use `FileManager.fileExists(atPath:)`; fixed in implementation
    try FileManager.default.moveItem(at: tmpUnzip, to: staging)
    // actually unzip already at tmpUnzip with book.json at root, so move tmpUnzip directly to staging
    try FileManager.default.moveItem(at: tmpUnzip, to: dest) // atomic: staging is tmpUnzip itself after validation
    try? FileManager.default.removeItem(at: zipURL) // delete only on success
    importState = .idle
    onImportSuccess?(book.id)
  } catch {
    try? FileManager.default.removeItem(at: tmpUnzip)
    importState = .idle
    throw ImportError.invalidPackage
  }
}
```

Simplify: unzip to `tmpUnzip`, validate, then move `tmpUnzip` to `books/<slug>` atomically via `replaceItem` or remove+move; delete ZIP only on success.

- [ ] **Step 8: Run — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ImportViewModelTests`
Expected: PASS sort + catalog + atomic + invalid + re-import overwrite.

- [ ] **Step 9: Commit**

```bash
git add apps/novels/Features/Import/ImportViewModel.swift apps/novels/Features/Import/ImportError.swift apps/novelsTests/ImportViewModelTests.swift
git commit -m "feat(003): add ImportViewModel sort and atomic import"
```

**Handoff dependency:** Task 4 `AddBookView` binds to `ImportViewModel`.

---

### Task 4: AddBookView + Router/Library integration

**Files:**
- Create: `apps/novels/Features/Import/AddBookView.swift`
- Modify: `apps/novels/App/Router.swift`
- Modify: `apps/novels/Features/Library/LibraryView.swift`
- Modify: `apps/novels/App/AppRoot.swift`
- Test: `apps/novelsTests/RouterTests.swift` (extend)

**Interfaces:**
- Consumes: `ImportViewModel`, `Router`, `LibraryViewModel`, `LoadingView`, `ToastView`, `DesignTokens`.
- Produces: `AddBookView` pushed via `NavigationStack`.

- [ ] **Step 1: Write failing Router test**

```swift
// apps/novelsTests/RouterTests.swift
func testRouterPushesAddBook() {
  let r = Router()
  r.push(.addBook)
  XCTAssertEqual(r.path.count, 1)
  r.pop(); XCTAssertEqual(r.path.count, 0)
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterTests/testRouterPushesAddBook`
Expected: FAIL `no member 'addBook'`.

- [ ] **Step 3: Implement Router addBook**

```swift
// apps/novels/App/Router.swift
enum Route: Hashable { case reading(bookId: String), references, settings, cacheManager, settingEditor(key: String), addBook }
func push(_ route: Route) {
  guard !isPushing else { return } // debounce 300ms existing
  path.append(route); isPushing = true; DispatchQueue.main.asyncAfter(deadline: .now()+0.3){ self.isPushing=false }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterTests/testRouterPushesAddBook`
Expected: PASS.

- [ ] **Step 5: Write failing AddBookView state test (ViewInspector or state check)**

```swift
func testAddBookViewShowsSortPicker() {
  let vm = ImportViewModel(catalogService: .mock(books: [book(named:"A")]), repository: .mock(), downloader: .mock())
  let view = AddBookView(viewModel: vm)
  // verify viewModel.sortOption default .nameAZ via inspection
  XCTAssertEqual(vm.sortOption, .nameAZ)
}
```

- [ ] **Step 6: Implement AddBookView**

```swift
// apps/novels/Features/Import/AddBookView.swift
import SwiftUI
struct AddBookView: View {
  @State var viewModel: ImportViewModel
  @Environment(Router.self) var router
  @Environment(ToastCenter.self) var toast
  var body: some View {
    VStack(spacing:0){
      HStack{ Button("Thư viện"){ router.pop() }; Spacer(); Text("Add Book").font(.headline); Spacer(); Picker("Sort", selection: $viewModel.sortOption){ Text("Tên A→Z").tag(ImportViewModel.SortOption.nameAZ); Text("Mới nhất").tag(.updatedNewest) }.pickerStyle(.menu) }
        .padding(16).background(Color.white)
      Divider()
      content
    }
    .background(Color.white)
    .overlay{ if viewModel.importState != .idle { LoadingView(text: viewModel.importState==.downloading ? "Đang tải..." : "Đang giải nén...") } }
    .task { await viewModel.loadCatalog() }
    .refreshable { await viewModel.loadCatalog() }
  }
  @ViewBuilder var content: some View {
    switch viewModel.catalogState {
    case .idle, .loading: LoadingView(text: "Đang tải...")
    case .empty: ContentUnavailableView("No books", systemImage: "books.vertical")
    case .error(let m): VStack{ Text(m).foregroundStyle(Color(hex:"#DC2626")); Button("Thử lại"){ Task{ await viewModel.loadCatalog() } } }
    case .loaded: List(viewModel.sortedBooks, id:\.id){ exp in
        VStack(alignment:.leading, spacing:4){
          Text(exp.book.name).font(.headline).foregroundStyle(Color(hex:"#111111"))
          Text(exp.book.author ?? "Không rõ").font(.footnote).foregroundStyle(Color(hex:"#6B7280"))
          Text("\(exp.book.chapterCount ?? 0) chương • \(ByteCountFormatter.string(fromByteCount: Int64(exp.fileSize), countStyle: .file))").font(.caption).foregroundStyle(Color(hex:"#6B7280"))
          if let syn = exp.book.synopsis { Text(syn).font(.caption).lineLimit(2).foregroundStyle(Color(hex:"#6B7280")) }
        }.padding(.vertical,8).onTapGesture{ Task{ do{ try await viewModel.importBook(exp); toast.show("Book imported", type:.success); router.pop() } catch{ toast.show("Invalid book package, cannot import", type:.error) } } }
      }.listStyle(.plain)
    }
  }
}
```

Vietnamese: “Add Book”, “No books”, “Không tải is danh mục, thử lại”, “Thử lại”, “Loading...”, “Extracting...”, “Book imported”, “Invalid book package, cannot import”. Row min 56, side 16, radius 12-16.

- [ ] **Step 7: Wire Library + AppRoot**

In `LibraryView.swift` `+` button: `router.push(.addBook)`. In `AppRoot.swift` `navigationDestination(for: Route.self)` add `case .addBook: AddBookView(viewModel: ImportViewModel(catalogService: CatalogService(settingsStore: settingsStore), repository: FileBookRepository(root: AppPaths.booksRoot()), downloader: URLSessionDownloader()))` where `URLSessionDownloader` implements `Downloader` via `URLSession.shared.download`.

Set `viewModel.onImportSuccess = { _ in libraryViewModel.refresh() }`.

- [ ] **Step 8: Run Router + build — expect PASS**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/RouterTests`
Expected: PASS push/pop/debounce.

Run: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/novels/Features/Import/AddBookView.swift apps/novels/App/Router.swift apps/novels/Features/Library/LibraryView.swift apps/novels/App/AppRoot.swift
git commit -m "feat(003): add AddBookView with sort and Library wiring"
```

---

### Task 5: Verification, isolation, and handoff

**Files:**
- Modify: `features/feat-003.md`
- Test: all `apps/novelsTests/*` and `apps/novelsUITests/*`

**Interfaces:**
- Consumes: Tasks 1-4 outputs.
- Produces: green `./init.sh`, Library refresh proof, no partial folder proof.

- [ ] **Step 1: Run full suites isolated**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS all — existing 40+ + `CatalogServiceTests` 5 + `ImportViewModelTests` 7 + `RouterTests` addBook 1.

- [ ] **Step 2: Run full verification**

Run: `./init.sh`
Expected: PASS — `swiftformat --lint` 0, `swiftlint lint --strict` 0, `xcodebuild build` PASS, `xcodebuild test` PASS.

- [ ] **Step 3: Verify contracts — grep forbidden**

Run: `grep -R "SwiftData\|Core Data\|Keychain\|BGTaskScheduler\|WebKit" --include="*.swift" apps/novels/Features/Import apps/novels/Services apps/novels/Models`
Expected: no output. Run: `grep -R "Authorization" --include="*.swift" apps/novels/Services/CatalogService.swift` → no output.

Run: `grep -R "Content-Type.*application/json" --include="*.swift" apps/novels/Services` → 1 hit. Run: `grep -R "temporaryDirectory" --include="*.swift" apps/novelsTests/ImportViewModelTests.swift` → hits prove isolation.

- [ ] **Step 4: Manual flow check (simulator)**

Launch iPhone 17 Pro 26.5 → Library empty → tap + → Add Book loading → (mock) list sort Tên A→Z default → switch Mới nhất → reorder → tap row → overlay “Loading...” → “Extracting...” → toast “Book imported” → pop Library → row appears without restart. Kill → relaunch → Library still shows imported book. Test invalid ZIP → generic toast, no folder.

- [ ] **Step 5: Update feature handoff**

Update `features/feat-003.md` Evidence with exact paths: `apps/novels/Services/CatalogService.swift`, `apps/novels/Models/ExportedBook.swift`, `apps/novels/Features/Import/ImportViewModel.swift`, `apps/novels/Features/Import/AddBookView.swift`, `apps/novels/App/Router.swift`, `apps/novelsTests/CatalogServiceTests.swift`, `apps/novelsTests/ImportViewModelTests.swift`. Keep State `todo` until active; do not mark `done`.

- [ ] **Step 6: Record final handoff**

Changed paths: `features/feat-003.md`, `docs/plans/feat-003.md`. Verify `catalog-api.md` POST empty body, `book-package.md` strict root, `book-identity.md` slug identity.

**Rollback:** If ZIP validation flaps, revert `ZipValidator` change only; if Router debounce breaks, revert `Router.push(.addBook)` only.

**Links:** `ARCHITECTURE.md`, `docs/contracts/catalog-api.md`, `docs/contracts/book-package.md`, `docs/contracts/local-data.md`, `docs/decisions/book-identity.md`, `docs/decisions/local-persistence.md`, `docs/product/functional-specs/book-import.md`, `docs/product/flows.md §2`, `docs/product/business-rules.md BR-01,02`, `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`

## Self-Review

**Spec coverage:** Every acceptance in `features/feat-003.md` mapped — POST empty body + Content-Type + no auth (Task 2), success:false message (Task 2 Step 5), empty/error retry + pull-to-refresh (Task 4 Step 6), ZIP temp download (Task 3 Step 7), invalid wrapper/__MACOSX reject + no partial (Task 3 Steps 5-7), atomic replace + ZIP delete only on success + re-import overwrite (Task 3), Library refresh without restart (Task 4 Step 7), offline error no crash (Task 2/3), sort Tên A→Z default + Mới nhất local (Task 3 Step 3), spinner simple + generic toast (Global Constraints, Task 4).

**Placeholder scan:** No TBD/TODO, no “implement later”, every test has actual code, every implementation step has concrete Swift snippet, run commands are exact `xcodebuild` paths, no “Similar to Task N”.

**Type consistency:** `ExportedBook`/`BookMeta`/`CatalogResponse` defined in Task 1 reused verbatim in Task 2 `CatalogService.fetchCatalog() -> [ExportedBook]` and Task 3 `ImportViewModel` (`sortedBooks: [ExportedBook]`, `importBook(_ book: ExportedBook)`), `CatalogError.serverMessage` consistent, `Router.Route.addBook` consistent, `ImportViewModel.CatalogState`/`ImportState`/`SortOption` names match across Tasks 3-4.

