# feat-019 — Chapter-Run Log + Raw JSON View

## Goal

The "Nhật ký" log groups 1 row = 1 chapter × 1 run with a clear status ("Thành công"/"Thất bại"/"Đang xử lý"); tapping in shows all inner events + retries; API detail shows the full raw JSON (request + response) in a bottom sheet.

## Context

- The current log is a flat per-entry timeline + book/chapter filter + "Tất cả"/"Sự kiện"/API/"Lỗi" chips + "Dòng thời gian"/"Theo chương" toggle; search covers requestId/host/error codes. When a chapter fails, the user cannot tell which chunk/API failed.
- A manual retry of the same chapter must become a new row (separate runs), never merged together.
- Old constraint (ADR `diagnostic-log-viewer.md`): no raw bodies. feat-019 relaxes exactly 1 point: raw JSON stays **in RAM** (entry ring buffer, no persistence, no OSLog), shown only in-app; headers are no longer shown in the UI, so no secrets leak.

## Scope

- `Domain/DiagnosticsEntry.swift`: `LogEntry` adds 3 defaulted source-compatible fields: `runId: UUID? = nil`, `requestBody: String? = nil`, `responseBody: String? = nil`. `AIDiagnosticsContext` adds `runId: UUID? = nil`. `debugSummary` unchanged (no raw content).
- `Services/AIClient.swift`: capture `requestBody` (outgoing JSON as string) + `responseBody` (returned data as UTF-8 string) into every API entry (success + all fail branches). `host` records the full URL instead of the redacted display.
- `Services/AIReadingService.swift`: `processedContent`/`reprocess` add a `runId: UUID? = nil` param (`let run = runId ?? UUID()`); every log for that call (cache hit/miss/save, chunk start/success/fail, context passed to client) uses `run`.
- `Services/PrefetchManager.swift`: each chapter in the loop creates `runId = UUID()`; passes it to `processedContent(..., runId:)`; that chapter's `prefetch.error-continue` logs (missing/empty/aiError) carry the same `runId`.
- `Features/Diagnostics/LogScreen.swift` (@designer): remove book/chapter filters, kind chips, group toggle; keep the search box, matching only chapter number/status/event/detail (not requestId/host/error codes). List groups by `runId` DESC by newest time: row "Rewrite · Ch 20" + status badge + chunk count; tapping expands events (keeps `LogRowView` for inner entries incl. retry attempts); tapping an API event opens a JSON bottom sheet (request + response, mono, scrollable, using `BottomSheetView`).
- UI removals: headers block, Model line. `Router.apiLog(bookId:initialFilter:)` keeps its signature; `initialFilter == .error` pre-expands failed groups.
- Tests: runId separates 2 runs of the same chapter; retry shares the run; full bodies; full-URL host; grouping/status; narrowed search; new UI identifiers.

## Non-goals

- No log persistence (SQLite/file) — keep the spirit of `local-persistence.md`.
- No JSON copy/share, no syntax highlight.
- No retry/chunk/prefetch logic changes, no new settings.

## Acceptance

- [x] Failed rewrite of ch20 → ch20 row with "Thất bại" badge; inside shows the exact failed chunk/API + attempts 1/2.
- [x] Manual "Xử lý lại" on ch20 → separate new row, not merged with the old row.
- [x] Prefetch of 21,22,23 → 3 separate rows (1 row per chapter-run).
- [x] API detail opens a bottom sheet showing the full raw request + response JSON.
- [x] No more book/chapter filters, chips, segmentation; search no longer matches requestId/host/error codes.
- [x] No entry persists raw content to disk/OSLog (`debugSummary` has no raw content).
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/decisions/diagnostic-log-viewer.md` (Amendment feat-019)
- `docs/contracts/ai-service.md` (RAM-only body note)
- `docs/design/screens.md` (new Log row)
- `docs/plans/feat-014.md` (original ownership: @fixer logic / @designer UI — unchanged)

## Plan (inline)

1. @fixer (data): entry fields + context runId + AIClient capture + full-URL host + service/prefetch runId threading + logic tests; `./init.sh --quick` + targeted suites.
2. @designer (UI, after 1): LogScreen regroup + JSON bottom sheet + filter removal + UI tests; `./init.sh --quick` + targeted.
3. Orchestrator: `./init.sh` full + close feature.

## Verify

- `./init.sh` full (format + lint + build + test + drift).

## Handoff

- State: done — @fixer data (runId threading + RAM-only bodies + full-URL host, 47/47 targeted) + @designer UI (runId regroup + JSON bottom sheet + filter removal, quick + targeted PASS) + full `./init.sh` PASS 2026-09-04.
- Evidence: `LogRunBuilder`/`LogRunGroup` + `LogScreenGroupingTests` 11/11; `AIClientTests` body tests; full suite ** TEST SUCCEEDED ** + drift PASS.
- Blockers: none (tree uncommitted — not committed because it was not requested).
- Next: repo idle — user retests the "Nhật ký" log screen: chapter-run rows + status badges, expand for retries, "Xem JSON thô".

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
