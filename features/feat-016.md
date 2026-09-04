# feat-016 — No Auto-Retry + Fix Stuck Loading

## Goal

Remove auto-retry (1 attempt/chunk, fail → manual "Xử lý lại"), fix the stuck chapter spinner after a fail while prefetch is still running.

## Context

- Bug on ch22: the rewrite had stopped after retry, but Reading + Sheet kept loading while prefetch was running. Trace exp-4: `loadAIContent` has `defer=false`, so in theory a fail still clears `isAIProcessing`; the observed spinner was the prefetch spinner (`prefetchStatus.isRunning`, text "Đang tải trước x/y") right below aiSection + a race between fire-and-forget `load()` and `onDisappear` not clearing the flag (waiting up to 180s for cancel) + the poll early-return skipping the final sync + a shared `catch` swallowing CancellationError into aiError/toast.
- User confirmed: drop retry, failed chapters use manual retry.

## Scope (inline)

- `AIClient.complete`: single attempt only (remove loop/backoff/`retry.scheduled`), keep `checkCancellation`, 4xx/5xx/URLError throw right after attempt 1. Keep 180/600 timeout + redaction + diagnostics (attempt always 1).
- `AIReadingService`: keep parallel TaskGroup + fail-fast; 1 attempt per chunk.
- `ReaderViewModel.loadAIContent`: add `catch is CancellationError` (no aiError/toast, only clear the flag via defer); `onDisappear`: `aiTask?.cancel()` + `isAIProcessing=false` synchronously so the sheet never sticks; prefetch poll guarantees the final sync (no early-return skipping the mirror).
- `docs/contracts/ai-service.md`: Retry → No auto-retry (1 attempt, manual reprocess).
- Tests: update `AIClientTests` (1 request then throw/success), `AIReadingServiceTests` (single attempt per chunk, cancel → CancellationError), add a stuck-flag regression (fail → isAIProcessing false while prefetchRunning is true).

## Non-goals

- No change to timeout/chunk split/parallel join, no new settings, no `LogScreen` changes.

## Acceptance

- [x] Mock 500 → 1 request then throw; 200 → 1 request success.
- [x] Chapter fail → `isAIProcessing==false`, one toast, raw fallback shown, prefetch keeps running separately with its own indicator; onDisappear → flag false immediately.
- [x] Cancel → CancellationError, no aiError/toast.
- [x] `./init.sh` full PASS.

## Plan (inline)

1. `AIClient` single-attempt + docs.
2. `ReaderViewModel` cancel/catch/poll-sync.
3. Tests update + regression; `./init.sh --quick` then full.

## Verify

- Targeted: AIClient/AIReadingService/Reader suites + `./init.sh`.

## Handoff (done)

- State: done — single-attempt + dedicated CancellationError catch + onDisappear flag clear + final poll sync + parallel test race fix; `./init.sh` full PASS.
- Evidence: `AIClient` 1 attempt, `ReaderViewModel` cancel/catch/poll, `ai-service.md` no-retry, AIClient/AIReadingService/AIReadingViewModel/DiagnosticsLog/PrefetchManager tests PASS.
- Blockers: none
- Next: repo idle — user retests failed ch22: chapter spinner stops, prefetch runs separately, manual "Xử lý lại".
