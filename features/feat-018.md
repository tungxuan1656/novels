# feat-018 — Rewrite + Prefetch Correctness (consolidating feat-015/016/017)

## Goal

Rewrite + prefetch behavior as the user confirmed on 2026-09-04: parallel chunk batches joined in correct order, 1 retry on the exact failed chunk, sequential prefetch only on a real chapter change, a single header spinner for the current chapter, zero-API back navigation from the "Nhật ký" log.

## Context

- feat-015/016/017 overlap on the same problem (parallelism + retry + stuck spinner + odd 200 decode), currently uncommitted but marked done. Freeze those 3 features as archived and consolidate all correct behavior into feat-018 alone. No new feature per small fix anymore.
- Root bug: entering the "Nhật ký" log and backing to Reading ch22 retried prefetch even though it had previously stopped on error; spinners in content + bottom-sheet confused the current chapter with prefetch.

## Scope

- `Services/AIClient.swift`: loop of max 2 attempts/chunk (all error kinds, exact failed chunk, same requestId, separate attempt 1/2 logs, `Task.checkCancellation`).
- `Services/AIReadingService.swift`: keep index-keyed parallel TaskGroup with ordered `"\n"` join, fail-fast with 1 chunk aborting the chapter after 2 attempts, no partial caching.
- `Services/PrefetchManager.swift` + `Features/Reading/ReaderViewModel.swift`: trigger prefetch only on a real chapterNumber change (goNext/goPrev/goToChapter/References/mode switch/reprocess); `load(source)` distinguishes chapterChange vs return-from-Log; back from Log on the same chapter → zero API, terminal status kept; batchStatus all-cached → zero calls; on miss → sequential per-chapter batches, skip on error + `errors[]` + `prefetch.error-continue`; 2 reload paths (next-chapter auto-check, manual "Xử lý lại" outside the window).
- `Features/Reading/ReaderView.swift`: remove the `aiSection` spinner + `prefetchIndicator` from content; row 2 of the header adds a 12px spinner left of the prev/next capsule, visible only while the current chapter has `isAIProcessing`.
- `Features/Reading/ReaderBottomSheet.swift`: remove the loading indicator entirely; keep picker + "Xử lý lại" + "Nhật ký" button (error badge).
- Errors: dedicated `CancellationError` (clear flag, no toast); chapter fail shows one toast + raw fallback; prefetch fail is silent (badge + Log).
- Docs (updated before code in this brainstorm): `docs/contracts/ai-service.md`, `docs/product/functional-specs/ai-reading.md`, `docs/product/functional-specs/chapter-prefetch.md`, `docs/design/screens.md`.
- Extend tests (no new files unless needed): per-chunk retry on the right chunk, correct-order join under reversed delays, back-from-Log zero-API, header spinner for current only, prefetch sequential-skip.

## Non-goals

- No change to the 180/600 timeout, 1300 chunk hint, cache key, localhost-only ATS, or existing Log shape fields.
- No new settings, no `{data:...}` envelope treated as success, no raw logging.
- No refactoring outside rewrite/prefetch/header scope.

## Acceptance

- [x] 1 failed chunk → 1 retry on that exact chunk (requests==2 for the failed chunk, ==1 for others), success joins in correct order.
- [x] 1 chunk failing twice → chapter abort, one toast, raw fallback, no partial cache, manual "Xử lý lại" available.
- [x] Chapter change → batchStatus: all-cached means zero API; on miss → sequential per-chapter batches, continue past errors.
- [x] On ch22, entering the "Nhật ký" log and backing out → zero API (no current reload, no prefetch), old status kept.
- [x] Header spinner only while the current chapter rewrites; no spinners in content + bottom-sheet; running prefetch shows no header.
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/contracts/ai-service.md` (Chunking + bounded per-chunk Retry)
- `docs/product/functional-specs/ai-reading.md` (batch join + manual retry)
- `docs/product/functional-specs/chapter-prefetch.md` (chapter-change trigger + sequential + back-zero-API)
- `docs/design/screens.md` (header-only Loading)
- `features/feat-015.md`, `features/feat-016.md`, `features/feat-017.md` (archived, do not edit further)

## Plan

External: `docs/plans/feat-018.md`. Ownership:
- @fixer: `AIClient`, `AIReadingService`, `PrefetchManager`, `ReaderViewModel`, logic tests.
- @designer: `ReaderView` header spinner + content-indicator removal, `ReaderBottomSheet` spinner removal.
- Shared: trigger source + zero-API + toast/raw-fallback.

## Verify

- `./init.sh` full (format + lint + build + test + drift).

## Handoff

- State: done — fix-1 (Tasks 1-3: AIClient 2 attempts with stable requestId + TaskGroup join verify + LoadSource zero-API + stale a11y fix) + des-1 (Tasks 4-5: header aiProgressHeader + content/sheet spinner removal) + Task 6 full verify done 2026-09-04.
- Evidence: `./init.sh` full PASS (format 0/lint 0/build PASS/test ** TEST SUCCEEDED ** incl. AIClientTests 12/12, AIReadingServiceTests 11/11, Prefetch 7/7+6/6, ReaderHeaderSpinnerTests 3/3, ReaderViewFixTests 18/18/drift PASS); plan `docs/plans/feat-018.md`.
- Blockers: none (working tree still holds the combined uncommitted feat-015/016/017 + feat-018 — not committed because the user has not asked for it).
- Next: repo idle — user retests on a real device: failed ch22 → toast + raw + header off; entering the "Nhật ký" log and backing out is zero-API; chapter change prefetches sequentially.
- Follow-up 2026-09-04: header adds a "Đang xử lý" text (caption, muted) right of the spinner in the same height-28 HStack — quick PASS + HeaderSpinner/ViewFix 22/22 + A11y/Regression PASS.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
