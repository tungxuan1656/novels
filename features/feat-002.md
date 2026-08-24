# feat-002 — App Shell + Home Library

## Goal

Establish NavigationStack startup routing and offline Home Library shell with shared primitives so later import/reader/settings flows have a consistent Vietnamese UI container.

## Scope

- Startup restore of session/settings (no network) and routing `onScreen ? Reading(bookId: slug) : Library` per `docs/design/navigation.md`.
- `NavigationStack` with routes Library (root), Reading, References — shell only, no reader content.
- Shared primitives: loading overlay, toast, bottom sheet.
- Offline Library: scan `Application Support/novels/books/<slug>/`, list rows from `book.json`, empty state when none.
- Info/details + chapter index bottom sheet from selected book.
- Swipe-to-delete with confirmation; deletes slug folder via repository boundary from feat-001.
- Vietnamese UI strings; iPhone-only shell.

## Non-goals

- No catalog import/ZIP download, no `WKWebView` reader, no settings UI, no AI/prefetch.

## Acceptance

- [ ] Launch restores session and routes correctly; invalid `bookId` toasts and stays on Library.
- [ ] Library lists only folders with valid `book.json`; empty state shown when zero books.
- [ ] Info sheet shows `name`/`author`/`count`/`references`; delete confirms then removes folder and refreshes list.
- [ ] Loading/toast/bottom-sheet primitives work on Library; Vietnamese copy present.
- [ ] Back at root does not crash; Reading back clears `onScreen`.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`
- `docs/contracts/local-data.md`, `docs/contracts/book-package.md`
- `docs/product/functional-specs/book-library.md`, `docs/product/flows.md`, `docs/product/domain-model.md`

## Plan

Detailed planning deferred until activation; inline plan only if bounded (<4 files, <200 lines).

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Select/approve feat-001 for activation; feat-002 starts after feat-001 done
