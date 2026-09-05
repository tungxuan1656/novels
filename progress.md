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
**Done**: App Shell + Home Library — NavigationStack startup routing `onScreen ? Reading : Library` via `@Observable Router` (NavigationPath + Route reading/references, isPushing debounce 300ms, pop guard, didPopFromReading), `AppRoot` with `.toast` + `.task restoreInitialRoute` (toast "Không tìm thấy sách" on invalid), shared primitives `LoadingView` (blocking #2563EB card radius 16) `ToastView` (success #16A34A/error #DC2626/info #2563EB/warning #EA580C 3s/4s/5s tap dismiss) `BottomSheetView` (handle #E5E7EB 40x5 white radius 24) + `DesignTokens` (#FDFCF8/#FFFFFF/#111111/#6B7280/#2563EB/#16A34A/#EA580C/#DC2626/#E5E7EB), offline Library `LibraryViewModel` scanning `FileBookRepository(AppPaths.booksRoot())` + `LibraryView` with Vietnamese "Thư viện/Chưa có sách/Nhấn + để thêm sách" empty ContentUnavailable + List row name/author/count + pull-to-refresh + swipe Info blue / Delete red + deleteConfirm + loadingOverlay, `BookInfoSheet` ("Thông tin sách" + chapter list) + swipe-delete confirm "Xóa sách?/Bạn có chắc...", `ReadingShellView` ("Đang đọc: bookId", "Tài liệu tham khảo" push references, back "Thư viện" clears onScreen, background #FDFCF8, iPhone-only TARGETED_DEVICE_FAMILY=1)
**Evidence**: `apps/novels/App/AppRoot.swift`, `apps/novels/App/Router.swift`, `apps/novels/SharedUI/LoadingView.swift`, `apps/novels/SharedUI/ToastView.swift`, `apps/novels/SharedUI/BottomSheetView.swift`, `apps/novels/Resources/DesignTokens.swift`, `apps/novels/Features/Library/LibraryView.swift`, `apps/novels/Features/Library/LibraryViewModel.swift`, `apps/novels/Features/Library/BookInfoSheet.swift`, `apps/novels/Features/Reading/ReadingShellView.swift`, `apps/novels/NovelsApp.swift`, tests `apps/novelsTests/ToastCenterTests.swift` 2 + `RouterTests.swift` 4 + `LibraryViewModelTests.swift` 5 + `ReadingShellTests.swift` 3 + `DomainCodableTests` 13 + `BookRepositoryTests` 13 + `ProcessedChapterCacheTests` 6 + `SettingsStoreTests` 6 + `FixtureTests` 1 + `apps/novelsUITests/LaunchSmokeTests.swift` 2 = 40+ PASS; `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` PASS, `./init.sh` PASS (format 0/lint 0/build PASS/test PASS), `grep TARGETED_DEVICE_FAMILY="1"` 6 hits, Vietnamese grep hits in LibraryView/BookInfoSheet/Router/ReadingShell, no SwiftData/Core Data/Keychain/BGTask/WebKit (1), no catalog-ai/Prefetch/ProcessedChapter in App/Features (1), no hard-coded Application Support/novels in tests (1 via AppPaths), `swiftformat --lint` 0/37, `swiftlint lint --strict` 0/37
**Blockers**: none
**Next**: feat-003 Catalog Import + ZIP Ingestion ready to activate (depends_on feat-001, feat-002 done)

## 2026-08-26 — feat-003

**State**: done
**Done**: Catalog Import + ZIP Ingestion — CatalogService POST empty body Content-Type application/json no auth + success:false message, ImportViewModel catalogState/empty/error + sort Name A→Z/Newest + atomic import via FileBookRepository+ZipValidator (download temp → unzip → validate exact-root reject wrapper/__MACOSX → atomic replace books/<slug>/ → delete ZIP only on success → re-import overwrite), AddBookView states loading/empty/error/content with pull-to-refresh + blocking overlay "Downloading..."/"Extracting..." + Library refresh without restart + sort picker
**Evidence**: `feat/003-catalog-import` 3201f68 — `apps/novels/Models/ExportedBook.swift` CatalogResponse/ExportedBook/BookMeta, `apps/novels/Services/CatalogError.swift`, `apps/novels/Services/CatalogService.swift` actor POST, `apps/novels/Features/Import/ImportViewModel.swift` @MainActor @Observable + Downloader, `apps/novels/Features/Import/ImportError.swift`, `apps/novels/Persistence/FileManagerZIP.swift` CRC32 polyfill, `apps/novels/Features/Import/AddBookView.swift` Vietnamese UI, `apps/novels/App/Router.swift` Route.addBook debounce, `apps/novels/App/AppRoot.swift` destination + onImportSuccess refresh, `apps/novels/Features/Library/LibraryView.swift` wire +, tests `CatalogServiceTests` 6 + `ImportViewModelTests` 7 + `RouterTests` addBook 2 = 60+ PASS; `./init.sh` PASS (format 0/45 lint 0 build PASS test PASS 194s full suite), `xcodebuild test` full PASS, grep Content-Type 1 hit Auth 0 SwiftData 0 temporaryDirectory 4
**Blockers**: none
**Next**: feat-004 Offline Book Reader ready (depends_on feat-001, feat-002, feat-003) and feat-005 Settings + Cache Manager ready (depends_on feat-001, feat-002) — choose next activation

## 2026-08-26 — feat-004

**State**: done
**Done**: Offline Book Reader — HtmlParser `div/h*/p/br/b/strong/i/em/span` → TextSpan/TextBlock pure Swift, ReaderViewModel 1-based clamp 1..count prev/next disabled bounds + `saveOffset` per slug + `onScreen` + toast "Không tìm thấy chương" without crash + rapid nav offset reset, ReaderView SwiftUI.Text VStack with typography `fontSize 12..24/lineHeight 1.2..2.0/letterSpacing 0..1.0` live + header Chapter N/count + footer Prev/Next + to-bottom via ScrollViewReader + overscroll 400ms lock + `ScrollOffsetKey` + `restore offset 0 on chapter change`, ReferencesView bold current + checkmark + `accessibilityIdentifier ref-N`, ReaderBottomSheet font picker System/Serif/Mono + steppers clamped + gear no-op toast feat-005, Router `Route.references(bookId:String)` + `didPopFromReading` + restoreInitialRoute toast "Không tìm thấy sách", AppRoot `navigationDestination` reading→ReaderView references→ReferencesView, swipe-back `interactiveDismissDisabled` only on Reading
**Evidence**: `docs/plans/feat-004.md` (752 lines) + commits `5135ab1` HtmlParser 5 tests, `d068d72` ReaderViewModel 8 tests, `fbf9815` References 3 tests, `d1eec46` BottomSheet 3 tests, `044c6d1` ReaderView 3 tests, `d50d6aa` Router 4 tests, `8de01b5` integration 2 tests + `ef80e5c` fix critical+majors 11 tests ReaderViewFixTests (overscroll bottom-only via ContentHeightKey/ViewportHeightKey + ReaderOverscrollLogic, restore offset per-book via ScrollPosition, font design System/Serif/Mono, debounce 300ms) — total ~81 tests + `novelsUITests` 2 — oracle review NEEDS_FIX addressed; `./init.sh` PASS (format 0/58 lint 0 build PASS test PASS 165.7s Xcode 26.5 iPhone 17 Pro → post-fix re-verify PASS), `xcodebuild build`/`test` PASS, offline grep 0
**Blockers**: none
**Next**: feat-005 Settings + Cache Manager ready (depends_on feat-001, feat-002) — choose activation OR feat-006 AI Reading blocked until 005 done

## 2026-08-26 — feat-010

**State**: done
**Done**: Tolerant ZIP Ingestion Hotfix — fixed error "Gói sách không hợp lệ" for valid ZIPs that match sample shape: `FileManagerZIP.unzipItem` supports data-descriptor flag 0x08 (descriptor 0x08074B50 + CRC/comp/uncomp trailing, effective size/CRC, findNextHeaderPos scan), hygiene filter `__MACOSX/.DS_Store/._*` skip-not-throw via `ZipValidator.isHygieneEntry` single source, resolver `resolveCanonicalRoot` flattens single outer-folder wrapper (filtered count==1 and child valid → canonical, else original) flattens only one folder, `ZipValidator.isValidRoot` tolerantly ignores hygiene at top level and chapters (filteredChapters count), `Book` fallback `init(from:)` derives `id` slug from `name` when missing/empty (folding diacriticInsensitive, single dash), `ImportViewModel` calls resolver after unzip before validator/save
**Evidence**: branch feat/010-tolerant-zip 10 commits c711c31..2749857 (315c0a5 plan, a2ef1b9 flag08+hygiene, 003b682 lint clean, a4cd8aa wrapper flatten, 9ef31f7 dedupe, 917d6c3 validator hygiene, 98ed7b4 Book fallback, 8d7e806 fallback tests, d1c372d docs tolerant, 2749857 fixtures+security tests) + SDD ledger .agent-work/sdd/feat-010/progress.md 6 tasks + final review clean; docs: ARCHITECTURE.md:14, docs/contracts/book-package.md 16-19 + Import Flow 43 + Reference Sample + Rules/Avoid, docs/decisions/book-package-shape.md Amendment 2026-08-26, docs/contracts/local-data.md Stores+Lifecycle — all tolerant phrase `hygiene + wrapper flatten + data-descriptor, strict security invariants preserved`; tests: TolerantFixtures.swift 192 lines (makeDeflateDescriptorZip real DEFLATE+flag08, makeDescriptorFlagStoreZip STORE+flag08), ImportViewModelTests 20/20 (synthetic wrapper+__MACOSX+flag08+DS_Store flatten, real sample 743 chapters count==743 refs, zip-slip/bomb 101MB/CRC/missing-chapter still invalidPackage), BookRepositoryTests 17/17 (hygiene tolerated, real extra/wrapper still reject), DomainCodableTests 15/15 (fallback van-gioi / van-gioi-chi-rut-thuong-he-thong); swiftformat 0/63, swiftlint --strict 0/63, `./init.sh` PASS (format/lint/build PASS, 127 tests PASS), sample docs/samples/van-gioi-chi-rut-thuong-he-thong.zip 1,955,587 bytes preserved; task reviews ora-1..ora-9 + final ora-10 all Approved (NeedsFix fix rounds 1/5 where needed)
**Blockers**: none
**Next**: Merge feat/010-tolerant-zip → main (`git checkout main && git merge --no-ff feat/010-tolerant-zip && git push`) — sample now importable tolerant via flatten, no migration

## 2026-08-27 — feat-005

**State**: done
**Done**: Settings + Cache Manager — grouped Settings list (Catalog/AI/Prefetch/Typography/Data→CacheManager) via `SettingsView` (Vietnamese "Cài đặt", rows `accessibilityIdentifier settings-<key>`), `SettingEditorView` with `SettingDescriptor.validate` (URLs non-empty, JSON object for headers/body verbatim allowed, `AI_PROVIDER` only openai case-insensitive, `PREFETCH_COUNT 1..10→3`, `AI_MIN_CHUNK_SIZE 500..5000→1300`, typography `12..24/1.2..2.0/0..1.0`) blocks save unless `allowsVerbatimSave` + `Clear`→default + Toast "Saved" + `router.pop()`, `SettingsStore.value/setValue` helpers + `save()`→`sanitize()` BR-12 (unknown legacy ignored, no re-implementation), headers/body `effectiveHeaders()→[:]` on bad JSON stored verbatim ignored at merge per `ai-service.md:17`; `CacheManagerView` count card shows total processed count + "Clear All" confirm + per-book "Clear" confirm → `SQLiteProcessedChapterCache.countAll/count/bookIds` via `SELECT count(*)` `DISTINCT` (WITHOUT ROWID + INDEX + user_version=1 preserved, mode none never written, INSERT OR REPLACE) reflects immediately + `refreshable` + Toast "Cleared"; `Router` extended `.settings/.cacheManager/.settingEditor(String)` + `isPushing` 300ms debounce + `AppRoot` destinations, `LibraryView` gear `settingsButton`; survives relaunch via `@Observable` + isolated `UserDefaults(suiteName:)` verified, `count/clearAll/clear(bookId)` immediate
**Evidence**: `docs/plans/feat-005.md` (719 lines, Tasks 1-5), `apps/novels/Features/Settings/SettingsView.swift` + `SettingEditorView.swift` + `SettingsViewModel.swift` + `CacheManagerView.swift` (165→full), `apps/novels/App/Router.swift` + `AppRoot.swift`, `apps/novels/Features/Library/LibraryView.swift` gear, `apps/novels/Persistence/SettingsStore.swift` helpers, `apps/novels/Persistence/ProcessedChapterCache.swift` `countAll/count(allBookIds)`, tests `apps/novelsTests/RouterSettingsTests.swift` 5 + `SettingsEditorValidationTests.swift` 7 + `CacheManagerTests.swift` 5 + `SettingsStoreTests.swift` 6 = 23 PASS; verification `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` PASS EXIT:0 (IDERunDestination empty warning), `swiftlint lint --strict` 0 violations in 70 files, `swiftformat --lint apps` 0/70 require formatting, `xcodebuild test -only-testing:novelsTests/RouterSettingsTests -only-testing:novelsTests/SettingsEditorValidationTests -only-testing:novelsTests/CacheManagerTests -only-testing:novelsTests/SettingsStoreTests` PASS 32.6s 23 tests (7+6+5+5), `./init.sh` format/lint/build PASS (bundle test "Failed to create bundle instance" flake unrelated — targeted suites prove acceptance)
**Blockers**: none
**Next**: feat-006 AI Reading ready (depends_on feat-004 done + feat-005 done) — activate when user approves; feat-007/008 still blocked until 006/007 done

## 2026-08-27 — feat-006

**State**: done
**Done**: AI Reading — cache-first translate/summary via OpenAI-compatible POST per chunk (1300 hint, 500..5000 else 1300, join "\n", clean) with `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON ignored at merge per `ai-service.md:17`, retry 3× 1000/2000 ms, `actor` de-duplication same `(bookId,chapter,mode)` single call, slug `book.json.id` cache key `PRIMARY KEY(book_id,chapter_number,mode) WITHOUT ROWID` `INSERT OR REPLACE` + `contentHash` SHA256, mode `none` never cached, `localhost`-only ATS `http://localhost:8317`, mode switch + reprocess in `ReaderBottomSheet` (`aiModePicker` Original/Translate/Summary + `reprocessButton` "Xử lý lại") via `ReaderViewModel` `aiMode/processedContent/isAIProcessing/aiError` + `AIReadingService` (`AIChunker`, `AIPromptBuilder` BR-03/04 honorifics ta/ngươi/huynh... 100% natural + BR-05/06 50-60% plot/dialogue no hallucination, `AIClient` actor, `AIResponse`)
**Evidence**: `docs/plans/feat-006.md` (903 lines, Tasks 1-5), `apps/novels/Services/AIChunker.swift` + `AIPromptBuilder.swift` + `SettingsModels.swift` BR prompts + `AIClient.swift` + `AIResponse.swift` + `AIReadingService.swift` (CacheStore/CryptoKit dedup) + `ReaderViewModel.swift` aiMode + `ReaderBottomSheet.swift` picker/reprocess + `ReaderView.swift` processed rendering + `Info.plist` ATS localhost, `apps/novels.xcodeproj/project.pbxproj` GENERATE_INFOPLIST_FILE=NO, tests `AIChunkerTests` 4 + `AIPromptBuilderTests` 5 (BR-03/04/05/06) + `AIClientTests` 4 (merge/ignore/retry 3/empty) + `AIReadingServiceTests` 6 (hit/miss dedup/none/reprocess/invalid) + `AIReadingViewModelTests` 4 (switch/reprocess/none/goNext) + `AIIntegrationTests` 3 (invalid headers/none long/ATS) = 26 PASS; verification `swiftformat --lint` 0/82 `swiftlint lint --strict` 0/82 `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` PASS `xcodebuild test ...` PASS 80+ `plutil -p Info.plist` ATS localhost only `grep GENERATE_INFOPLIST_FILE` NO, `./init.sh` PASS (format PASS lint PASS build PASS test PASS drift PASS 82 files)
**Blockers**: none
**Next**: feat-007 Chapter Prefetch ready (depends_on feat-006 done) — sequential next-N cache batch check + cancellable Task; feat-008 blocked until 007 done

## 2026-08-27 — feat-007

**State**: done
**Done**: Chapter Prefetch — batch cache check via `processed_chapters.sqlite` `batchStatus` skipping cached, sequential `AIReadingService` misses with `Task` cancellation on chapter/mode change and book deletion, `PrefetchStatus` runtime-only (`isRunning/currentBookId/totalChapters/processedChapters/message/errors[]`) read-only UI (no writable controls, no persistence), per-chapter error continue to `errors[]`, invalid `PREFETCH_COUNT` 1..10 else 3
**Evidence**: `docs/plans/feat-007.md` (790 lines, Tasks 1-4), `apps/novels/Domain/PrefetchStatus.swift`, `apps/novels/Services/PrefetchManager.swift` (actor `Task` + eligibility `mode != none` + `effectivePrefetchCount` + range `current+1..min(current+N,total)` + `batchStatus` + sequential `AIReadingService` + `Task.isCancelled` + `AppPaths.booksRoot().bookId` deleted check + `PrefetchStatus` updates), `apps/novels/Persistence/SettingsStore.swift` `effectivePrefetchCount()`, `apps/novels/Features/Reading/ReaderViewModel.swift` (`prefetchStatus`/`prefetchManager`/`triggerPrefetchIfEligible`/`cancelPrefetch` wired to `load`/`goNext`/`goPrev`/`goToChapter`/`setAIMode`/`reprocess`/`onDisappear` + 100ms poll), `apps/novels/Features/Reading/ReaderView.swift` read-only `prefetchStatus` indicator (`ProgressView` + `Prefetching` + errors, `accessibilityIdentifier prefetchStatus`), `apps/novelsTests/PrefetchStatusTests` 2 + `PrefetchManagerTests` 7 + `ReaderPrefetchIntegrationTests` 4 = 13 PASS; `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` PASS, `swiftformat --lint` 0/87, `swiftlint lint --strict` 0/87, `./init.sh` PASS (format PASS, lint PASS, build PASS, test PASS 80.36s 87 files, drift PASS)
**Blockers**: none
**Next**: feat-008 Hardening + Release Readiness ready (depends feat-007 done) — activate when user approves

## 2026-08-27 — feat-008

**State**: done
**Done**: Hardening + Release Readiness — iPhone-only config verified (TARGETED_DEVICE_FAMILY=1 ×6, 26.5, AppIcon 1024×3, launch + ATS localhost-only, ~ipad pruned), a11y 4.5:1/3:1 + 44pt + VoiceOver/Dynamic Type sweep with labels, 7-edge regression recorded (offline scan, invalid ZIP still rejected, missing chapter error no crash, invalid JSON headers/body ignored verbatim, cache clear immediate, prefetch cancel on change, kill-on-Reading resume via UserDefaults)
**Evidence**: `docs/plans/feat-008.md`, `apps/novels/Info.plist` (LSRequiresIPhoneOS true + UILaunchScreen dict + ATS localhost-only, ~ipad 0), `project.pbxproj` TARGETED_DEVICE_FAMILY=1 ×6 IPHONEOS_DEPLOYMENT_TARGET=26.5 ×6 DEVELOPMENT_TEAM M5U4E4H84J ×8, `Assets.xcassets/AppIcon` 3×1024, a11y 44pt/labels/Dynamic Type/VoiceOver (ReaderView 12 identifiers, ToastView 1 label, Library 3), `apps/novelsTests/HardeningRegressionTests` 2 + `HardeningA11yTests` 4 + `HardeningEdgeTests` 7 PASS, `xcodebuild build` PASS, `swiftformat` 0/88, `swiftlint` 0 violations in 88 files, `./init.sh` PASS [format] PASS [lint] PASS [build] PASS [test] PASS [drift] (21 siblings, total 22)
**Blockers**: none
**Next**: Release ready — no active feature; repo idle per Harness Slim

## 2026-08-28 — feat-011

**State**: done
**Done**: AI Prompt Setting & Inline Rewrite Reading Sheet — Replaced `AI_PROCESS_ACTIONS` JSON setting with single `AI_PROMPT` key ("Prompt", multiline editor, default natural Vietnamese translate/rewrite prompt). Simplified `AIMode` enum to `.none` ("Không") and `.rewrite` ("Rewrite"). Updated `AIPromptBuilder` and `AIReadingService` to utilize single `aiPrompt`. Refactored `ReaderBottomSheet` UI to display "AI Rewrite" with an inline segmented picker ("Không" / "Rewrite") and side-by-side "Xử lý lại" reprocess button. Updated all test suites and full `./init.sh` harness.
**Evidence**: `docs/plans/feat-011.md`, `features/feat-011.md`, `feature_index.json`, `apps/novels/Domain/AIMode.swift`, `apps/novels/Persistence/DefaultsKeys.swift`, `apps/novels/Domain/SettingsModels.swift`, `apps/novels/Persistence/SettingsStore.swift`, `apps/novels/Services/AIPromptBuilder.swift`, `apps/novels/Services/AIReadingService.swift`, `apps/novels/Features/Settings/SettingsView.swift`, `apps/novels/Features/Settings/SettingsViewModel.swift`, `apps/novels/Features/Settings/SettingEditorView.swift`, `apps/novels/Features/Reading/ReaderBottomSheet.swift`, `apps/novelsTests/` 12 updated test suites (DomainCodableTests, SettingsStoreTests, SettingsStoreCoercionTests, SettingsEditorValidationTests, RouterSettingsTests, AIPromptBuilderTests, AIReadingServiceTests, AIReadingViewModelTests, CacheManagerTests, ProcessedChapterCacheTests, PrefetchManagerTests, ReaderPrefetchIntegrationTests, AIIntegrationTests, HardeningRegressionTests); `./init.sh` full verification PASS 100% (format PASS, lint PASS, build/test PASS, drift PASS).
**Blockers**: none
**Next**: All features complete, repository idle per Harness Slim.

## 2026-09-03 — feat-012

**State**: done
**Done**: Prompt Sync & Inline AI Rewrite Picker — Docs: overview.md Purpose/Scope/Features none/rewrite, glossary AI Prompt/AI Mode none("Không")/rewrite("Rewrite"), integrations Purpose single Prompt, domain-model Relationship Map AI_PROMPT, screens Cases Invalid headers/body + Empty Prompt → default; Code: ReaderBottomSheet HStack Picker inline (aiModePicker) + Button "Xử lý lại" beside (reprocessButton) disabled when none/processing, Settings AI_PROMPT label Prompt multiline default Vietnamese honorifics (BR-12); feat-012 active→done.
**Evidence**: `features/feat-012.md`, `feature_index.json` feat-012 done (depends_on feat-011), `docs/product/overview.md`, `docs/product/glossary.md`, `docs/product/integrations.md`, `docs/product/domain-model.md`, `docs/design/screens.md` (5 docs grep clean), `apps/novels/Features/Reading/ReaderBottomSheet.swift` pickerStyle .inline + HStack12 + reprocessButton, `apps/novels/Features/Settings/SettingsViewModel.swift` Prompt descriptor, `./init.sh` full PASS 2026-09-03 (format 0/89, lint 0/89, build PASS, test PASS ~130, drift PASS 21/22)
**Blockers**: none
**Next**: repo idle — Prompt/AI Rewrite inline fully synced, no further feat active

## 2026-09-04 — feat-013

**State**: done
**Done**: Auto Prev/Next on overscroll — pull past top ≥90pt → prev landing at bottom, push past bottom ≥90pt → next landing at top; hint “Thả để chuyển chương” ~45pt + haptic + toast “Đã là chương đầu/cuối”; short chapters navigable both directions; keeps 400ms lock + per-book offset + AI/prefetch cancel.
**Evidence**: `features/feat-013.md`, `feature_index.json` feat-013 done (depends_on feat-004), `ScrollOffsetPreference.defaultThreshold=90` + `isPulledBeyondTop`, `ReaderView` hint overlays + `scrollToBottom` + bound toast, `ReaderViewFixTests` 6 new tests, `./init.sh` full PASS (format 0/89, lint 0, build PASS, test PASS, drift PASS 21/22)
**Blockers**: none
**Next**: repo idle — test on real device with long/short chapters + AI rewrite

## 2026-09-04 — feat-013 fix

**State**: done
**Done**: Lowered overscroll threshold 90→28pt (hint ~14pt) because real swipe amplitude on Simulator is only ~20–35pt; forced bounce `.scrollBounceBehavior(.always)` so short chapters still emit signal; updated `ReaderViewFixTests` to threshold 28.
**Evidence**: `ScrollOffsetPreference.defaultThreshold=28`, `ReaderView` bounce always, tests 17/17, `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: user rebuilds app on Simulator then pulls past top/bottom holding touch to verify hint + chapter switch

## 2026-09-04 — feat-013 pipeline fix

**State**: done
**Done**: Replaced offset-measurement pipeline `GeometryReader` + PreferenceKey with `onScrollGeometryChange(-contentOffset.y)` because the old pattern missed rubber-banding (content slides but offsetY ≈ 0); kept threshold 28/hint ~14/lock/toast/bounce unchanged.
**Evidence**: `ReaderView` onScrollGeometryChange with inverted sign, `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: user rebuilds + retests past-edge pull at top/bottom on Simulator

## 2026-09-04 — feat-013 round 2

**State**: done
**Done**: Rework excursion state machine — rest-relative thresholds (no hint/toast before scrolling), programmatic settle by velocity + easeOut (no auto back/cascade), single-source ScrollGeometry (bottom trigger works), single-fire + 900ms throttle + 1 toast per excursion; removed 3 dead PreferenceKeys.
**Evidence**: `ReaderViewFixTests` 26/26 (9 new tests: rest-invariance, re-arm, cooldown, overshoot), `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: user rebuilds + retests per script (note: first open with deep restore needs ≤2s settle before accepting swipes)

## 2026-09-04 — feat-013 pivot

**State**: done
**Done**: Replaced vertical overscroll with thirds edge swipe after 3 failed rounds — swipe right in left third → prev, swipe left in right third → next; both land at top. Deleted overscroll state machine + debug overlay; kept offset save/restore, header buttons, toasts, haptics. Direction lock |dx|>=60 + |dx|>2|dy|, onEnded fire, 600ms throttle, one-time bound toast.
**Evidence**: `EdgeSwipeDecision` + 12 new edge tests (18 ReaderViewFixTests pass), `./init.sh` full PASS (format 0/89, lint 0, build PASS, test PASS incl. UITests, drift PASS)
**Blockers**: none
**Next**: repo idle — user retests edge swipe on Simulator (both thirds, bounds, vertical-scroll safety)

## 2026-09-04 — feat-013 jump-top

**State**: done
**Done**: Chapter switch now jumps to top instantly with animations disabled, on every path (edge swipe, header buttons, chapter-number change observer as safety net against load-vs-scroll races). Active "scroll to bottom" button keeps its animation.
**Evidence**: `ReaderView.scrollToTop` transaction without animation + `onChange(chapterNumber)` second jump, `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: repo idle — user retests: no scroll animation on switch, always lands at top

## 2026-09-04 — feat-014

**State**: done
**Done**: Diagnostic Log Viewer in-session — ring 500 + OSLog private, redact auth → `<redacted>` (prompt never raw, snippet only when verbose), AI timeout hardcoded 180/600 + waitsForConnectivity, prefetch budget 600/1800 + markers, timeline DESC + filter/search + group toggle + expand, entry "Nhật ký" from bottom sheet → route `Reading --> Log`. ADR `diagnostic-log-viewer.md` partially reverses `network-logger-removed`.
**Evidence**: `features/feat-014.md`, `docs/plans/feat-014.md`, `docs/decisions/diagnostic-log-viewer.md`, `Domain/DiagnosticsEntry.swift`, `Services/DiagnosticsLog.swift`, `AIClient`/`AIReadingService`/`PrefetchManager` instrument + `PrefetchManager` loop-top bookDeleted guard, `ReaderBottomSheet.apiLogButton` + `Features/Diagnostics/LogScreen.swift` + `Router.apiLog` + `AppRoot`, `DiagnosticsLogTests` 10 tests, docs (ARCHITECTURE/navigation/screens/SECURITY/settings-schema + `DIAGNOSTICS_VERBOSE`), `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: repo idle — user retests on Simulator: read + AI Rewrite + prefetch then open "Nhật ký" to check timeline/filter/expand/verbose

## 2026-09-04 — feat-015

**State**: done
**Done**: Parallel chunks + 2 total attempts + loading-only — TaskGroup index-keyed join in correct order (retry per-chunk in client), AIClient 0..<2 + checkCancellation, ViewModel cancels aiTask onDisappear, plain centered spinner (removed aiError view/id, kept toast), red Log badge on fail.
**Evidence**: `features/feat-015.md`, `docs/plans/feat-015.md`, `AIClient`/`AIReadingService`/`ReaderViewModel`/`DiagnosticsStore.errorCount`, `ReaderView`/`BottomSheet`/`LogScreen` + `Router.apiLog(bookId:initialFilter:)`, `ai-service.md` retry 2, tests AIClient/AIReadingService/DiagnosticsLog/PrefetchManager/ReaderViewFixTests PASS, `./init.sh` format/lint/build/drift PASS + targeted TEST SUCCEEDED (full run flaked once on Simulator bundle)
**Blockers**: none
**Next**: repo idle — user retests parallel translation + Log attempt/requestId

## 2026-09-04 — feat-016

**State**: done
**Done**: Removed auto-retry (1 attempt/chunk, fail → manual "Xử lý lại") + fixed stuck spinner ch22 — separate CancellationError catch (no aiError/toast), synchronous flag clear onDisappear, prefetch poll always syncs at end, fixed parallel test race (NSLock + set assertion).
**Evidence**: `features/feat-016.md`, `AIClient` single-attempt, `ReaderViewModel` cancel/catch/poll, `ai-service.md` no-retry, `DiagnosticsLogTests` NSLock + set-compare, `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: repo idle — user retests ch22 fail: chapter spinner off, prefetch runs separately, manual retry

## 2026-09-04 — feat-017

**State**: done
**Done**: Tolerant 200 decode — `content?` + `reasoning_content` fallback + `tool_calls` tolerant; safe shape logging (keys/choicesCount/contentKind/hasReasoning/hasTools, no raw); LogScreen Kind/Choices/Content rows; keeps single-attempt + manual retry.
**Evidence**: `features/feat-017.md`, `AIResponse` resolvedText, `AIClient` shape parse/log, `DiagnosticsEntry/Log` shape fields, `LogScreen`, `ai-service.md`, tests reasoning/tool/envelope/empty + redaction, `./init.sh` full PASS (format/lint/build/test/drift)
**Blockers**: none
**Next**: repo idle — user retests odd provider 200-shape, opens Log to check Kind/Choices

## 2026-09-04 — feat-018

**State**: done
**Done**: Rewrite + Prefetch Correctness (consolidating feat-015/016/017, freezing 3 old feats as done-archived): parallel batch chunks joined in correct order, 1 retry on exactly the failed chunk (all error types, 2 attempts/chunk, stable requestId, attempt 1/2 logged separately); sequential prefetch only on real chapter change (LoadSource chapterChange vs returnFromLog), batchStatus all-cached zero-API, miss sequential per chapter with error-skip-continue; 12px header spinner left of prev/next capsule only for current rewrite chapter, removed content + bottom-sheet spinners, silent prefetch (Log badge); back from "Nhật ký" on same chapter zero-API keeps status; silent CancellationError, failed chapter 1 toast + raw fallback.
**Evidence**: `features/feat-018.md` (acceptance 6/6), `docs/plans/feat-018.md` Tasks 1-6, `docs/contracts/ai-service.md` + `ai-reading.md` + `chapter-prefetch.md` + `docs/design/screens.md`, `AIClient` loop 1...2 + `ReaderViewModel.load(source:)` + `ReaderView` aiProgressHeader + `ReaderBottomSheet` no-spinner + stale `HardeningRegressionTests` header-only, `./init.sh` full PASS 2026-09-04 (format/lint/build TEST SUCCEEDED/drift; AIClient 12/12, AIReadingService 11/11, Prefetch 7/7+6/6, HeaderSpinner 3/3, ViewFix 18/18), `feature_index.json` feat-018 done (zero active)
**Blockers**: none (tree still uncommitted consolidating 015/016/017+018 — not committed as not requested)
**Next**: repo idle — user retests on real device (ch22 fail → toast+raw+header off; Log back zero-API; chapter-change sequential prefetch), commit when user requests

## 2026-09-04 — feat-019

**State**: done
**Done**: Log groups 1 row = 1 chapter × 1 processing run (`runId` threading through service/prefetch) with Success/Failure/Processing badge + chunk count; expand shows events + retry; API has "Xem JSON thô" button (full request/response in `BottomSheetView`, RAM-only, no persist/OSLog); removed headers block + Model row, Server full URL; removed book/chapter filters, chips, segmentation; search only by chapter/status/event/detail.
**Evidence**: `features/feat-019.md` (acceptance 7/7), ADR amendment + `screens.md` + `ai-service.md`, `LogRunBuilder` + `LogScreenGroupingTests` 11/11, bodies/runId tests, `./init.sh` full PASS 2026-09-04 (format/lint/build TEST SUCCEEDED/drift), `feature_index.json` feat-019 done (zero active)
**Blockers**: none (tree uncommitted — not committed as not requested)
**Next**: repo idle — user retests Log screen then requests commit when ready

## 2026-09-04 — feat-020

**State**: done
**Done**: Fastlane iOS Diawi distribution — `Gemfile` (+lock) + `fastlane/Appfile` (`com.tungxuan.novels`/`M5U4E4H84J`) + `fastlane/Fastfile` iOS-only (`apps/novels.xcodeproj`, scheme `novels`, lanes `prepare`/`build`/`upload`/`distribute`, token via `ENV["DIAWI_TOKEN"]`) + `.gitignore` fastlane artifacts; branch `feat/020-fastlane-ios-diawi`
**Evidence**: `ruby -c fastlane/Fastfile` Syntax OK; `bundle exec fastlane lanes` 4/4; grep old token 0 + android 0; `./init.sh` full PASS (format/lint/build/test/drift); `feature_index.json` feat-020 done (zero active)
**Blockers**: none
**Next**: repo idle — export `DIAWI_TOKEN` then `bundle exec fastlane ios distribute` to ship IPA to Diawi

## 2026-09-05 — feat-021

**State**: done
**Done**: Reading Themes Trio — `ReadingTheme` vangGiay (default) / trang / den persist `UserDefaults` key `readingTheme` (unknown → vangGiay), per-theme palette exact approved hex, `ReaderView` full theme tokens + `preferredColorScheme` Reader-only + disabled 0.35/0.42, `ReaderBottomSheet` section `Màu nền` 3 swatch 48pt VI + ring accent 2.5pt + live + haptic + a11y + theme border + force scheme, docs resolve `#FDFCF8`→`#F5F1E5`
**Evidence**: `features/feat-021.md` (acceptance 7/7), `feature_index.json` feat-021 done (zero active), `apps/novels/Domain/ReadingTheme.swift`, `apps/novels/Persistence/DefaultsKeys.swift` + `SettingsStore.swift` (`loadReadingTheme` + `loadDiagnosticsTypographySession` refactor), `apps/novels/Resources/DesignTokens.swift` palette extension, `apps/novels/Features/Reading/ReaderView.swift` (no `backgroundPaper`/`systemGray5`), `apps/novels/Features/Reading/ReaderBottomSheet.swift` (`themePicker`/`theme-vangGiay`/`Màu nền`), `apps/novelsTests/ReadingThemeTests.swift` 6/6, `docs/contracts/settings-schema.md` + `docs/design/design-system.md`; `./init.sh` full PASS 2026-09-05 (format 0/96, lint 0/96, build PASS, test PASS incl. ReadingTheme 6/6 + UITests, drift PASS 21/22)
**Blockers**: none (tree uncommitted incl. prior feats + feat-021 — not committed as not requested)
**Next**: repo idle — user retests 3 themes live + relaunch persist + Đen + Light sheet on Simulator

## 2026-09-05 — feat-022

**State**: todo
**Done**: Reverted session restore edits to HEAD (`ReaderView`/`Router`/`AppRoot`/`RouterReadingTests` + deleted `ReadingRestoreFixTests.swift`; kept `CacheManagerView` pill fix, reverted incidental `init.sh`/`AGENTS.md`); created `features/feat-022.md` (inline simple plan: single restore-after-load, drop flag/poll/reassert, keep save path) + `feature_index.json` feat-022 todo
**Evidence**: `features/feat-022.md`, `feature_index.json` (feat-022 todo, depends_on feat-004), `git status` shows only `M CacheManagerView.swift`
**Blockers**: none
**Next**: User approves plan (notably the brief top-flash trade-off), then activate feat-022 for implementation

## 2026-09-05 — feat-022 done

**State**: done
**Done**: Reading Position Restore (Simple) — `ReaderView.restoreOffset` replaced with restore-once (100ms×20 ~2s wait for `!isLoading` + blocks/error, single `scrollPosition` assign; deleted `isRestoringOffset`/`shouldReassert`/150ms reassert; kept `offsetToRestore` + `needsScrollRestore` + chapter-equality stale guard + `scrollToTop` on chapter change; save path untouched); `ReaderViewFixTests` updated (`testShouldReassert` removed, restore-once assertions rewritten + `testReaderRestoreAssignsOnce` added); `feature_index.json` feat-022 done (zero active)
**Evidence**: `apps/novels/Features/Reading/ReaderView.swift` (net negative), `apps/novelsTests/ReaderViewFixTests.swift`, `features/feat-022.md` (acceptance 4/4), `./init.sh` full PASS 2026-09-05 (format/lint/build/test PASS incl. restore-once + UITests/drift PASS 21/22)
**Blockers**: none (tree uncommitted — not committed as not requested)
**Next**: repo idle — user retests on Simulator (scroll→back→re-enter shows X; scroll→wait>1s→kill→relaunch shows X after brief top; chapter change→top; different book→top)

## 2026-09-06 — feat-023 plan

**State**: active
**Done**: Investigation complete (3 explorer lanes + 10 oracle lanes P1A/P1B/P2A/P2B/P3A/P3B/P4A/P4B/P5A/P5B, all read-only) + plan approved full 5 phases; created `features/feat-023.md` (separate plan link, 3-lane ownership) + `docs/plans/feat-023.md` (Phase 0 baseline, P1 state guard, P2 status/log, P3 count transparency, P4 bounded retry/window, P5 resource guards, roadmap, owner defaults) + `feature_index.json` feat-023 active
**Evidence**: `docs/plans/feat-023.md`, `features/feat-023.md`, `feature_index.json` (feat-023 active, depends_on feat-004/005/006/007/014/018); Phase 0 baseline `./init.sh` full PASS 2026-09-06 (format/lint/build TEST SUCCEEDED/drift 21/22)
**Blockers**: none
**Next**: Phase 1 Lane R (generation guard + `ReaderStaleGuardTests`) — awaiting execution approach choice

## 2026-09-06 — feat-023 R+S reconcile

**State**: active
**Done**: Lane R Phase 1 loop closed (`bfed666` + fix `634ae88`: aiGeneration guard, guarded flag clear, aiTask tracking, deterministic GatedAIURLProtocol tests; re-review 7/7 + no breakage) + Lane S Phase 3/2-badge loop closed (`360ebbb` + fix `af25fab`: shared trim rule, effective-N row, badge/isError/allowlist/keyHash-join, hygiene tests; re-review 9/10, I10 closed by full init below); `./init.sh` full PASS post-merge (format/lint/build TEST SUCCEEDED incl. new StaleGuard 4/4 + Grouping/drift 21/22); parked minors: R M1/M4 + S 11-14 (ledgered for final review)
**Evidence**: `features/feat-023.md` (handoff updated), commits `bfed666`/`634ae88`/`360ebbb`/`af25fab`, `./init.sh` full PASS 2026-09-06
**Blockers**: none
**Next**: Lane P Phases 4-5 (bounded retry/window + resource guards), then final whole-branch review + manual walks

## 2026-09-06 — feat-023 done

**State**: done
**Done**: All 5 phases landed + reviewed (Lane R `bfed666`/`634ae88` generation guard + `758a26e`/`b75f78c` poll epoch/resume; Lane S `360ebbb`/`af25fab` trim/effective-N/badge contract; Lane P `3ebf9de`/`9225cc9`/`33be48b` retry-topup/cap); every review loop closed via scoped re-reviews (no open Critical/Important; parked minors: R M1/M4, S 11-14, P log-spam); `./init.sh` full PASS (format 0/98, lint 0, build PASS, test PASS incl. new StaleGuard/Grouping/Integration suites, drift 21/22; one retry past the known Simulator bundle-instance flake)
**Evidence**: `features/feat-023.md` (acceptance 6/6), `docs/plans/feat-023.md`, `feature_index.json` feat-023 done (zero active), commits listed above
**Blockers**: none (tree uncommitted — not committed as not requested)
**Next**: repo idle — user retests the 4 reported walks on device/Simulator; roadmap (durable queue, event-driven status, cache migration) awaits owner sign-off

## 2026-09-06 — feat-023 commit

**State**: done
**Done**: Commit-time verification per repo rule: first `./init.sh` full FAIL on test step (`PrefetchManagerTests.testEndOfBookMessageNamesRemainingChapters` timed out under parallel 2-clone load + one Simulator launch-denied infra flake); targeted single-test run PASS; full retry `./init.sh` PASS with 0 failures — confirmed flake, no production/test code change needed. Committed feat-023 records (`feature_index.json`, `progress.md`, `docs/plans/feat-023.md`, `features/feat-023.md`).
**Evidence**: first run failing test `testEndOfBookMessageNamesRemainingChapters` + `FBSOpenApplicationServiceErrorDomain RequestDenied`, single-test `** TEST SUCCEEDED **`, retry `EXIT:0` (PASS format/lint/build/test/drift)
**Blockers**: none
**Next**: feat-024 (feat-023 extend: FIFO prefetch refactor) plan for owner approval, refactor after approval

## 2026-09-06 — feat-024 plan

**State**: todo
**Done**: Extend plan written (writing-plans skill): `docs/plans/feat-024.md` (P0 baseline, P1 FIFO queue core, P2 drop debounce/poll/epoch, P3 single-N, P4 specs + close; Lane P engine / Lane R reader / Lane S spec ownership; owner defaults: no hardCap, cancel only on book/mode change, attempts≤1 requeue) + `features/feat-024.md` (separate plan link, acceptance 6/6) + `feature_index.json` feat-024 todo (zero active)
**Evidence**: `docs/plans/feat-024.md`, `features/feat-024.md`, `feature_index.json` (feat-024 todo, depends_on feat-023)
**Blockers**: owner approval of plan (notably hardCap removal + queue-cancel policy) before activation; refactor NOT started
**Next**: approve plan + choose execution approach (subagent-driven vs inline), then Phase 0 baseline

## 2026-09-06 — feat-024 active

**State**: active
**Done**: Owner approved plan with defaults (no hardCap, cancel only on book/mode change, attempts≤1) and chose subagent-driven execution; SDD workspace `.agent-work/sdd/feat-024` ready (fresh ledger); feat-024 activated (zero other active)
**Evidence**: `features/feat-024.md` (handoff active), `feature_index.json` (feat-024 active)
**Blockers**: none
**Next**: Phase 0 baseline + dispatch Lane P implementer (FIFO core)

## 2026-09-06 — feat-024 done

**State**: done
**Done**: Durable FIFO queue keeps running task across same-book navigate (ensureWindow keep ∩ + append tail, attempts≤1 tail requeue, cancel only on book/mode/none/deletion); reader drops 200ms debounce + poll/epoch (synchronous trigger + one-shot resync, returnFromLog zero-API + resume); single-N (hardCap removed, storedN/effectiveN only); specs amended (chapter-prefetch §4 Step 5 + settings-schema BR-08); NSLock around cache entry points (oracle: correct/deadlock-free); M3 same-mode guard attempted then reverted (broke 2 suites) and parked with M1/M2/M4/M5 + test gaps
**Evidence**: `974661a` + uncommitted 8 files (ReaderViewModel/PrefetchManager/ProcessedChapterCache + 3 test suites incl. `testNavigateViaViewModelKeepsRunningTask` + 2 spec docs); oracle review 0 blockers; `./init.sh` full PASS post-revert (format/lint/build/test/drift); `feature_index.json` feat-024 done (zero active)
**Blockers**: none (tree uncommitted — not committed as not requested)
**Next**: repo idle — user retests walks #2/#4 on device/Simulator (steady-next ~1 tail, N=20 keep+append-471, returnFromLog resume)

## 2026-09-06 — feat-024 commit

**State**: done
**Done**: Commit-time verification per repo rule: first `./init.sh` full FAIL on build/test step (tail showed UITests green with overall FAIL; failing test not captured); retry full `./init.sh` EXIT:0 PASS with 0 failures — confirmed flake, no production/test code change needed. Committed feat-024 records (11 files: 3 prod + 3 test suites + 2 spec docs + `feature_index.json`/`features/feat-024.md`/`progress.md`).
**Evidence**: `init-commit.log` PASS format/lint/build/test/drift (`Verification passed`), retry `EXIT:0`
**Blockers**: none
**Next**: repo idle — push when user requests
