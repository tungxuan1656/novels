# feat-003 — Catalog Import + ZIP Ingestion

## Goal

Enable discovery and offline import of book ZIP packages from the remote catalog with strict validation and atomic replacement.

## Scope

- Catalog POST to `BOOKS_API_URL` with no body/auth; states loading/empty/error with retry + pull-to-refresh. POST returns `{success, data, message}` per `docs/contracts/catalog-api.md:24`; on `success:false` display `message` toast, no folder created.
- `URLSession` download of selected ZIP to temp directory with blocking overlay spinner simple (“Đang tải…” / “Đang giải nén…”) per clarification 2026-08-25.
- Strict archive-root validation (`book.json` at root, `chapters/chapter-N.html` 1..count, reject wrapper/`__MACOSX`) with generic toast “Gói sách không hợp lệ, không thể nhập” per clarification.
- Atomic ingest to `Application Support/novels/books/<slug>/` via replacement boundary from feat-001; delete temp ZIP only after success; temp cleanup on failure/cancel.
- Re-import of same slug overwrites atomically without confirm per clarification 2026-08-25; Home Library refreshes on success via `LibraryViewModel.refresh()` and pop to Library.
- Catalog list sorted locally: default Tên A→Z, option Mới nhất (lastUpdated desc) per clarification; no search/filter — YAGNI.
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

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan required at activation (≥4 files expected) — created `docs/plans/feat-003.md` per `feat-001` template (`features/feat-001.md:47-51` and `docs/plans/feat-001.md`).

- Link: `docs/plans/feat-003.md` (accepted design 2026-08-25 — approach A minimal spec-faithful)

## Ownership

- Owns: `CatalogService`, `ImportViewModel`, `AddBookView`, Download+Unzip boundary via feat-001 `FileBookRepository`
- Shared: `LibraryView` refresh hook (owned by feat-002, consumed here on import success)

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: Accepted design recorded at `docs/plans/feat-003.md` (2026-08-25, approach A) — covers CatalogService POST contract, ImportViewModel states + sort + atomic replace, AddBookView + Router/Library integration, verification. Feature file scope clarified for sort/spinner/toast/ghi đè per brainstorm.
- Blockers: none
- Next: Awaiting user review of `docs/plans/feat-003.md` and `features/feat-003.md` before implementation planning; activation ready (depends_on feat-001, feat-002 done)
