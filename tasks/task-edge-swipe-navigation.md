# Edge Swipe Prev/Next Chapter

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md)
- Required to integrate/release: none
- Previous ID: feat-013

## Scope and non-goals

Replace vertical overscroll chapter switching with explicit horizontal edge swipe gesture navigation:
- Remove previous overscroll machinery in `ReaderView.swift` (trigger/hint pills, armed/rest state machines, cooldown locks, and overscroll toasts), superseding vertical overscroll from [task-offline-reader](task-offline-reader.md).
- Implement horizontal edge swipe in screen thirds:
  - Swipe RIGHT starting in the LEFT third navigates to the previous chapter.
  - Swipe LEFT starting in the RIGHT third navigates to the next chapter.
  - Touches starting in the middle third ignore the gesture.
- Gesture configuration: `DragGesture(minimumDistance: 10)` attached via `simultaneousGesture` on the `ScrollView` so vertical scrolling remains uninhibited; direction lock enforcing `|dx| >= 60 && |dx| > 2*|dy|`; fires on `.onEnded` with a 600ms throttle; boundary toast “Đã là chương đầu/cuối” displayed once at boundaries; both navigations reset position to top.
- Pure helper `EdgeSwipeDecision` with unit tests replacing legacy overscroll excursion tests.
- Retain per-book scroll offset save/restore, top scroll helper, header previous/next buttons, and offline stability.

Non-goals: No coachmark or discoverability overlays (header buttons remain accessible); no new settings keys; no SQLite, AI, or Router changes.

## Acceptance

- [x] Swipe right within left third → prev lands top; swipe left within right third → next lands top; exactly 1 chapter per swipe.
- [x] Vertical/diagonal swipes don't trigger; wrong-direction swipes in a zone are ignored; bounds toast, no crash.
- [x] Nothing fires at rest; no ping-pong; per-book offset save/restore intact.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/functional-specs/book-reader.md](../docs/product/functional-specs/book-reader.md)
- [docs/product/flows.md](../docs/product/flows.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full verification (format 0/89, lint 0, build PASS, test PASS including 18 ReaderViewFixTests and edge swipe decision tests, drift PASS). Overscroll trigger code removed; `EdgeSwipeDecision` thirds boundary testing passed. Canonical reading behavior documented in `docs/product/functional-specs/book-reader.md`.
- Blockers: None.
- Next: HISTORICAL: Manual verification of edge swipes on Simulator across both boundaries and vertical scrolling safety.
