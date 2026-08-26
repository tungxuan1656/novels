# feat-004 — Offline Book Reader

## Goal

Offline native Text reader for `chapter-N.html` with bounded nav, saved offset, and typography.

## Scope

- `SwiftUI.Text` pipeline for `Application Support/novels/books/<slug>/chapters/chapter-N.html` (`div`/`h*`/`p`/`br`/`b`/`strong`/`i`/`em`/`span` → spans → `VStack`); no AI.
- 1-based prev/next and References index; bounds block under/overflow.
- Per-book offset save/restore via feat-001 session store; `onScreen` on enter/back.
- Bottom sheet: font picker + size/lineHeight/letterSpacing + gear to Settings; persist via `SettingsStore.typography`.
- Overscroll auto-advances with short lock; prev/next disabled at bounds; to-bottom button; swipe-back disabled per `docs/design/navigation.md §3 Stack Structure`.
- Missing `chapter-N.html` toast; fully offline, no network.

## Non-goals

- No AI, prefetch, settings editing, or catalog.

## Acceptance

- [x] Parses HTML to spans and renders with `SwiftUI.Text` for `1 <= N <= count`; prev/next disabled at bounds; References selects and returns.
- [x] Overscroll auto-advances with short lock; to-bottom button; swipe-back disabled per `docs/design/navigation.md §3 Stack Structure` (`docs/product/flows.md §4 Reading`).
- [x] Offset saved per slug and restored on resume/re-entry; `onScreen` correct.
- [x] Bottom sheet controls (font + size/lineHeight/letterSpacing) persist via `SettingsStore.typography` and apply instantly.
- [x] Missing `chapter-N.html` toasts 'Không tìm thấy chương' without crash; rapid nav does not corrupt offset.

## Relevant docs

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan at activation — `docs/plans/feat-004.md` per feat-001.

- Link: `docs/plans/feat-004.md` (create at activation)

## Ownership

- Owns: `ReaderView`, `HtmlParser` + `TextSpan` → `SwiftUI.Text`, `ReaderViewModel`, sheet + typography wiring
- Shared: offset via feat-001 (`ReadingSession`/`SettingsStore`), file read via `FileBookRepository`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: done
- Evidence: `docs/plans/feat-004.md` + 8 commits 5135ab1 HtmlParser, d068d72 ViewModel, fbf9815 References, d1eec46 BottomSheet, 044c6d1 ReaderView, d50d6aa Router/AppRoot, 8de01b5 integration, ef80e5c fix overscroll+restore+font+debounce (11 tests ReaderViewFixTests) + `./init.sh` PASS (format 0/58 lint 0 build PASS test PASS 165.7s → 11 extra tests post-fix, total ~81 tests), `xcodebuild test` PASS, grep offline checks 0 hits WebKit/URLSession in Reading; oracle review NEEDS_FIX addressed (critical overscroll + 3 majors)
- Blockers: none
- Next: feat-005 Settings + Cache Manager ready (depends 001,002) OR feat-006 AI Reading blocked until 005 done — choose activation
