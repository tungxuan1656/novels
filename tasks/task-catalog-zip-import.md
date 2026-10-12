# Catalog Import + ZIP Ingestion

- Status: done
- Owner: Tung Doan
- Required to start: [feat-001](task-persistence-foundation.md), [feat-002](task-app-shell-library.md)
- Required to integrate/release: none
- Previous ID: feat-003

## Scope and non-goals

Enable catalog discovery and offline book import from the remote catalog API:
- Catalog client sending HTTP POST to `BOOKS_API_URL` with empty body and no authentication; handles loading, empty, and error states with pull-to-refresh and retry.
- Ingestion flow: `URLSession` downloads selected ZIP to a temporary directory with a blocking overlay spinner (“Đang tải…”, “Đang giải nén…”).
- Strict package validation rejecting non-root layouts and `__MACOSX` wrappers with toast “Gói sách không hợp lệ, không thể nhập”. Note: strict archive-root rejection implemented here was later superseded by tolerant ingestion in [task-tolerant-zip-ingestion](task-tolerant-zip-ingestion.md) (`docs/contracts/book-package.md`).
- Atomic ingestion into `Application Support/novels/books/<slug>/` via `FileBookRepository`; deletes temp file only after success; cleanup on cancellation or failure; re-import overwrites atomically.
- Local catalog list sorting: default name A-Z, optional newest date; Library view refreshes on pop.

Non-goals: No HTML text reader rendering, no AI processing or prefetch, and no settings editor UI beyond reading `BOOKS_API_URL`.

## Acceptance

- [x] POST catalog with empty body shows list; error/empty each have retry; no auth header sent.
- [x] Request has `Content-Type: application/json`, empty body, no auth; `success:false` shows `message` toast per `docs/contracts/catalog-api.md:24`, no folder created.
- [x] Empty list shows empty state; error has retry.
- [x] ZIP downloads to temp via `URLSession`; invalid root layout (wrapper/`__MACOSX`) rejected with toast, no partial folder left.
- [x] Valid ZIP atomically replaces `books/<slug>/`; ZIP deleted only on success; re-import overwrites.
- [x] Library reflects newly imported book without restart.
- [x] Offline catalog shows error with retry; no crash.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/catalog-api.md](../docs/contracts/catalog-api.md)
- [docs/contracts/book-package.md](../docs/contracts/book-package.md)
- [docs/decisions/book-package-shape.md](../docs/decisions/book-package-shape.md)
- [docs/product/functional-specs/book-import.md](../docs/product/functional-specs/book-import.md)
- [apps/novels/Services/](../apps/novels/Services/)
- [apps/novels/Features/Import/](../apps/novels/Features/Import/)
- [apps/novels/Persistence/](../apps/novels/Persistence/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` (format 0/45, lint 0 violations, build PASS, test PASS 60+ tests including CatalogServiceTests 6, ImportViewModelTests 7, RouterTests 6). Full `xcodebuild test` passed in 194s. Strict ZIP rejection behavior recorded in acceptance criterion 4 was subsequently updated by tolerant ingestion in [task-tolerant-zip-ingestion](task-tolerant-zip-ingestion.md) (`docs/contracts/book-package.md`). Individual test suites mentioned here are historical records and subject to the current verification policy (`docs/decisions/verification.md`).
- Blockers: None.
- Next: HISTORICAL: feat-004 Offline Book Reader or feat-005 Settings + Cache Manager ready to activate.
