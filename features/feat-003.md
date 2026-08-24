# feat-003 — Catalog Import + ZIP Ingestion

## Goal

Enable discovery and offline import of book ZIP packages from the remote catalog with strict validation and atomic replacement.

## Scope

- Catalog POST to `BOOKS_API_URL` with no body/auth; states loading/empty/error with retry. POST returns `{success, data, message}` per `docs/contracts/catalog-api.md:24`; on `success:false` display `message` toast, no folder created.
- `URLSession` download of selected ZIP to temp directory.
- Strict archive-root validation (`book.json` at root, `chapters/chapter-N.html` 1..count, reject wrapper/`__MACOSX`).
- Atomic ingest to `Application Support/novels/books/<slug>/` via replacement boundary from feat-001; delete temp ZIP only after success.
- Re-import of same slug overwrites atomically; Home Library refreshes on success.
- Consumes atomic replacement boundary from feat-001; do not reopen persistence decisions.

## Non-goals

- No Text reader UI (HTML→SwiftUI.Text), no AI processing/prefetch, no settings editor UI beyond reading `BOOKS_API_URL`.

## Acceptance

- [ ] POST catalog with empty body shows list; error/empty each have retry; no auth header sent.
- [ ] Request has `Content-Type: application/json`, empty body, no auth; `success:false` shows `message` toast per `docs/contracts/catalog-api.md:24`, no folder created.
- [ ] Empty list shows empty state; error has retry.
- [ ] ZIP downloads to temp via `URLSession`; invalid root layout (wrapper/`__MACOSX`) rejected with toast, no partial folder left.
- [ ] Valid ZIP atomically replaces `books/<slug>/`; ZIP deleted only on success; re-import overwrites.
- [ ] Library reflects newly imported book without restart.
- [ ] Offline catalog shows error with retry; no crash.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/catalog-api.md`, `docs/contracts/book-package.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md` (`BOOKS_API_URL`)
- `docs/decisions/book-identity.md`, `docs/decisions/local-persistence.md`
- `docs/product/functional-specs/book-import.md`, `docs/product/functional-specs/book-library.md`

## Plan

External plan required at activation (≥4 files expected) — create `docs/plans/feat-003.md` per `feat-001` template (`features/feat-001.md:47-51` and `docs/plans/feat-001.md`).

- Link: `docs/plans/feat-003.md` (to be created at activation)

## Ownership

- Owns: `CatalogService`, `ImportViewModel`, `AddBookView`, Download+Unzip boundary via feat-001 `FileBookRepository`
- Shared: `LibraryView` refresh hook (owned by feat-002, consumed here on import success)

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001 and feat-002 completion before activation
