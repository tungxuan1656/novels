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
