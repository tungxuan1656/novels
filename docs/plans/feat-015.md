# Plan — feat-015 Parallel Chunks + Bounded Retry + Loading-Only UI

> Separate (>=4 files + behavior change). Feature: `features/feat-015.md`.

## 1. Retry 2 attempts (user-confirmed, differs from oracle 1+2)

- `AIClient.complete`: `for attempt in 0..<2`, `if attempt < 1 { sleep(1s); continue }` (drop the 2s backoff). Keep retry for 5xx/URLError only; throw 4xx/decode/noResponse immediately.
- Add `try Task.checkCancellation()` at the start of each iteration; use `try await` (not `try?`) for `Task.sleep` so `CancellationError` propagates instead of being wrapped as `noResponse`.
- Update `docs/contracts/ai-service.md` Retry: 2 attempts (1 + 1 retry, backoff 1s).
- Tests: `AIClientTests` — 500×2 → throw count==2; 500+200 → success; 500×3 mock → count==2.

## 2. Parallel chunks (unbounded TaskGroup)

- `AIReadingService.processChunks`: replace the sequential `for (index,chunk)` with `withThrowingTaskGroup(of: (Int,String).self)`; each child calls `client.complete(prompt:chunk:context: chunkIndex=i)` (natural per-chunk retry inside the client); join the `buffer:[String?]` with `"\n"` by index; fail-fast (1 chunk failure → throw, no partial caching); keep the `inFlight` actor dedup.
- `ReaderViewModel.onDisappear`: add `aiTask?.cancel()`.
- Diagnostics: stable `requestId`/chunk, `attempt` 1..2, keep `chunk.start/success/fail` + `retry.scheduled`.
- TODO: cap at 4 if 429s appear in the Log (out of scope this time).

## 3. Loading-only UI + badge

- Remove `Text(aiError)` + id `aiError` in `ReaderView.aiSection` + `BottomSheet.aiModeSection`; change the fallback to only check `isAIProcessing`.
- `ProgressView()` without label, `.frame(maxWidth:.infinity)` + `minHeight:120` + `accessibilityIdentifier aiProgress` + `accessibilityLabel "Đang xử lý"`.
- Badge: `DiagnosticsStore.errorCount` (chunk.fail/errorCode) → red dot on `apiLogButton`; tap opens the Log with the Error filter. Keep the error toast.
- UI tests: has `aiProgress`, no `aiError`.

## 4. Ownership

- @fixer: `AIClient`, `AIReadingService`, `ReaderViewModel`, `ai-service.md`, tests logic.
- @designer: `ReaderView`, `ReaderBottomSheet`, badge.
- No overlap. Shared contract §1-§3.
