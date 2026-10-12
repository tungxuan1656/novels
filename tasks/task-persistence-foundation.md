# Native Persistence Foundation

- Status: done
- Owner: Tung Doan
- Required to start: none recorded.
- Required to integrate/release: none
- Previous ID: feat-001

## Scope and non-goals

Establish the native Swift persistence foundation behind isolated, testable boundaries:
- Pure Swift domain/Codable models (`Book`, `Chapter`, `Reference`, `ProcessedChapter`, `ReadingSession`, `TypographySetting`, settings models) using string-slug `id` and numeric `count`.
- `Application Support` directory layout with `FileManager` + `Codable` local book repository (`books/<slug>/`, 1-based chapters, atomic writes, whole-book deletion). Note: strict archive-root ZIP rejection implemented here was later superseded by tolerant ingestion in [task-tolerant-zip-ingestion](task-tolerant-zip-ingestion.md) (`docs/contracts/book-package.md`).
- Single SQLite `processed_chapters` cache actor (`user_version` schema versioning, composite primary key `(book_id, chapter_number, mode)`, batch status, upsert, cache clearing, never caching `mode == "none"`).
- Settings store via `UserDefaults` with `@Observable`, enforcing BR-12 sanitize rules and ignoring invalid header/body JSON or unknown keys.

Non-goals: No UI screens or navigation, no catalog networking or ZIP download flows, no AI client or prefetch runner, no Core Data/SwiftData/Keychain, and no deployment target or device family changes.

## Acceptance

- [x] `Book`, `Chapter`, `Reference`, `ProcessedChapter`, `ReadingSession`, `TypographySetting`, and settings models are Codable/pure Swift, use slug `id` and numeric `count`, and pass Codable round-trip tests.
- [x] Repository paths resolve under `Application Support/novels/books/<slug>/` and `Application Support/novels/cache/processed_chapters.sqlite`; scan lists only folders with valid `book.json`; `chapters/chapter-N.html` 1-based validated; atomic write replaces file without partial state; `deleteBook(slug)` removes whole folder only.
- [x] Repository rejects ZIPs not matching exact archive-root layout (`book.json` at root, `chapters/chapter-N.html` `1..count`); wrapper sample with outer folder/`__MACOSX` is treated as invalid in fixture test.
- [x] `processed_chapters` SQLite schema matches `docs/contracts/local-data.md` (PRIMARY KEY/UNIQUE, index, no `none`, upsert, versioned via `user_version`); cache hit by `(book_id, chapter_number, mode)` works; batch status for prefetch range works; upsert overwrites; `clearAll()` and `clear(bookId:)` delete correctly; `mode == "none"` is never written.
- [x] Settings `@Observable` store exposes current keys only with defaults `gpt-4o`, prefetch `3`, chunk `1300`, `openai`, catalog/AI URLs; sanitize on load enforces BR-12; invalid `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` JSON is ignored; unknown/legacy keys are ignored.
- [x] Unit tests in `novelsTests` at `apps/novelsTests/` cover Codable, repository isolation (temp Application Support), cache semantics/identity, and settings sanitize; UI tests in `novelsUITests` at `apps/novelsUITests/` exist with a launch smoke test (`LaunchSmokeTests.testAppLaunches`) and both targets pass `xcodebuild test`.
- [x] `./init.sh` passes after `xcodebuild build` and `xcodebuild test` for the new test target.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/decisions/local-persistence.md](../docs/decisions/local-persistence.md)
- [docs/decisions/book-identity.md](../docs/decisions/book-identity.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/book-package.md](../docs/contracts/book-package.md)
- [docs/product/domain-model.md](../docs/product/domain-model.md)
- [docs/product/business-rules.md](../docs/product/business-rules.md)
- [docs/product/functional-specs/settings-management.md](../docs/product/functional-specs/settings-management.md)
- [docs/product/functional-specs/book-import.md](../docs/product/functional-specs/book-import.md)
- [docs/product/functional-specs/book-library.md](../docs/product/functional-specs/book-library.md)
- [docs/product/functional-specs/book-reader.md](../docs/product/functional-specs/book-reader.md)
- [apps/novels/Domain/](../apps/novels/Domain/)
- [apps/novels/Persistence/](../apps/novels/Persistence/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` (40 tests passed: DomainCodableTests 13, BookRepositoryTests 13, ProcessedChapterCacheTests 6, SettingsStoreTests 6, FixtureTests 1, LaunchSmokeTests 1). Executed `./init.sh` (format 0/24, lint 0 violations, build PASS, test PASS). Strict ZIP rejection was subsequently amended by tolerant ingestion in [task-tolerant-zip-ingestion](task-tolerant-zip-ingestion.md) (`docs/contracts/book-package.md`). Historical UI smoke test suite was later retired under the focused unit test policy (`docs/decisions/verification.md`).
- Blockers: None.
- Next: HISTORICAL: feat-002 App Shell + Home Library ready to activate.
