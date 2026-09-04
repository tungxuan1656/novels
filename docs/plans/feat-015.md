# Plan — feat-015 Parallel Chunks + Bounded Retry + Loading-Only UI

> Separate (>=4 files + behavior change). Feature: `features/feat-015.md`.

## 1. Retry 2 attempts (user chốt, khác oracle 1+2)

- `AIClient.complete`: `for attempt in 0..<2`, `if attempt < 1 { sleep(1s); continue }` (bỏ backoff 2s). Giữ retry chỉ 5xx/URLError; 4xx/decode/noResponse throw ngay.
- Thêm `try Task.checkCancellation()` đầu mỗi iteration; `Task.sleep` dùng `try await` (không `try?`) để `CancellationError` lan ra, không wrap thành `noResponse`.
- Update `docs/contracts/ai-service.md` Retry: 2 attempts (1 + 1 retry, backoff 1s).
- Tests: `AIClientTests` — 500×2 → throw count==2; 500+200 → success; 500×3 mock → count==2.

## 2. Parallel chunks (unbounded TaskGroup)

- `AIReadingService.processChunks`: thay `for (index,chunk)` sequential bằng `withThrowingTaskGroup(of: (Int,String).self)`; mỗi child `client.complete(prompt:chunk:context: chunkIndex=i)` (retry per-chunk tự nhiên trong client); `buffer:[String?]` join `"\n"` theo index; fail-fast (1 chunk fail → throw, không cache partial); giữ dedup `inFlight` actor.
- `ReaderViewModel.onDisappear`: thêm `aiTask?.cancel()`.
- Diagnostics: `requestId` stable/chunk, `attempt` 1..2, giữ `chunk.start/success/fail` + `retry.scheduled`.
- TODO: cap 4 nếu thấy 429 trong Log (không làm lần này).

## 3. Loading-only UI + badge

- Xóa `Text(aiError)` + id `aiError` ở `ReaderView.aiSection` + `BottomSheet.aiModeSection`; sửa fallback chỉ check `isAIProcessing`.
- `ProgressView()` không label, `.frame(maxWidth:.infinity)` + `minHeight:120` + `accessibilityIdentifier aiProgress` + `accessibilityLabel "Đang xử lý"`.
- Badge: `DiagnosticsStore.errorCount` (chunk.fail/errorCode) → chấm đỏ trên `apiLogButton`; tap mở Log filter Lỗi. Giữ toast error.
- Tests UI: có `aiProgress`, không `aiError`.

## 4. Ownership

- @fixer: `AIClient`, `AIReadingService`, `ReaderViewModel`, `ai-service.md`, tests logic.
- @designer: `ReaderView`, `ReaderBottomSheet`, badge.
- Không overlap. Shared contract §1-§3.
