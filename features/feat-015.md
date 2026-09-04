# feat-015 — Parallel Chunks + Bounded Retry + Loading-Only UI

## Goal

Dịch song song các chunk (join đúng thứ tự, retry per-chunk), tổng 2 attempts/chunk (1 + 1 retry), bỏ error text ở Reading + BottomSheet chỉ giữ spinner căn giữa ngang (giữ toast + badge Log để drill-down).

## Context

- `AIClient.swift:54` đang `0..<3` (1+2); user chốt tổng 2 attempts. Cảm giác "mãi" do prefetch sequential × 180s + `aiTask`/prefetch chồng + `Task.sleep` nuốt cancel.
- `AIReadingService.processChunks` sequential `for (index,chunk)` + fail abort cả chương. Cần `withThrowingTaskGroup` index-keyed, ordered join, fail-fast, unbounded (TODO cap 4 nếu thấy 429).
- `ReaderView.aiSection:122-151` + `ReaderBottomSheet.aiModeSection:138-146` đang hiện `ProgressView("Đang xử lý...")` lệch trái + `Text(aiError)`. Cần spinner thuần căn giữa, xóa error text/identifier, giữ toast.

## Scope

- `Services/AIClient.swift`: loop `0..<2`, `attempt<1` mới continue, backoff 1s sau attempt 0; thêm `Task.checkCancellation()` đầu loop; `try await Task.sleep` (không `try?`) để lan `CancellationError`; giữ 5xx/URLError retry, 4xx/decode/noResponse throw ngay.
- `Services/AIReadingService.swift`: `processChunks` → `withThrowingTaskGroup(of: (Int,String))`, per-child `client.complete` với `AIDiagnosticsContext(chunkIndex:i)` (retry per-chunk tự nhiên), `buffer[index]` ordered join `"\n"`, fail-fast, giữ dedup `inFlight` actor + cache hit/miss/save.
- `Features/Reading/ReaderViewModel.swift`: `onDisappear` thêm `aiTask?.cancel()`; giữ toast error, giữ `aiError` trong VM/log nhưng không bind Text.
- UI loading-only (`@designer`): xóa `Text(aiError)` + id `aiError` ở `ReaderView` + `BottomSheet`; `ProgressView()` không label, `.frame(maxWidth:.infinity)` + `minHeight:120` + `accessibilityIdentifier aiProgress` + `accessibilityLabel "Đang xử lý"`; badge đỏ trên `apiLogButton` khi `DiagnosticsStore` có chunk.fail (tap mở Log filter Lỗi). Giữ toast.
- Tests extend (không file mới): `AIClientTests` (500×2 → throw, count==2; 500+200 → success), `AIReadingServiceTests` (ordering delays ngược vẫn đúng thứ tự; per-chunk retry; cancel → CancellationError), `ReaderViewFixTests` (có aiProgress, không aiError), `DiagnosticsLogTests` (attempt 1..2, requestId stable/chunk).

## Non-goals

- Không đổi timeout 180/600, không đổi chunk split 1300, không cache partial, không cap 4 (TODO sau), không thêm setting, không entry Settings mới.

## Acceptance

- [x] Mock 500×2 → throw, requests==2; 500+200 → success.
- [x] 5 chunks delay ngược vẫn join đúng thứ tự; per-chunk retry đúng attempt/requestId; cancel → CancellationError.
- [x] Reading + BottomSheet: có `aiProgress` centered, không `aiError` view/id; toast vẫn hiện khi fail; badge Log khi có fail.
- [x] `./init.sh` full PASS (format/lint/build/drift PASS; test full flake bundle Simulator 1 lần, rerun targeted AIClient/AIReadingService/DiagnosticsLog/PrefetchManager/ReaderViewFixTests TEST SUCCEEDED).

## Relevant docs

- `docs/plans/feat-015.md`, `docs/contracts/ai-service.md` (retry/chunking cần update 3→2), `features/feat-014.md` (DiagnosticsLog contract).

## Plan

External: `docs/plans/feat-015.md`. Ownership:
- @fixer: `AIClient`, `AIReadingService`, `ReaderViewModel.onDisappear`, tests logic.
- @designer: `ReaderView.aiSection`, `ReaderBottomSheet.aiModeSection`, badge `apiLogButton`.
- Shared: retry 2 attempts + TaskGroup ordered join + loading-only + toast/badge.

## Verify

- `./init.sh` full + targeted suites.

## Handoff (done)

- State: done — fix-3 (retry 2 + TaskGroup + cancel + errorCount + ai-service.md + tests) + des-2 (loading-centered + badge + Router filter) done; `./init.sh` format/lint/build/drift PASS, targeted unit TEST SUCCEEDED.
- Evidence: `AIClient` 0..<2 + checkCancellation, `AIReadingService` TaskGroup ordered join fail-fast, `ReaderViewModel.onDisappear` cancel aiTask, `ReaderView`/`BottomSheet` spinner thuần centered + xóa aiError + badge, `DiagnosticsStore.errorCount`, tests 5 suites PASS.
- Blockers: none (full suite 1 lần flake bundle Simulator, rerun targeted PASS)
- Next: repo idle — user retest dịch song song + mở Nhật ký kiểm tra attempt/requestId.
