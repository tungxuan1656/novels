# Reading Position Restore

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md)
- Required to integrate/release: none
- Previous ID: feat-022

## Scope and non-goals

Simplify and reliably restore reading scroll positions `(bookId, chapterNumber, offset)` when returning from the Library or relaunching after application termination:
- Streamline restoration machinery: replace complex 20x50ms wait loops, reassert timers, and state flags in `ReaderView.swift` with a single restore-once mechanism: wait for content readiness (`!isLoading`, ~2s timeout), then assign `scrollPosition` directly to the persisted offset.
- Remove redundant state guards: delete `isRestoringOffset` and `shouldReassert` flags while preserving 300ms offset debouncing, background phase flushes, and offset clearing on chapter switches.
- Update helper logic in `ScrollOffsetPreference.swift` to retain pure target offset resolution (`ReaderOffsetRestore.offsetToRestore`).
- Retain session persistence in `UserDefaults` via `SettingsStore` and router restoration semantics.

Non-goals: No zero-flash or animation-free mandate (a brief jump to top before scrolling to offset is acceptable); no block-id element mapping; no database schema modifications.

## Acceptance

- [x] Reading at X, back to Library, tap the same book again → shows X (brief top flash acceptable).
- [x] Reading at X, stop scrolling for >1s then swipe-kill the app, relaunch → opens straight into Reading with the right book/chapter, shows X after a brief top (lag ~1s acceptable).
- [x] Chapter change (prev/next buttons, edge swipe, TOC) → top, offset reset.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/flows.md](../docs/product/flows.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [apps/novels/Features/Reading/ReaderView.swift](../apps/novels/Features/Reading/ReaderView.swift)
- [apps/novels/Features/Reading/ScrollOffsetPreference.swift](../apps/novels/Features/Reading/ScrollOffsetPreference.swift)
- [apps/novels/Persistence/SettingsStore.swift](../apps/novels/Persistence/SettingsStore.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, unit tests (`ReaderRestorePhase2Tests` verifying single assignment and `SeamlessRestoreTests` verifying save paths), and drift checks. Removed legacy reassert timers and state variables.
- Blockers: None.
- Next: HISTORICAL: Manual verification on Simulator for scroll restore upon return, cold relaunch restore, and offset reset on chapter navigation.
