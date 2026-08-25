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

## 2026-08-25 — feat-001

**State**: active
**Done**: Activated feat-001 for implementation (user approved subagent-driven, 2026-08-25)
**Evidence**: `feature_index.json` feat-001 active, `docs/plans/feat-001.md` 6 tasks, `ARCHITECTURE.md` scheme novels iOS 26.5
**Blockers**: none
**Next**: Task 1 — create novelsTests/novelsUITests targets + fixtures

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
