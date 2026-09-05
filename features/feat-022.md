# feat-022 — Reading Position Restore (Simple)

## Goal

Remember the last reading position `(bookId, chapterNumber, offset)` and restore it after backing out to Library or killing the app, using the simplest mechanism possible. Accepted trade-off: the top of the chapter may flash briefly before jumping to X (no instant / no-animation / no-flash requirement).

## Scope

- `apps/novels/Features/Reading/ReaderView.swift`: replace the complex `restoreOffset` (20×50ms wait-loop + 150ms reassert + `isRestoringOffset` flag + early-exit) with restore-once: after `load()`, wait until data is ready (`!isLoading`, ~2s timeout) then assign `scrollPosition` to the saved offset exactly once. Delete the `isRestoringOffset` flag and all related guards. Keep `debouncedSave` 300ms, `flushPendingOffset`, `scrollToTop`, `onDisappear`, `scenePhase.background` untouched.
- `apps/novels/Features/Reading/ScrollOffsetPreference.swift`: keep the target reader helper (`ReaderOffsetRestore.offsetToRestore`); remove parts that only served the old mechanism if now dead.
- Do not touch `Router.swift`, `AppRoot.swift`, `ReaderViewModel.swift`, `SettingsStore.swift`: keep the save path (settle + disappear/background flush), `onScreen` semantics (only `popReading` clears), `persistChapter` offset reset on chapter change, `restoreInitialRoute`.
- Existing tests (`ReaderViewFixTests`, `SeamlessRestoreTests`): update tests asserting removed machinery + add a restore-once test. No new test files.

## Non-goals

- No instant-restore, no mandatory `disablesAnimations`, no early-exit poll-loop, no leading throttle, no `synchronize()`, no separate file store, no block-id mapping, no `scrollTo(id)`, no terminate observer.
- No TOC/References/Library/AI/Prefetch/Settings/Docs changes.
- No migration, no `ReadingSession` schema change, no Keychain/SwiftData.

## Acceptance

- [ ] Reading at X, back to Library, tap the same book again → shows X (brief top flash acceptable).
- [ ] Reading at X, stop scrolling for >1s then swipe-kill the app, relaunch → opens straight into Reading with the right book/chapter, shows X after a brief top (lag ~1s acceptable).
- [ ] Chapter change (prev/next buttons, edge swipe, TOC) → top, offset reset.
- [ ] `./init.sh` full PASS.

## Relevant docs

- `docs/product/flows.md` (reading flow)
- `docs/contracts/local-data.md` (UserDefaults-only session)
- `ARCHITECTURE.md` §1/§5
- `AGENTS.md` (harness)

## Plan

Inline (bounded: ~1–2 source files, net negative lines, single writer, no `docs/plans/` split).

1. Writer (@fixer, single lane): read current `ReaderView.swift` (`onAppear`, `restoreOffset`, `isRestoringOffset`, `scrollToTop`) + `ScrollOffsetPreference.swift`.
2. Writer: replace `restoreOffset` with wait-for-`!isLoading` (100ms poll, ~2s timeout) then assign `scrollPosition` once per `offsetToRestore`; delete `isRestoringOffset`, `shouldReassert`, 150ms reassert, early-exit; keep `scrollToTop` on real chapter change.
3. Writer: remove dead helpers (if any), update existing tests + add restore-once test.
4. Writer: `./init.sh --quick` loop.
5. Orchestrator: full `./init.sh` to close, update feature done + `progress.md`.

File ownership: single writer owns all (no parallel).

## Verify

- `./init.sh --quick` (loop)
- `./init.sh` (full to close)
- Manual ×5: scroll to X → back → re-enter shows X; scroll to X → wait >1s → swipe-kill → relaunch shows X after brief top; change chapter → top.

## Handoff

- State: todo (awaiting user approval to activate + implement)
- Evidence: —
- Blockers: none
- Next: user approves plan (notably the Acceptance trade-off), then activate feat-022 for implementation.
