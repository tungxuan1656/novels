# Prefetch FIFO Queue Refactor

- Status: done
- Owner: Tung Doan
- Required to start: [feat-023](task-reader-prefetch-guards.md)
- Required to integrate/release: none
- Previous ID: feat-024

## Scope and non-goals

Refactor the chapter prefetch engine into a persistent in-memory FIFO queue, superseding the sliding-window batch-cancellation mechanism, hardCap, polling, and debounce from [task-reader-prefetch-guards](task-reader-prefetch-guards.md):
- Prefetch FIFO queue architecture in `PrefetchManager.swift`: maintain `pending` queue, `inFlight` task tracking, and retry attempt counters; implement `ensureWindow` logic that retains existing overlapping in-flight chapters and appends only new tail chapters; sequential worker processes queue items in order; cancellation occurs strictly on book or mode switches.
- Remove redundant reader-side mechanisms in `ReaderViewModel.swift`: delete the 200ms trigger debounce, 100ms prefetch polling timer, and prefetch epoch counters; retain zero-API behavior for current chapter upon returning from logs while allowing the background queue to process pending chapters.
- Remove artificial hard cap (`hardCap = 10`) and logging churn, logging the configured single prefetch count transparently.
- Maintain cache query safety (`batchStatus`) and diagnostic log group status badging.

Non-goals: No changes to active AI generation or reader identity gates; no budget/timeout modifications; no outer-chapter concurrency (sequential queue worker maintained); no SQLite cache schema migration.

## Acceptance

- [x] Walk 450→451→450→451: continuous forward progress, no silent skip; Log shows FIFO order per window.
- [x] Steady reading: ~1 tail fetch per next, no full-batch churn/cancel spam in Log.
- [x] Transient failure retried once then logged-dropped; next window picks it up via miss (no failed-first reorder).
- [x] N=20 at 450 issues window 451-470 once; navigating to 451 keeps the running task, appends only 471.
- [x] `returnFromLog` on same chapter+mode: zero API for current chapter, background queue resumes if misses remain.
- [x] All pre-existing suites green except intentionally-changed debounce/cap tests (cited); `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/functional-specs/chapter-prefetch.md](../docs/product/functional-specs/chapter-prefetch.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/product/flows.md](../docs/product/flows.md)
- [apps/novels/Services/PrefetchManager.swift](../apps/novels/Services/PrefetchManager.swift)
- [apps/novels/Features/Reading/ReaderViewModel.swift](../apps/novels/Features/Reading/ReaderViewModel.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, unit tests (`PrefetchFifoQueueTests` covering queue order, running task retention on navigation, and tail appending), and drift checks. Superseded batch-cancel behaviors from [task-reader-prefetch-guards](task-reader-prefetch-guards.md) were replaced by the durable FIFO queue.
- Blockers: None.
- Next: HISTORICAL: Owner retest walks #2/#4 (steady-next tail, N=20 keep+append-471, returnFromLog resume); push only on request.

## Recovery And Parked Work

Historical core commit: `974661a`. Cache entry points gained `NSLock`; the recorded review found no deadlock.
The M3 same-mode guard was attempted then reverted because it broke two suites; full verification passed after reverting.
At commit time an initial build/test check failed without capturing the failing test; the full retry passed (`init-commit.log`, exit 0) and 11 files were committed without a production/test fix. Do not claim the first run passed or infer its root cause.
Review majors M1/M2/M3/M4/M5 and test gaps remained parked pending owner sign-off.
See [reader/prefetch deferred proposals](task-reader-prefetch-guards.md) for the historical hash-migration, status-publication and measurement-gated concurrency proposals. None is authorization for new work.
