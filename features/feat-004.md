# feat-004 — Offline Book Reader

## Goal

Provide offline `WKWebView` reader for raw `chapter-N.html` with bounded navigation, saved offset, and typography.

## Scope

- `WKWebView` via `UIViewRepresentable` loading `Application Support/novels/books/<slug>/chapters/chapter-N.html` (no AI content).
- 1-based prev/next and References index; bounds prevent under/overflow.
- Per-book scroll offset save/restore via session store from feat-001; `onScreen` lifecycle on enter/back.
- Typography application from `@Observable` store; read-only in this feature.
- Overscroll/edge navigation handling, missing-content error toast.
- Fully offline; no network calls.

## Non-goals

- No AI translate/summary, no prefetch, no settings editing, no catalog work.

## Acceptance

- [ ] Reader renders raw HTML for `1 <= N <= count`; prev/next disabled at bounds; References selects and returns to Reading.
- [ ] Scroll offset saved per slug and restored on resume/re-entry; `onScreen` set/cleared correctly.
- [ ] Typography changes apply to `WKWebView` content.
- [ ] Missing chapter file shows error toast without crash.
- [ ] Rapid navigation does not corrupt offset.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/local-data.md`, `docs/contracts/book-package.md`
- `docs/product/functional-specs/book-reader.md`, `docs/product/flows.md`
- `docs/design/screens.md`, `docs/design/navigation.md`

## Plan

Detailed planning deferred until activation; inline plan only if bounded.

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001, feat-002, feat-003 completion before activation
