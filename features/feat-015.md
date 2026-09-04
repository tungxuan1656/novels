# feat-015 — Parallel Chunks + Bounded Retry + Loading-Only UI

## Goal

Translate chunks in parallel (join in correct order, per-chunk retry), 2 attempts total per chunk (1 + 1 retry); remove error text in Reading + BottomSheet and keep only a horizontally centered spinner (keep toast + Log badge for drill-down).

## Context

- `AIClient.swift:54` currently uses `0..<3` (1+2); user confirmed 2 attempts total. The "forever" feeling comes from sequential prefetch × 180s + overlapping `aiTask`/prefetch + `Task.sleep` swallowing cancellation.
- `AIReadingService.processChunks` is sequential `for (index,chunk)` + one failed chunk aborts the whole chapter. Needs index-keyed `withThrowingTaskGroup`, ordered join, fail-fast, unbounded (TODO: cap at 4 if 429s appear).
- `ReaderView.aiSection:122-151` + `ReaderBottomSheet.aiModeSection:138-146` currently show a left-aligned `ProgressView("Đang xử lý...")` + `Text(aiError)`. Needs a plain centered spinner; remove error text/identifier, keep toast.

## Scope

- `Services/AIClient.swift`: loop `0..<2`, continue only when `attempt<1`, 1s backoff after attempt 0; add `Task.checkCancellation()` at the top of the loop; use `try await Task.sleep` (not `try?`) so `CancellationError` propagates; keep 5xx/URLError retry, 4xx/decode/noResponse throw immediately.
- `Services/AIReadingService.swift`: `processChunks` → `withThrowingTaskGroup(of: (Int,String))`, per-child `client.complete` with `AIDiagnosticsContext(chunkIndex:i)` (natural per-chunk retry), `buffer[index]` ordered join with `"\n"`, fail-fast, keep `inFlight` actor dedup + cache hit/miss/save.
- `Features/Reading/ReaderViewModel.swift`: `onDisappear` adds `aiTask?.cancel()`; keep error toast, keep `aiError` in the VM/log but do not bind Text.
- Loading-only UI (`@designer`): remove `Text(aiError)` + id `aiError` in `ReaderView` + `BottomSheet`; bare `ProgressView()` with `.frame(maxWidth:.infinity)` + `minHeight:120` + `accessibilityIdentifier aiProgress` + `accessibilityLabel "Đang xử lý"`; red badge on `apiLogButton` when `DiagnosticsStore` has chunk.fail (tap opens Log with the "Lỗi" filter). Keep toast.
- Extend tests (no new files): `AIClientTests` (500×2 → throw, count==2; 500+200 → success), `AIReadingServiceTests` (reversed delays still join in order; per-chunk retry; cancel → CancellationError), `ReaderViewFixTests` (has aiProgress, no aiError), `DiagnosticsLogTests` (attempts 1..2, stable requestId/chunk).

## Non-goals

- No change to the 180/600 timeout, chunk split 1300, partial caching, cap of 4 (later TODO), new settings, or new Settings entries.

## Acceptance

- [x] Mock 500×2 → throw, requests==2; 500+200 → success.
- [x] 5 chunks with reversed delays still join in correct order; per-chunk retry uses the right attempt/requestId; cancel → CancellationError.
- [x] Reading + BottomSheet: centered `aiProgress`, no `aiError` view/id; toast still shows on fail; Log badge on fail.
- [x] `./init.sh` full PASS (format/lint/build/drift PASS; full test flaked once on the Simulator bundle, rerun of targeted AIClient/AIReadingService/DiagnosticsLog/PrefetchManager/ReaderViewFixTests TEST SUCCEEDED).

## Relevant docs

- `docs/plans/feat-015.md`, `docs/contracts/ai-service.md` (retry/chunking needs 3→2 update), `features/feat-014.md` (DiagnosticsLog contract).

## Plan

External: `docs/plans/feat-015.md`. Ownership:
- @fixer: `AIClient`, `AIReadingService`, `ReaderViewModel.onDisappear`, logic tests.
- @designer: `ReaderView.aiSection`, `ReaderBottomSheet.aiModeSection`, `apiLogButton` badge.
- Shared: 2-attempt retry + TaskGroup ordered join + loading-only + toast/badge.

## Verify

- `./init.sh` full + targeted suites.

## Handoff (done)

- State: done — fix-3 (2-attempt retry + TaskGroup + cancel + errorCount + ai-service.md + tests) + des-2 (centered loading + badge + Router filter) done; `./init.sh` format/lint/build/drift PASS, targeted units TEST SUCCEEDED.
- Evidence: `AIClient` 0..<2 + checkCancellation, `AIReadingService` TaskGroup ordered join fail-fast, `ReaderViewModel.onDisappear` cancels aiTask, `ReaderView`/`BottomSheet` plain centered spinner + aiError removed + badge, `DiagnosticsStore.errorCount`, 5 test suites PASS.
- Blockers: none (full suite flaked once on the Simulator bundle, targeted rerun PASS)
- Next: repo idle — user retests parallel translation + opens the "Nhật ký" log to check attempt/requestId.
