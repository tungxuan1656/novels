# Chapter Prefetch

- Status: done
- Owner: Tung Doan
- Required to start: [feat-006](task-ai-reading.md)
- Required to integrate/release: none
- Previous ID: feat-007

## Scope and non-goals

Prefetch next N chapters' AI content sequentially and cancellably after current chapter is ready:
- Eligibility: active mode is not `none` and current chapter finished processing; N = `PREFETCH_COUNT` (default 3, range 1..10, invalid values coerced to 3).
- Batch cache status check for the next N chapters against `processed_chapters.sqlite`; processes only misses sequentially.
- Swift `Task` cancellation on chapter navigation or mode change; runtime-only `PrefetchStatus` (isRunning, total, processed, message, errors) exposed to read-only UI without disk persistence.
- Per-chapter failure appends to `PrefetchStatus.errors` and continues with subsequent chapters; book deletion mid-run cancels pending tasks.
- Note on later evolution: Batch sliding-window prefetch was later overhauled into a durable FIFO queue with continuous forward progress in [task-prefetch-fifo-queue](task-prefetch-fifo-queue.md).

Non-goals: No new AI transport protocol, no cache schema changes, no background task scheduling (`BGTaskScheduler`), and no writable user progress controls.

## Acceptance

- [x] Prefetch runs only when eligible; batch check skips cached chapters.
- [x] Sequential processing of misses in order; cancellation stops remaining work.
- [x] `PrefetchStatus` runtime-only (isRunning/total/processed/message/errors[]) read-only UI, not persisted per `docs/product/domain-model.md:66`.
- [x] Single chapter failure does not abort batch; errors collected in `PrefetchStatus.errors`.
- [x] Book folder deleted during prefetch cancels pending tasks.
- [x] Invalid `PREFETCH_COUNT` coerced to 3.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/product/functional-specs/chapter-prefetch.md](../docs/product/functional-specs/chapter-prefetch.md)
- [docs/product/flows.md](../docs/product/flows.md)
- [docs/product/domain-model.md](../docs/product/domain-model.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [apps/novels/Domain/](../apps/novels/Domain/)
- [apps/novels/Services/](../apps/novels/Services/)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `xcodebuild build` PASS; `swiftlint` 0 violations; `swiftformat` 0/87; `./init.sh` passed with full test suite (PrefetchStatusTests 2, PrefetchManagerTests 7, ReaderPrefetchIntegrationTests 4). Later prefetch queue modifications and status UI refinements route to canonical documentation in `docs/product/functional-specs/chapter-prefetch.md` and [task-prefetch-fifo-queue](task-prefetch-fifo-queue.md).
- Blockers: None.
- Next: HISTORICAL: feat-008 Hardening + Release Readiness ready to activate.
