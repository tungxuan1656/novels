# Reader & Prefetch Correctness Round 2

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-005](task-settings-cache-manager.md), [feat-006](task-ai-reading.md), [feat-007](task-chapter-prefetch.md), [feat-014](task-diagnostic-log-viewer.md), [feat-018](task-rewrite-prefetch-correctness.md)
- Required to integrate/release: none
- Previous ID: feat-023

## Scope and non-goals

Harden reader and prefetch behavior against stale chapter content, inaccurate prefetch counts, misleading log badges, and sliding-window chapter drops:
- Reader state protection: generation-guarded AI writes, cancellation on `setAIMode`, epoch-guarded status polling, and navigation debounce in `ReaderViewModel.swift`. Identity-gated AI views in `ReaderView.swift`.
- Prefetch resilience: log-only effective prefetch count tracking, bounded in-batch retries, failed-first retry ordering, overlap-preserving window top-up, and an end-of-book state message. Note: the hard cap, polling mechanism, and trigger debounce introduced here were subsequently superseded by the FIFO queue architecture in [task-prefetch-fifo-queue](task-prefetch-fifo-queue.md).
- Cache safety: chunked `batchStatus` queries in `ProcessedChapterCache.swift` ensuring database query errors never mistakenly trigger mass-refetches.
- Diagnostic log contracts: success badges for cache hits and shared in-flight runs; muted cancel statuses avoiding misleading error indicators.
- Settings transparency: effective prefetch count display reflecting configured clamping rules (`0...1000` clamping).

Non-goals: No architectural FIFO queue or event-driven streaming status at this stage (addressed in follow-up); no cache schema migration; no change to core timeout or budget limits.

## Acceptance

- [x] ch450 + rewrite, prefetch 451 done, open Log, back → ch450 content stays ch450; rapid next/prev x5 → content always matches header; mode switch mid-spinner → no ghost content (`ReaderStaleGuardTests` 4/4 + generation/epoch guards).
- [x] `" 20"` saves as 20; invalid input message matches block behavior; Log `batchCheck` shows `effectiveN=20` (trim rule + effective row + storedN/effectiveN log).
- [x] Cache-hit group badges Success; cancel-on-navigate never red; Log peek + return resyncs status (badge contract + epoch-guarded poll + resync/resume tests).
- [x] Reported walk 450→451→450→451 shows continuous forward progress, no silent skip; transient failure retried once; steady reading ≈ 1 tail fetch per next (bounded retry + overlap top-up + debounce).
- [x] N=1000 behaves capped with honest message; query failure never mass-refetches; end-of-book message distinct (hardCap 10 + chunked batchStatus + keep-state).
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/functional-specs/chapter-prefetch.md](../docs/product/functional-specs/chapter-prefetch.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/product/flows.md](../docs/product/flows.md)
- [apps/novels/Services/PrefetchManager.swift](../apps/novels/Services/PrefetchManager.swift)
- [apps/novels/Features/Reading/ReaderViewModel.swift](../apps/novels/Features/Reading/ReaderViewModel.swift)
- [apps/novels/Persistence/ProcessedChapterCache.swift](../apps/novels/Persistence/ProcessedChapterCache.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS (format 0/98, lint 0/98, build PASS, unit tests passed including `ReaderStaleGuardTests` 4/4, `LogScreenGroupingTests`, and integration tests, drift PASS). The recorded full run passed after a Simulator/test retry. Hardcap, polling, and debounce mechanisms were subsequently replaced by an in-memory FIFO queue with one-shot reader status resync in [task-prefetch-fifo-queue](task-prefetch-fifo-queue.md).
- Blockers: None.
- Next: HISTORICAL: Manual verification of chapter transitions and prefetch count logging across extended reading sessions.

## Deferred Proposals — Not Approved Work

The FIFO queue proposal was subsequently delivered in [prefetch FIFO](task-prefetch-fifo-queue.md).
Event-driven status publication and prompt/source-hash cache invalidation remained parked pending owner sign-off.
The historical hash-migration proposal (`user_version` 1->2 with source/prompt hash columns) is not the implemented version-2 clear described in [local data](../docs/contracts/local-data.md); do not execute it from this history.
Outer-chapter concurrency was rejected unless measured `current+1` hit rate demonstrates the sequential model is insufficient (data, battery and ordering costs).
Parked review items: reader M1/M4, settings/log 11-14 and prefetch log spam. Detailed old review/plan evidence remains in Git history.
