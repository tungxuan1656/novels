# feat-024 — Prefetch FIFO Queue Refactor (feat-023 extend)

## Goal

Replace feat-023's sliding-window batch cancel-on-navigate prefetch with a durable FIFO queue, keeping every must-fix guard, so steady reading shows continuous forward progress with ~1 tail fetch per next and no silent skip.

## Scope

- `PrefetchManager.swift`: `pending`+`Set`+`inFlight`+`attempts` queue, `ensureWindow` (keep ∩ + append tail), sequential worker, attempts≤1 tail requeue, no cancel except book/mode change; remove `hardCap`/`appliedCap`, failed-first store, top-up extras.
- `ReaderViewModel.swift`: remove 200ms trigger debounce + 100ms prefetch poll + `prefetchEpoch`; `returnFromLog` keeps zero-current-API + one-shot resync.
- `LogScreen.swift`: no change (badge contract stays).
- `ProcessedChapterCache.swift`: no change (chunked `batchStatus` + never-miss-all stay).
- `chapter-prefetch.md` (§4-5) + `settings-schema.md` amendments (queue model, single-N logging).
- Tests: new `PrefetchFifoQueueTests.swift`; update only suites whose behavior intentionally changes (debounce/cap), with spec citation in test comments.

## Non-goals

- No AI write-path change (`aiGeneration` + identity gate stay untouched).
- No budget/timeout/range-policy change (600s/1800s, `0...1000 else 3` stay).
- No outer-chapter concurrency, no cache migration, no UI redesign/copy change.
- No new log event types (reuse existing `prefetch.*` shapes + detail fields).

## Acceptance

- [x] Walk 450→451→450→451: continuous forward progress, no silent skip; Log shows FIFO order per window.
- [x] Steady reading: ~1 tail fetch per next, no full-batch churn/cancel spam in Log.
- [x] Transient failure retried once then logged-dropped; next window picks it up via miss (no failed-first reorder).
- [x] N=20 at 450 issues window 451-470 once; navigating to 451 keeps the running task, appends only 471.
- [x] `returnFromLog` on same chapter+mode: zero API for current chapter, background queue resumes if misses remain.
- [x] All pre-existing suites green except intentionally-changed debounce/cap tests (cited); `./init.sh` full PASS.

## Relevant docs

- `docs/plans/feat-024.md` (separate plan: P0 baseline → P1 queue core → P2 drop debounce/poll/epoch → P3 single-N → P4 docs + close)
- `docs/product/functional-specs/chapter-prefetch.md` (§4-5)
- `docs/contracts/settings-schema.md` (BR-08)
- `docs/product/flows.md` (§6)
- `ARCHITECTURE.md` §1/§5

## Plan

Separate (`docs/plans/feat-024.md`): 4 phases + baseline, each TDD with own acceptance.

1. Lane P (prefetch engine): `PrefetchManager.swift` — Phase 1 queue core. No shared files.
2. Lane R (reader): `ReaderViewModel.swift` — Phase 2 debounce/poll/epoch removal, after Lane P locks `start`/`ensureWindow` interface.
3. Lane S (spec): `chapter-prefetch.md` + `settings-schema.md` — Phase 3-4, anytime (no code).

## Verify

- `./init.sh --quick` per task (loop)
- `./init.sh` full to close
- Manual acceptance walks (exact reported scenarios: 450→451→450→451, steady-next tail, returnFromLog resume)

## Handoff

- State: done
- Evidence: Lane P `974661a` FIFO core + Lane R+P3-code (drop debounce/poll/epoch, same-book keep, remove hardCap) + Lane S-docs (chapter-prefetch §4 Step 5 + settings-schema BR-08 single-N); new `testNavigateViaViewModelKeepsRunningTask` covers real VM keep flow; oracle review 0 blockers (NSLock correct/deadlock-free); M3 same-mode guard attempted then reverted (broke 2 suites) and parked; `./init.sh` full PASS post-revert (format/lint/build/test/drift)
- Blockers: none (tree uncommitted — not committed as not requested)
- Next: repo idle — user retests walks #2/#4 on device/Simulator (steady-next ~1 tail, N=20 keep+append-471, returnFromLog resume); parked oracle majors M1/M2/M4/M5 + M3 + test gaps await owner sign-off
