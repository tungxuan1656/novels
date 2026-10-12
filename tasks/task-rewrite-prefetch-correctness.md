# Rewrite & Prefetch Correctness Consolidation

- Status: done
- Owner: Tung Doan
- Required to start: [feat-015](task-parallel-chunks-retry.md), [feat-016](task-manual-retry-loading.md), [feat-017](task-tolerant-ai-response.md)
- Required to integrate/release: none
- Previous ID: feat-018

## Scope and non-goals

Consolidate and finalize the concurrent rewrite and prefetch pipeline, unifying earlier work from [task-parallel-chunks-retry](task-parallel-chunks-retry.md), [task-manual-retry-loading](task-manual-retry-loading.md), and [task-tolerant-ai-response](task-tolerant-ai-response.md):
- Per-chunk retry in `AIClient.swift`: bounded loop of at most 2 attempts per chunk (1 initial + 1 retry) targeted specifically at the failing chunk, keeping stable `requestId` and separate attempt logs.
- Ordered concurrent processing in `AIReadingService.swift`: index-keyed parallel task group joined in order with newline separators; fail-fast aborting the chapter if any chunk fails twice; no partial cache writes.
- Chapter-change trigger in `PrefetchManager.swift` and `ReaderViewModel.swift`: prefetch triggers only on true chapter transitions (navigation buttons, table of contents, mode switch, reprocess); `load(source)` differentiates chapter transitions from returning from the log screen; returning from logs on the same chapter makes zero API requests and preserves terminal status.
- UI indicator consolidation: remove content and bottom sheet loading spinners; place a single compact spinner in the reader header visible only while the active chapter is processing.
- Error flow: handle `CancellationError` cleanly without toasts; chapter failure falls back to raw text with a single error toast; prefetch errors log silently without disrupting active reading.

Non-goals: No changes to timeout thresholds (180s/600s), chunk size thresholds (1,300 chars), or cache key hashing; no additional settings keys.

## Acceptance

- [x] 1 failed chunk → 1 retry on that exact chunk (requests==2 for the failed chunk, ==1 for others), success joins in correct order.
- [x] 1 chunk failing twice → chapter abort, one toast, raw fallback, no partial cache, manual "Xử lý lại" available.
- [x] Chapter change → batchStatus: all-cached means zero API; on miss → sequential per-chapter batches, continue past errors.
- [x] On ch22, entering the "Nhật ký" log and backing out → zero API (no current reload, no prefetch), old status kept.
- [x] Header spinner only while the current chapter rewrites; no spinners in content + bottom-sheet; running prefetch shows no header.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/functional-specs/chapter-prefetch.md](../docs/product/functional-specs/chapter-prefetch.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Services/AIClient.swift](../apps/novels/Services/AIClient.swift)
- [apps/novels/Services/AIReadingService.swift](../apps/novels/Services/AIReadingService.swift)
- [apps/novels/Services/PrefetchManager.swift](../apps/novels/Services/PrefetchManager.swift)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS (format 0, lint 0, build PASS, unit tests passed including `AIClientTests` 12/12, `AIReadingServiceTests` 11/11, `PrefetchManagerTests` 13/13, `ReaderHeaderSpinnerTests` 3/3, and `ReaderViewFixTests` 18/18, drift check PASS). This records the historical consolidation; current behavior is canonical in the linked AI and prefetch specifications.
- Blockers: None.
- Next: HISTORICAL: Manual testing on real device verifying chapter transitions, zero-API log back-navigation, and sequential prefetch.
