# feat-003 — Catalog Import + ZIP Ingestion

## Goal

Enable discovery and offline import of book ZIP packages from the remote catalog with strict validation and atomic replacement.

## Scope

- Catalog POST to `BOOKS_API_URL` with no body/auth; states loading/empty/error with retry.
- `URLSession` download of selected ZIP to temp directory.
- Strict archive-root validation (`book.json` at root, `chapters/chapter-N.html` 1..count, reject wrapper/`__MACOSX`).
- Atomic ingest to `Application Support/novels/books/<slug>/` via replacement boundary from feat-001; delete temp ZIP only after success.
- Re-import of same slug overwrites atomically; Home Library refreshes on success.
- Consumes atomic replacement boundary from feat-001; do not reopen persistence decisions.

## Non-goals

- No `WKWebView` reader UI, no AI processing/prefetch, no settings editor UI beyond reading `BOOKS_API_URL`.

## Acceptance

- [ ] POST catalog with empty body shows list; error/empty each have retry; no auth header sent.
- [ ] ZIP downloads to temp via `URLSession`; invalid root layout rejected with toast, no partial folder left.
- [ ] Valid ZIP atomically replaces `books/<slug>/`; ZIP deleted only on success; re-import overwrites.
- [ ] Library reflects newly imported book without restart.
- [ ] Offline catalog shows error with retry; no crash.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/catalog-api.md`, `docs/contracts/book-package.md`, `docs/contracts/local-data.md`
- `docs/decisions/book-identity.md`, `docs/decisions/local-persistence.md`
- `docs/product/functional-specs/book-import.md`, `docs/product/functional-specs/book-library.md`

## Plan

Detailed planning deferred until activation; inline plan only if bounded.

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001 and feat-002 completion before activation
