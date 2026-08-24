# feat-004 — Offline Book Reader

## Goal

Provide offline `WKWebView` reader for raw `chapter-N.html` with bounded navigation, saved offset, and typography.

## Scope

- `WKWebView` via `UIViewRepresentable` loading `Application Support/novels/books/<slug>/chapters/chapter-N.html` (no AI content).
- 1-based prev/next and References index; bounds prevent under/overflow.
- Per-book scroll offset save/restore via session store from feat-001; `onScreen` lifecycle on enter/back.
- Typography controls wired to store — Reading bottom sheet owns font picker + size/lineHeight/letterSpacing steppers + gear stub to Settings; changes persist via feat-001 `SettingsStore.typography` (applies to every `WKWebView` render).
- Overscroll/edge navigation: scroll beyond threshold auto-advances chapter with short lock prevents rapid jumps; prev/next disabled at bounds; References select returns; to-bottom button; swipe-back disabled per `docs/design/navigation.md:37`.
- Missing-content error toast; fully offline, no network calls.

## Non-goals

- No AI translate/summary, no prefetch, no settings editing, no catalog work.

## Acceptance

- [ ] Reader renders raw HTML for `1 <= N <= count`; prev/next disabled at bounds; References selects and returns to Reading.
- [ ] Scroll beyond threshold auto-advances chapter with short lock prevents rapid jumps; prev/next disabled at bounds; References select returns; to-bottom button; swipe-back disabled per `docs/design/navigation.md:37` (`docs/product/flows.md:36`, `docs/product/functional-specs/book-reader.md:8`).
- [ ] Scroll offset saved per slug and restored on resume/re-entry; `onScreen` set/cleared correctly.
- [ ] Typography controls in Reading sheet (font picker + size/lineHeight/letterSpacing steppers) persist via feat-001 `SettingsStore.typography` and apply to `WKWebView` content immediately.
- [ ] Missing `chapter-N.html` toasts 'Không tìm thấy chương' no crash; rapid nav no corrupt; offset saved per slug restored on resume.
- [ ] Rapid navigation does not corrupt offset.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/local-data.md`, `docs/contracts/book-package.md`, `docs/contracts/settings-schema.md` (typography keys/range)
- `docs/product/functional-specs/book-reader.md`, `docs/product/flows.md`
- `docs/design/screens.md`, `docs/design/navigation.md`, `docs/design/design-system.md`

## Plan

External plan required at activation (≥4 files expected) — create `docs/plans/feat-004.md` per `feat-001` template (`features/feat-001.md:47-51` and `docs/plans/feat-001.md`).

- Link: `docs/plans/feat-004.md` (to be created at activation)

## Ownership

- Owns: `ReaderView`, `WKWebView` Representable, `ReaderViewModel`, Reading sheet (typography + nav controls), typography wiring to `SettingsStore`
- Shared: offset persistence via feat-001 (`ReadingSession`/`SettingsStore`), book file read via feat-001 `FileBookRepository`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001, feat-002, feat-003 completion before activation
