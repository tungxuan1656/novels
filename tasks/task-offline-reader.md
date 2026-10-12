# Offline Book Reader

- Status: done
- Owner: Tung Doan
- Required to start: [feat-001](task-persistence-foundation.md), [feat-002](task-app-shell-library.md), [feat-003](task-catalog-zip-import.md)
- Required to integrate/release: none
- Previous ID: feat-004

## Scope and non-goals

Build the native offline text reader for `chapter-N.html` with bounded navigation, saved scroll offset, and typography customization:
- HTML parser translating chapter HTML tags (`div`, `p`, headings, formatting tags) into text spans rendered via `SwiftUI.Text`. Note: this span pipeline was later superseded by the title + single body string architecture in [task-title-body-reader](task-title-body-reader.md).
- 1-based previous and next chapter navigation and References table of contents selection; bounds checking prevents underflow and overflow.
- Per-book scroll offset saved and restored via `ReadingSession` / `SettingsStore`; `onScreen` tracked.
- Typography bottom sheet with font picker, size, line height, and letter spacing controls persisting via `SettingsStore.typography`. Note: letter spacing was later removed in [task-remove-letter-spacing](task-remove-letter-spacing.md).
- Vertical overscroll auto-advancement with cooldown locks. Note: vertical overscroll was later replaced by horizontal edge swipe navigation in [task-edge-swipe-navigation](task-edge-swipe-navigation.md).
- Offline missing chapter error handling toasts “Không tìm thấy chương” without crashing.

Non-goals: No AI processing, no prefetch, no settings configuration UI beyond typography, and no catalog integration.

## Acceptance

- [x] Parses HTML to spans and renders with `SwiftUI.Text` for `1 <= N <= count`; prev/next disabled at bounds; References selects and returns.
- [x] Overscroll auto-advances with short lock; to-bottom button; swipe-back disabled per `docs/design/navigation.md §3 Stack Structure` (`docs/product/flows.md §4 Reading`).
- [x] Offset saved per slug and restored on resume/re-entry; `onScreen` correct.
- [x] Bottom sheet controls (font + size/lineHeight/letterSpacing) persist via `SettingsStore.typography` and apply instantly.
- [x] Missing `chapter-N.html` toasts 'Không tìm thấy chương' without crash; rapid nav does not corrupt offset.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/functional-specs/book-reader.md](../docs/product/functional-specs/book-reader.md)
- [docs/product/flows.md](../docs/product/flows.md)
- [docs/design/navigation.md](../docs/design/navigation.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Domain/](../apps/novels/Domain/)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` (format 0/58, lint 0, build PASS, test PASS 165.7s, total ~81 tests including ReaderViewFixTests 11). Offline checks confirmed zero references to WebKit or network calls in reading components. Superseded behavior note: Spans rendering was superseded by [task-title-body-reader](task-title-body-reader.md); overscroll auto-advance was superseded by [task-edge-swipe-navigation](task-edge-swipe-navigation.md); letter spacing was removed in [task-remove-letter-spacing](task-remove-letter-spacing.md). Canonical behavior routes to `docs/product/functional-specs/book-reader.md`.
- Blockers: None.
- Next: HISTORICAL: feat-005 Settings + Cache Manager ready, or feat-006 AI Reading blocked until feat-005 finishes.
