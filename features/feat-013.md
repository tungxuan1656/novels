# feat-013 — Edge Swipe Prev/Next Chapter (pivoted from overscroll)

## Goal

Swipe horizontally from the left/right third of the content to prev/next chapter: swipe RIGHT starting in the LEFT third → previous chapter, swipe LEFT starting in the RIGHT third → next chapter. Both land at top (offset 0) for simplicity.

## Context

Vertical overscroll failed 3 rounds (rubber-banding not measurable → threshold → state machine still false-firing at rest/ping-pong). User decided to pivot to an explicit horizontal gesture: no conflict with vertical scroll, no dependence on bounce/insets/velocity.

## Scope

- DELETE the entire overscroll machinery in `ReaderView.swift`: trigger/hint pill + overlays, armed/rest/programmatic/settle/lock/cooldown, overscroll toasts, `DEBUG-ROUND3-TEMP` overlay. DELETE dead overscroll helpers in `ScrollOffsetPreference.swift` (keep the file for the new helper).
- KEEP: per-book offset save/restore (debounced save + scrollPosition + restoreOffset), `scrollToTop`, header prev/next buttons, toasts, haptics, offline/iPhone-only/Vietnamese UI.
- NEW edge-swipe in 3 screen columns: swipe RIGHT starting in the LEFT third → prev; swipe LEFT starting in the RIGHT third → next; middle third ignores the gesture. `DragGesture(minimumDistance: 10)` via `simultaneousGesture` on the ScrollView (vertical scroll unaffected); direction lock `|dx| >= 60 && |dx| > 2*|dy|`; fire on `.onEnded` (naturally single-fire) + 600ms throttle; bound toast “Đã là chương đầu/cuối” once; both prev/next land at top.
- Pure testable helper (e.g. `EdgeSwipeDecision`) + tests replacing the old excursion tests (keep the test file compiling).

## Non-goals

- No coachmark/discoverability hint (header buttons remain).
- No new Settings keys, no SQLite/AI/prefetch/catalog/Router changes.

## Acceptance

- [x] Swipe right within left third → prev lands top; swipe left within right third → next lands top; exactly 1 chapter per swipe.
- [x] Vertical/diagonal swipes don't trigger; wrong-direction swipes in a zone are ignored; bounds toast, no crash.
- [x] Nothing fires at rest; no ping-pong; per-book offset save/restore intact.
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/product/functional-specs/book-reader.md`
- `docs/product/flows.md` §4
- `docs/design/screens.md` (Reading)
- `ARCHITECTURE.md` §4

## Plan

1. `ReaderView.swift`: delete overscroll machinery + debug overlay; attach edge-swipe gesture + width from geometry.
2. `ScrollOffsetPreference.swift`: pure decision helper.
3. Edge-decision tests; `./init.sh --quick` then full.

## Verify

- `./init.sh` full
- `xcodebuild test` Reader suites

## Handoff (pivot — done)

- State: done — edge swipe in thirds replaced the overscroll machinery; thirds amendment applied in the same lane; docs kept in English per user request.
- Evidence: overscroll trigger/hint/armed/rest/programmatic/settle/lock + DEBUG overlay deleted; `EdgeSwipeDecision` thirds + direction lock + 600ms throttle; 12 new edge tests (18 ReaderViewFixTests pass); `./init.sh` full PASS (format 0/89, lint 0, build PASS, test PASS incl. UITests, drift PASS).
- Blockers: none
- Next: repo idle — user retests edge swipe on Simulator (both thirds + bounds + vertical-scroll safety).
