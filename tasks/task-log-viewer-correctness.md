# Log Viewer Correctness & Realtime Updates

- Status: done
- Owner: Tung Doan
- Required to start: [feat-019](task-chapter-run-json-log.md), [feat-023](task-reader-prefetch-guards.md)
- Required to integrate/release: none
- Previous ID: feat-025

## Scope and non-goals

Refine diagnostic log viewing with disambiguated run titles, real-time update streaming, intra-group filtering, and accurate run status resolution:
- Disambiguated titles and run status: origin title differentiates runs using source suffixes (`"API done/total"`, `"Cache"`, `"Dùng chung"`); status resolution prioritizes strictly newer terminal success over prior failures, resolving ties as failed; muted cancels and skips are handled cleanly.
- Real-time updates: `DiagnosticsLog` provides an `AsyncStream` yielding updates with generational tokens; `DiagnosticsStore.observe()` debounces updates by 250ms on the `MainActor` and cancels subscriptions on screen exit; `.refreshable` pull-to-refresh modifier wired to the view.
- Filtering and detail view: intra-group filtering shows only matching events during search; auto-expansion for matching or failed groups (`initialFilter = .error`); JSON presentation sheet gates strictly on `body != nil`, preventing empty bottom sheets.
- Shared domain predicates: unify `isError`, `isMutedCancel`, and `cancelReason` on `LogEntry` with injectable timestamps for deterministic testing.

Non-goals: No expansion of the 500-entry in-memory ring buffer; no disk or database persistence of log entries; no 1s polling loops; no complex syntax highlighting.

## Acceptance

- [x] Opening from a book shows only that book's logs; `initialFilter=.error` auto-expands failed groups.
- [x] No two identical titles: `"Rewrite · Ch 455 · API 3/5"` vs `"Rewrite · Ch 455 · Cache"`.
- [x] New entries appear while staying on screen (debounced); pull-to-refresh works; leaving the screen ends observation (no zombie task).
- [x] Old fail + later retry success reads `"Thành công"`; tied timestamps read failed.
- [x] Search expands only matching groups and shows only matching entries inside.
- [x] JSON opens from any entry with a body, bounds kept, never an empty sheet.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/decisions/diagnostic-log-viewer.md](../docs/decisions/diagnostic-log-viewer.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [SECURITY.md](../SECURITY.md)
- [apps/novels/Features/Diagnostics/LogScreen.swift](../apps/novels/Features/Diagnostics/LogScreen.swift)
- [apps/novels/Services/DiagnosticsLog.swift](../apps/novels/Services/DiagnosticsLog.swift)
- [apps/novels/Domain/DiagnosticsEntry.swift](../apps/novels/Domain/DiagnosticsEntry.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, unit tests (`LogScreenGroupingTests` and `DiagnosticsLogTests` updating titles, realtime streaming, and status resolution), and drift checks. Superseded earlier flat and unsynced log behavior from [task-diagnostic-log-viewer](task-diagnostic-log-viewer.md).
- Blockers: None.
- Next: HISTORICAL: Manual verification of log presentation during live chapter streaming, pull-to-refresh, and intra-group searching.
