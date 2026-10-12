# Chapter Scroll Reset on Swipe

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-013](task-edge-swipe-navigation.md)
- Required to integrate/release: none
- Previous ID: feat-029

## Scope and non-goals

Ensure horizontal chapter navigation always opens at the top of the newly selected chapter, even when swiping quickly while the `ScrollView` has vertical inertial momentum:
- Force `ScrollView` structural identity regeneration by applying `.id(viewModel.chapterNumber)` directly to the reader `ScrollView` in `apps/novels/Features/Reading/ReaderView.swift`. This cancels previous scroll momentum and clears residual offset state upon chapter transitions.
- Retain existing `scrollToTop()` calls as secondary backups and preserve `restoreOffset()` when returning from the diagnostic log screen.

Non-goals: No alterations to gestures, swipe thresholds, `EdgeSwipeDecision`, or `ReaderViewModel` navigation methods; no changes to intra-chapter `aiMode` switches; no timer or delay workarounds.

## Acceptance

- [x] Swiping horizontally at the bottom of a chapter to navigate to a new chapter opens at top without preserving old scroll offset.
- [x] Tapping previous/next buttons still resets scroll to top.
- [x] Returning to the same chapter (return from log viewer) restores saved scroll offset.
- [x] `./init.sh --quick` PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/functional-specs/book-reader.md](../docs/product/functional-specs/book-reader.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Features/Reading/ReaderView.swift](../apps/novels/Features/Reading/ReaderView.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed full `./init.sh` build-only verification PASS (format 0/57, lint 0 violations, build PASS on iPhone 17 Pro iOS 26.5, test skipped by repository decision per `docs/decisions/verification.md`, drift check PASS 21/22). Code change isolated to adding `.id(viewModel.chapterNumber)` on `ScrollView`. Real-device gesture QA was deferred to manual device testing.
- Blockers: None.
- Next: HISTORICAL: Manual gesture QA on physical device to verify swipe transitions during active scroll inertia.
