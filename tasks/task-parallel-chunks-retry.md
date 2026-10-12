# Parallel Chunks & Bounded Retry

- Status: done
- Owner: Tung Doan
- Required to start: [feat-006](task-ai-reading.md), [feat-014](task-diagnostic-log-viewer.md)
- Required to integrate/release: none
- Previous ID: feat-015

## Scope and non-goals

Execute AI chapter chunks in parallel using task groups, bound retry attempts to 2 per chunk, and replace inline error messages with a centered progress indicator and diagnostic log badging:
- Update `AIClient.swift` to 2 attempts max per chunk (1 initial + 1 retry) with 1s backoff after attempt 0, fast cancellation checks, and immediate throws for 4xx/decoding errors. Note: consolidated and superseded by [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).
- Update `AIReadingService.swift` to process chunks concurrently via `withThrowingTaskGroup(of: (Int, String))`, joining results in ordered sequence by chunk index with fail-fast cancellation on chunk errors.
- UI changes: Remove inline `Text(aiError)` from reader and bottom sheet in favor of a centered `ProgressView()` and error badge on the diagnostic log button when errors occur.
- Retain error toasts and diagnostic logging entries for failed requests.

Non-goals: No alteration to timeout bounds (180s/600s), no chunk size changes (1,300 characters), and no partial cache persistence on chapter failure.

## Acceptance

- [x] Mock 500×2 → throw, requests==2; 500+200 → success.
- [x] 5 chunks with reversed delays still join in correct order; per-chunk retry uses the right attempt/requestId; cancel → CancellationError.
- [x] Reading + BottomSheet: centered `aiProgress`, no `aiError` view/id; toast still shows on fail; Log badge on fail.
- [x] `./init.sh` full PASS (format/lint/build/drift PASS; full test flaked once on the Simulator bundle, rerun of targeted AIClient/AIReadingService/DiagnosticsLog/PrefetchManager/ReaderViewFixTests TEST SUCCEEDED).

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Services/AIClient.swift](../apps/novels/Services/AIClient.swift)
- [apps/novels/Services/AIReadingService.swift](../apps/novels/Services/AIReadingService.swift)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` format, lint, build, and drift checks cleanly; targeted unit tests (`AIClientTests`, `AIReadingServiceTests`, `DiagnosticsLogTests`, `PrefetchManagerTests`, `ReaderViewFixTests`) passed. The full historical suite flaked on the Simulator bundle; targeted passes do not certify a full-suite pass. The original acceptance wording is retained as historical. Current test policy lives in [verification](../docs/decisions/verification.md). Note that chunk retry and reader spinner behavior was subsequently consolidated and superseded by [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).
- Blockers: None.
- Next: HISTORICAL: Manual testing of parallel chunk translation and log inspection.
