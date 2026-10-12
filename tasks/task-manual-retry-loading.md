# Single Attempt & Loading Flag Cleanup

- Status: done
- Owner: Tung Doan
- Required to start: [feat-015](task-parallel-chunks-retry.md)
- Required to integrate/release: none
- Previous ID: feat-016

## Scope and non-goals

Remove automatic client retries in favor of manual re-processing and resolve stuck chapter loading spinner states while background prefetch runs:
- Update `AIClient.complete` to a single request attempt without loop or backoff; fail immediately on HTTP or network errors. Note: retry and prefetch handling was later consolidated and superseded by [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).
- Keep parallel task groups and fail-fast processing in `AIReadingService`.
- Fix loading flag lifecycle in `ReaderViewModel.loadAIContent`: handle `CancellationError` explicitly without setting error text or toast; reset `isAIProcessing = false` synchronously in `onDisappear`; ensure prefetch polling finishes its final state sync.
- Update contract documentation in `docs/contracts/ai-service.md` reflecting single-attempt execution and manual re-processing.

Non-goals: No timeout adjustments, no chunk size changes, and no changes to log presentation screens.

## Acceptance

- [x] Mock 500 → 1 request then throw; 200 → 1 request success.
- [x] Chapter fail → `isAIProcessing==false`, one toast, raw fallback shown, prefetch keeps running separately with its own indicator; onDisappear → flag false immediately.
- [x] Cancel → CancellationError, no aiError/toast.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/functional-specs/chapter-prefetch.md](../docs/product/functional-specs/chapter-prefetch.md)
- [apps/novels/Services/AIClient.swift](../apps/novels/Services/AIClient.swift)
- [apps/novels/Services/AIReadingService.swift](../apps/novels/Services/AIReadingService.swift)
- [apps/novels/Features/Reading/ReaderViewModel.swift](../apps/novels/Features/Reading/ReaderViewModel.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS. Unit tests verified 1-request failure/success, immediate loading flag dismissal on cancellation, and isolated prefetch execution. This behavior was later integrated into the unified prefetch and retry model in [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).
- Blockers: None.
- Next: HISTORICAL: Manual testing on failed chapters verifying spinner dismissal and independent prefetch operation.
