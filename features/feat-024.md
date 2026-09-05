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

- [ ] Walk 450→451→450→451: continuous forward progress, no silent skip; Log shows FIFO order per window.
- [ ] Steady reading: ~1 tail fetch per next, no full-batch churn/cancel spam in Log.
- [ ] Transient failure retried once then logged-dropped; next window picks it up via miss (no failed-first reorder).
- [ ] N=20 at 450 issues window 451-470 once; navigating to 451 keeps the running task, appends only 471.
- [ ] `returnFromLog` on same chapter+mode: zero API for current chapter, background queue resumes if misses remain.
- [ ] All pre-existing suites green except intentionally-changed debounce/cap tests (cited); `./init.sh` full PASS.

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

- State: active (plan approved with defaults: no hardCap, cancel only on book/mode change, attempts≤1; execution subagent-driven)
- Evidence: `docs/plans/feat-024.md`, this file, `feature_index.json` (feat-024 active, depends_on feat-023)
- Blockers: none
- Next: Phase 0 baseline + Phase 1 Lane P (FIFO core)
