# feat-016 — No Auto-Retry + Fix Stuck Loading

## Goal

Bỏ auto-retry (1 attempt/chunk, fail → manual "Xử lý lại"), fix kẹt spinner chapter sau fail khi prefetch vẫn chạy.

## Context

- Bug ch22: rewrite lỗi đã dừng sau retry nhưng Reading + Sheet vẫn loading trong khi prefetch chạy. Trace exp-4: `loadAIContent` có `defer=false` nên fail vẫn clear `isAIProcessing` về lý thuyết; quan sát được = spinner prefetch (`prefetchStatus.isRunning`, text "Đang tải trước x/y") nằm ngay dưới aiSection + race `load()` fire-and-forget vs `onDisappear` không clear flag (chờ cancel tới 180s) + poll early-return bỏ sync cuối + `catch` chung nuốt CancellationError thành aiError/toast.
- User chốt: bỏ retry, chapter lỗi manual retry.

## Scope (inline)

- `AIClient.complete`: 1 attempt duy nhất (xóa loop/backoff/`retry.scheduled`), giữ `checkCancellation`, 4xx/5xx/URLError throw ngay sau attempt 1. Giữ timeout 180/600 + redaction + diagnostics (attempt luôn 1).
- `AIReadingService`: giữ TaskGroup song song + fail-fast; per-chunk 1 attempt.
- `ReaderViewModel.loadAIContent`: thêm `catch is CancellationError` (không set aiError/toast, chỉ clear flag qua defer); `onDisappear`: `aiTask?.cancel()` + `isAIProcessing=false` đồng bộ để sheet không kẹt; poll prefetch đảm bảo sync cuối (không early-return bỏ mirror).
- `docs/contracts/ai-service.md`: Retry → No auto-retry (1 attempt, manual reprocess).
- Tests: update `AIClientTests` (1 request rồi throw/success), `AIReadingServiceTests` (per-chunk single attempt, cancel → CancellationError), thêm regression kẹt flag (fail → isAIProcessing false trong khi prefetchRunning true).

## Non-goals

- Không đổi timeout/chunk split/parallel join, không thêm setting, không sửa LogScreen.

## Acceptance

- [x] Mock 500 → 1 request rồi throw; 200 → 1 request success.
- [x] Chapter fail → `isAIProcessing==false`, toast 1 lần, raw fallback hiện, prefetch vẫn chạy riêng với indicator của nó; onDisappear → flag false ngay.
- [x] Cancel → CancellationError, không aiError/toast.
- [x] `./init.sh` full PASS.

## Plan (inline)

1. `AIClient` single-attempt + docs.
2. `ReaderViewModel` cancel/catch/poll-sync.
3. Tests update + regression; `./init.sh --quick` rồi full.

## Verify

- Targeted: AIClient/AIReadingService/Reader suites + `./init.sh`.

## Handoff (done)

- State: done — single-attempt + catch CancellationError riêng + onDisappear clear flag + poll sync cuối + fix parallel test race; `./init.sh` full PASS.
- Evidence: `AIClient` 1 attempt, `ReaderViewModel` cancel/catch/poll, `ai-service.md` no-retry, tests AIClient/AIReadingService/AIReadingViewModel/DiagnosticsLog/PrefetchManager PASS.
- Blockers: none
- Next: repo idle — user retest ch22 fail: spinner chapter tắt, prefetch chạy riêng, manual "Xử lý lại".
