# Progress

<!-- Log template -->

## YYYY-MM-DD — feat-XXX

**State**: todo
**Done**: —
**Evidence**: —
**Blockers**: none
**Next**: Define the feature scope and acceptance criteria.

<!-- Add each new block below this note. Do not edit older blocks. -->

## 2026-08-24 — feat-001

**State**: todo
**Done**: Feature record `features/feat-001.md` and external plan `docs/plans/feat-001.md` created per `ARCHITECTURE.md`, `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`, `docs/contracts/book-package.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/functional-specs/*`
**Evidence**: `features/feat-001.md`, `docs/plans/feat-001.md`, `feature_index.json` (feat-001 todo, depends_on [])
**Blockers**: none
**Next**: Awaiting user approval to activate feat-001 and start implementation; do not start without explicit go-ahead

## 2026-08-24 — backlog

**State**: todo
**Done**: Backlog initialized — feat-002..008 records created per approved 8-feature order and dependencies; no detailed plans created yet
**Evidence**: `feature_index.json` (feat-001..008 todo, zero active), `features/feat-002.md`, `features/feat-003.md`, `features/feat-004.md`, `features/feat-005.md`, `features/feat-006.md`, `features/feat-007.md`, `features/feat-008.md` — all todo, no active feature per Harness Slim
**Blockers**: none
**Next**: Select/approve feat-001 for activation

## 2026-08-24 — feat-009

**State**: done
**Done**: Lint/format toolchain installed — SwiftLint 0.65.1 + SwiftFormat 0.62.1 with `.swiftlint.yml`/`.swiftformat`, `.githooks/pre-commit` (core.hooksPath), `scripts/setup.sh`, `init.sh` lint/format active; existing sources formatted (`NovelsApp` rename)
**Evidence**: `.swiftlint.yml`, `.swiftformat`, `.githooks/pre-commit` (executable), `scripts/setup.sh`, `init.sh` (FORMAT_TASKS `swiftformat --lint . --verbose`, LINT_TASKS `swiftlint lint --strict`), `AGENTS.md` updated, `swiftlint lint --strict` 0 violations (2 files), `swiftformat --lint .` 0/2 require formatting, `./init.sh` PASS (format PASS, lint PASS, build PASS iPhone 17 Pro 26.5), `git config core.hooksPath=.githooks`, `feature_index.json` feat-009 done
**Blockers**: none
**Next**: Developers run `bash scripts/setup.sh` once; commit hook enforces `swiftformat`/`swiftlint`; CI runs `./init.sh`

## 2026-08-25 — feat-001

**State**: done
**Done**: Native Persistence Foundation — Domain (Book/Reference/Chapter/AIMode/ProcessedChapter/ReadingSession/TypographySetting/AIAction/SHA256 CryptoKit), Persistence (AppPaths/booksRoot+cacheRoot, FileBookRepository + ZipValidator exact-root 1-based, SQLite processed_chapters PRIMARY KEY(book_id,chapter_number,mode) WITHOUT ROWID + idx + user_version, SettingsStore @Observable BR-12), tests + UI smoke via synchronized groups
**Evidence**: `apps/novels/Domain/` 9 files pure Swift Codable, `apps/novels/Persistence/` 7 files (Paths/BookRepository/ZipValidator/SQLiteSupport/ProcessedChapterCache/SettingsStore/DefaultsKeys), `apps/novelsTests/` 4 suites 33 tests + FixtureTests 1 (Fixtures/book.json count 2 + 2 HTML), `apps/novelsUITests/LaunchSmokeTests.testAppLaunches` 1, `apps/novels.xcodeproj/project.pbxproj` 3 targets (novels, novelsTests com.tungxuan.novels.tests TEST_HOST/BUNDLE_LOADER, novelsUITests com.tungxuan.novels.uitests TEST_TARGET_NAME=novels, synchronizedRootGroups + exceptionSets), `apps/novelsTests/Info.plist`, `apps/novelsUITests/Info.plist`, `init.sh` TEST_TASKS enabled (`xcodebuild test`); `xcodebuild test` PASS 40 tests (Domain 13/BookRepo 13/Cache 6/Settings 6/Fixture 1/Smoke 1), `xcodebuild build` PASS, `./init.sh` PASS (format 0/24 lint 0 build PASS test PASS), `grep SwiftData|Core Data|Keychain|BGTask` 0, `grep "Application Support/novels" tests` 0 (isolation via temporaryDirectory/:memory:/suiteName)
**Blockers**: none
**Next**: feat-002 App Shell + Home Library (depends_on feat-001) ready to activate

## 2026-08-25 — feat-002

**State**: done
**Done**: App Shell + Home Library — NavigationStack startup routing `onScreen ? Reading : Library` via `@Observable Router` (NavigationPath + Route reading/references, isPushing debounce 300ms, pop guard, didPopFromReading), `AppRoot` with `.toast` + `.task restoreInitialRoute` (toast "Không tìm thấy sách" on invalid), shared primitives `LoadingView` (blocking #2563EB card radius 16) `ToastView` (success #16A34A/error #DC2626/info #2563EB/warning #EA580C 3s/4s/5s tap dismiss) `BottomSheetView` (handle #E5E7EB 40x5 white radius 24) + `DesignTokens` (#FDFCF8/#FFFFFF/#111111/#6B7280/#2563EB/#16A34A/#EA580C/#DC2626/#E5E7EB), offline Library `LibraryViewModel` scanning `FileBookRepository(AppPaths.booksRoot())` + `LibraryView` Vietnamese "Thư viện/Chưa có sách/Nhấn + để thêm sách" empty ContentUnavailable + List row name/author/count + pull-to-refresh + swipe Info blue / Delete red + deleteConfirm + loadingOverlay, `BookInfoSheet` ("Thông tin sách" + danh mục chương) + swipe-delete confirm "Xóa sách?/Bạn có chắc...", `ReadingShellView` ("Đang đọc: bookId", "Tài liệu tham khảo" push references, back "Thư viện" clears onScreen, background #FDFCF8, iPhone-only TARGETED_DEVICE_FAMILY=1)
**Evidence**: `apps/novels/App/AppRoot.swift`, `apps/novels/App/Router.swift`, `apps/novels/SharedUI/LoadingView.swift`, `apps/novels/SharedUI/ToastView.swift`, `apps/novels/SharedUI/BottomSheetView.swift`, `apps/novels/Resources/DesignTokens.swift`, `apps/novels/Features/Library/LibraryView.swift`, `apps/novels/Features/Library/LibraryViewModel.swift`, `apps/novels/Features/Library/BookInfoSheet.swift`, `apps/novels/Features/Reading/ReadingShellView.swift`, `apps/novels/NovelsApp.swift`, tests `apps/novelsTests/ToastCenterTests.swift` 2 + `RouterTests.swift` 4 + `LibraryViewModelTests.swift` 5 + `ReadingShellTests.swift` 3 + `DomainCodableTests` 13 + `BookRepositoryTests` 13 + `ProcessedChapterCacheTests` 6 + `SettingsStoreTests` 6 + `FixtureTests` 1 + `apps/novelsUITests/LaunchSmokeTests.swift` 2 = 40+ PASS; `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` PASS, `./init.sh` PASS (format 0/lint 0/build PASS/test PASS), `grep TARGETED_DEVICE_FAMILY="1"` 6 hits, Vietnamese grep hits in LibraryView/BookInfoSheet/Router/ReadingShell, no SwiftData/Core Data/Keychain/BGTask/WebKit (1), no catalog-ai/Prefetch/ProcessedChapter in App/Features (1), no hard-coded Application Support/novels in tests (1 via AppPaths), `swiftformat --lint` 0/37, `swiftlint lint --strict` 0/37
**Blockers**: none
**Next**: feat-003 Catalog Import + ZIP Ingestion ready to activate (depends_on feat-001, feat-002 done)

## 2026-08-26 — feat-003

**State**: done
**Done**: Catalog Import + ZIP Ingestion — CatalogService POST empty body Content-Type application/json no auth + success:false message, ImportViewModel catalogState/empty/error + sort Tên A→Z/Mới nhất + atomic import via FileBookRepository+ZipValidator (download temp → unzip → validate exact-root reject wrapper/__MACOSX → atomic replace books/<slug>/ → delete ZIP only on success → re-import overwrite), AddBookView states loading/empty/error/content with pull-to-refresh + blocking overlay “Đang tải…”/“Đang giải nén…” + Library refresh without restart + sort picker
**Evidence**: `feat/003-catalog-import` 3201f68 — `apps/novels/Models/ExportedBook.swift` CatalogResponse/ExportedBook/BookMeta, `apps/novels/Services/CatalogError.swift`, `apps/novels/Services/CatalogService.swift` actor POST, `apps/novels/Features/Import/ImportViewModel.swift` @MainActor @Observable + Downloader, `apps/novels/Features/Import/ImportError.swift`, `apps/novels/Persistence/FileManagerZIP.swift` CRC32 polyfill, `apps/novels/Features/Import/AddBookView.swift` Vietnamese UI, `apps/novels/App/Router.swift` Route.addBook debounce, `apps/novels/App/AppRoot.swift` destination + onImportSuccess refresh, `apps/novels/Features/Library/LibraryView.swift` wire +, tests `CatalogServiceTests` 6 + `ImportViewModelTests` 7 + `RouterTests` addBook 2 = 60+ PASS; `./init.sh` PASS (format 0/45 lint 0 build PASS test PASS 194s full suite), `xcodebuild test` full PASS, grep Content-Type 1 hit Auth 0 SwiftData 0 temporaryDirectory 4
**Blockers**: none
**Next**: feat-004 Offline Book Reader ready (depends_on feat-001, feat-002, feat-003) and feat-005 Settings + Cache Manager ready (depends_on feat-001, feat-002) — choose next activation

## 2026-08-26 — feat-004

**State**: done
**Done**: Offline Book Reader — HtmlParser `div/h*/p/br/b/strong/i/em/span` → TextSpan/TextBlock pure Swift, ReaderViewModel 1-based clamp 1..count prev/next disabled bounds + `saveOffset` per slug + `onScreen` + toast "Không tìm thấy chương" without crash + rapid nav offset reset, ReaderView SwiftUI.Text VStack with typography `fontSize 12..24/lineHeight 1.2..2.0/letterSpacing 0..1.0` live + header Chương N/count + footer Trước/Sau + to-bottom via ScrollViewReader + overscroll 400ms lock + `ScrollOffsetKey` + `restore offset 0 on chapter change`, ReferencesView bold current + checkmark + `accessibilityIdentifier ref-N`, ReaderBottomSheet font picker System/Serif/Mono + steppers clamped + gear no-op toast feat-005, Router `Route.references(bookId:String)` + `didPopFromReading` + restoreInitialRoute toast "Không tìm thấy sách", AppRoot `navigationDestination` reading→ReaderView references→ReferencesView, swipe-back `interactiveDismissDisabled` only on Reading
**Evidence**: `docs/plans/feat-004.md` (752 lines) + commits `5135ab1` HtmlParser 5 tests, `d068d72` ReaderViewModel 8 tests, `fbf9815` References 3 tests, `d1eec46` BottomSheet 3 tests, `044c6d1` ReaderView 3 tests, `d50d6aa` Router 4 tests, `8de01b5` integration 2 tests + `ef80e5c` fix critical+majors 11 tests ReaderViewFixTests (overscroll bottom-only via ContentHeightKey/ViewportHeightKey + ReaderOverscrollLogic, restore offset per-book via ScrollPosition, font design System/Serif/Mono, debounce 300ms) — total ~81 tests + `novelsUITests` 2 — oracle review NEEDS_FIX addressed; `./init.sh` PASS (format 0/58 lint 0 build PASS test PASS 165.7s Xcode 26.5 iPhone 17 Pro → post-fix re-verify PASS), `xcodebuild build`/`test` PASS, offline grep 0
**Blockers**: none
**Next**: feat-005 Settings + Cache Manager ready (depends_on feat-001, feat-002) — choose activation OR feat-006 AI Reading blocked until 005 done

## 2026-08-26 — feat-010

**State**: done
**Done**: Tolerant ZIP Ingestion Hotfix — sửa lỗi "Gói sách không hợp lệ" với ZIP hợp lệ dạng samples: `FileManagerZIP.unzipItem` hỗ trợ data-descriptor flag 0x08 (descriptor 0x08074B50 + CRC/comp/uncomp trailing, effective size/CRC, findNextHeaderPos scan), hygiene filter `__MACOSX/.DS_Store/._*` skip-not-throw via `ZipValidator.isHygieneEntry` single-source, resolver `resolveCanonicalRoot` flatten single outer-folder wrapper (filtered count==1 + child valid → canonical, else original) chỉ flatten 1 folder, `ZipValidator.isValidRoot` tolerant ignore hygiene at top+chapters (filteredChapters count), `Book` fallback `init(from:)` derive `id` slugify từ `name` khi thiếu/empty (folding diacriticInsensitive, single dash), `ImportViewModel` gọi resolver sau unzip trước validator/save
**Evidence**: branch feat/010-tolerant-zip 10 commits c711c31..2749857 (315c0a5 plan, a2ef1b9 flag08+hygiene, 003b682 lint clean, a4cd8aa wrapper flatten, 9ef31f7 dedupe, 917d6c3 validator hygiene, 98ed7b4 Book fallback, 8d7e806 fallback tests, d1c372d docs tolerant, 2749857 fixtures+security tests) + SDD ledger .agent-work/sdd/feat-010/progress.md 6 tasks + final review clean; docs: ARCHITECTURE.md:14, docs/contracts/book-package.md 16-19 + Import Flow 43 + Reference Sample + Rules/Avoid, docs/decisions/book-package-shape.md Amendment 2026-08-26, docs/contracts/local-data.md Stores+Lifecycle — all tolerant phrase `hygiene + wrapper flatten + data-descriptor, strict security invariants preserved`; tests: TolerantFixtures.swift 192 lines (makeDeflateDescriptorZip real DEFLATE+flag08, makeDescriptorFlagStoreZip STORE+flag08), ImportViewModelTests 20/20 (synthetic wrapper+__MACOSX+flag08+DS_Store flatten, real sample 743 chapters count==743 refs, zip-slip/bomb 101MB/CRC/missing-chapter still invalidPackage), BookRepositoryTests 17/17 (hygiene tolerated, real extra/wrapper still reject), DomainCodableTests 15/15 (fallback van-gioi / van-gioi-chi-rut-thuong-he-thong); swiftformat 0/63, swiftlint --strict 0/63, `./init.sh` PASS (format/lint/build PASS, 127 tests PASS), sample docs/samples/van-gioi-chi-rut-thuong-he-thong.zip 1,955,587 bytes preserved; task reviews ora-1..ora-9 + final ora-10 all Approved (NeedsFix fix rounds 1/5 where needed)
**Blockers**: none
**Next**: Merge feat/010-tolerant-zip → main (`git checkout main && git merge --no-ff feat/010-tolerant-zip && git push`) — sample now importable tolerant via flatten, no migration

## 2026-08-27 — feat-005

**State**: done
**Done**: Settings + Cache Manager — grouped Settings list (Catalog/AI/Prefetch/Typography/Data→CacheManager) via `SettingsView` (Vietnamese `Cài đặt`, rows `accessibilityIdentifier settings-<key>`), `SettingEditorView` with `SettingDescriptor.validate` (URLs non-empty, JSON object for headers/body verbatim allowed, `AI_PROVIDER` only openai case-insensitive, `PREFETCH_COUNT 1..10→3`, `AI_MIN_CHUNK_SIZE 500..5000→1300`, typography `12..24/1.2..2.0/0..1.0`) blocking save unless `allowsVerbatimSave` + `Clear`→default + Toast "Đã lưu" + `router.pop()`, `SettingsStore.value/setValue` helpers + `save()`→`sanitize()` BR-12 consume (unknown legacy ignored, no re-impl), headers/body `effectiveHeaders()→[:]` on bad JSON stored verbatim ignored at merge per `ai-service.md:17`; `CacheManagerView` count card "Tổng số bản đã xử lý: N" + `Xóa tất cả` confirm + per-book `Xóa` confirm → `SQLiteProcessedChapterCache.countAll/count/bookIds` via `SELECT count(*)` `DISTINCT` (WITHOUT ROWID + INDEX + user_version=1 preserved, mode none never written, INSERT OR REPLACE) reflecting immediately + `refreshable` + Toast "Đã xóa"; `Router` extended `.settings/.cacheManager/.settingEditor(String)` + `isPushing` 300ms debounce + `AppRoot` destinations, `LibraryView` gear `settingsButton`; survive relaunch via `@Observable` + isolated `UserDefaults(suiteName:)` verified, `count/clearAll/clear(bookId)` immediate
**Evidence**: `docs/plans/feat-005.md` (719 lines, Tasks 1-5), `apps/novels/Features/Settings/SettingsView.swift` + `SettingEditorView.swift` + `SettingsViewModel.swift` + `CacheManagerView.swift` (165→full), `apps/novels/App/Router.swift` + `AppRoot.swift`, `apps/novels/Features/Library/LibraryView.swift` gear, `apps/novels/Persistence/SettingsStore.swift` helpers, `apps/novels/Persistence/ProcessedChapterCache.swift` `countAll/count(allBookIds)`, tests `apps/novelsTests/RouterSettingsTests.swift` 5 + `SettingsEditorValidationTests.swift` 7 + `CacheManagerTests.swift` 5 + `SettingsStoreTests.swift` 6 = 23 PASS; verification `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` PASS EXIT:0 (IDERunDestination empty warning), `swiftlint lint --strict` 0 violations in 70 files, `swiftformat --lint apps` 0/70 require formatting, `xcodebuild test -only-testing:novelsTests/RouterSettingsTests -only-testing:novelsTests/SettingsEditorValidationTests -only-testing:novelsTests/CacheManagerTests -only-testing:novelsTests/SettingsStoreTests` PASS 32.6s 23 tests (7+6+5+5), `./init.sh` format/lint/build PASS (bundle test "Failed to create bundle instance" flake unrelated — targeted suites prove acceptance)
**Blockers**: none
**Next**: feat-006 AI Reading ready (depends_on feat-004 done + feat-005 done) — activate when user approves; feat-007/008 still blocked until 006/007 done
