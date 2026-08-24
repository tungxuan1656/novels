# feat-001 — Native Persistence Foundation

## Goal

Establish the native Swift persistence foundation (Application Support books, SQLite processed_chapters cache, UserDefaults @Observable settings/session/typography with string-slug identity) behind isolated, testable boundaries so later import, library, reader, AI, and prefetch features can build on it without reopening storage decisions.

## Scope

- Add the first unit test target `novelsTests` at `apps/novelsTests/` and UI test target `novelsUITests` at `apps/novelsUITests/` plus test fixtures (valid root ZIP, invalid wrapper ZIP, book.json, chapter HTML).
- Define pure Swift domain/Codable types needed by persistence: `Book`, `Chapter`, `Reference`, `ProcessedChapter`, `ReadingSession`, `TypographySetting`, settings models — using local `book.json.id` string slug and `book.json.count` number.
- Implement Application Support paths and a `FileManager` + `Codable` local book repository: exact package-root validation, 1-based chapter handling, invalid-folder skip, atomic writes, whole-book deletion.
- Implement the single `SQLite3` `processed_chapters` cache behind a protocol/actor boundary: schema versioning, `PRIMARY KEY (book_id, chapter_number, mode)` / `UNIQUE(book_id, chapter_number, mode)`, index on `book_id`, cache hit, batch status, upsert, clear-all, clear-by-book, and rejection of `mode == "none"` rows.
- Implement current-key-only settings/session/typography via `UserDefaults` behind `@Observable`: defaults, BR-12 sanitize rules, invalid JSON handling for `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` (ignored), unknown-key ignore; no legacy migration, no Keychain/SwiftData/Core Data/RN/second cache.

## Non-goals

- No UI screen implementation or navigation.
- No catalog networking or ZIP download flow beyond repository interfaces/fixtures.
- No AI client, HTML/`WKWebView` reader, prefetch runner, `ATS`/Xcode configuration, or production migration from the old React Native app.
- No change to `TARGETED_DEVICE_FAMILY`, deployment target, or current project source in this planning-only task.

## Acceptance

- [ ] `Book`, `Chapter`, `Reference`, `ProcessedChapter`, `ReadingSession`, `TypographySetting`, and settings models are Codable/pure Swift, use slug `id` and numeric `count`, and pass Codable round-trip tests.
- [ ] Repository paths resolve under `Application Support/novels/books/<slug>/` and `Application Support/novels/cache/processed_chapters.sqlite`; scan lists only folders with valid `book.json`; `chapters/chapter-N.html` 1-based validated; atomic write replaces file without partial state; `deleteBook(slug)` removes whole folder only.
- [ ] Repository rejects ZIPs not matching exact archive-root layout (`book.json` at root, `chapters/chapter-N.html` `1..count`); wrapper sample with outer folder/`__MACOSX` is treated as invalid in fixture test.
- [ ] `processed_chapters` SQLite schema matches `docs/contracts/local-data.md` (PRIMARY KEY/UNIQUE, index, no `none`, upsert, versioned via `user_version`); cache hit by `(book_id, chapter_number, mode)` works; batch status for prefetch range works; upsert overwrites; `clearAll()` and `clear(bookId:)` delete correctly; `mode == "none"` is never written.
- [ ] Settings `@Observable` store exposes current keys only with defaults `gpt-4o`, prefetch `3`, chunk `1300`, `openai`, catalog/AI URLs; sanitize on load enforces BR-12; invalid `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` JSON is ignored; unknown/legacy keys are ignored.
- [ ] Unit tests in `novelsTests` at `apps/novelsTests/` cover Codable, repository isolation (temp Application Support), cache semantics/identity, and settings sanitize; UI tests in `novelsUITests` at `apps/novelsUITests/` exist with a launch smoke test (`LaunchSmokeTests.testAppLaunches`) and both targets pass `xcodebuild test`.
- [ ] `./init.sh` passes after `xcodebuild build` and `xcodebuild test` for the new test target.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/decisions/local-persistence.md`
- `docs/decisions/book-identity.md`
- `docs/contracts/local-data.md`
- `docs/contracts/settings-schema.md`
- `docs/contracts/book-package.md`
- `docs/product/domain-model.md`
- `docs/product/business-rules.md`
- `docs/product/functional-specs/settings-management.md`
- `docs/product/functional-specs/book-import.md`
- `docs/product/functional-specs/book-library.md`
- `docs/product/functional-specs/book-reader.md`

## Plan

External plan required — substantial work (≥4 files, SQLite schema, test target, phases/rollback).

- Link: `docs/plans/feat-001.md`

## Verify

- `./init.sh`
- After implementation: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
- After implementation: `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
- Manual: persistence isolation check — tests use temp Application Support/SQLite in-memory or temp file, never the real `Application Support/novels/`

## Handoff

- State: todo
- Evidence: `features/feat-001.md`, `docs/plans/feat-001.md` — plan created against canonical contracts listed above; no Swift/Xcode code modified
- Blockers: none
- Next: Awaiting user approval to activate feat-001 and start implementation (do not start without explicit go-ahead)

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
