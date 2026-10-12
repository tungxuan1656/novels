# Chapter-Run Log Grouping & Raw JSON View

- Status: done
- Owner: Tung Doan
- Required to start: [feat-014](task-diagnostic-log-viewer.md), [feat-018](task-rewrite-prefetch-correctness.md)
- Required to integrate/release: none
- Previous ID: feat-019

## Scope and non-goals

Group diagnostic log entries into discrete chapter runs and provide an in-app raw JSON viewer for request and response payloads:
- Grouping model: replace the flat timeline from [task-diagnostic-log-viewer](task-diagnostic-log-viewer.md) with chapter-run grouping where each row represents one chapter attempt (`runId: UUID`), displaying status pills ("Thành công", "Thất bại", "Đang xử lý") and chunk counts. Manual re-processing produces a new distinct row rather than mutating prior runs.
- Payload inspection: capture outgoing request bodies and returned response bodies in memory (`LogEntry`), allowing developers to inspect full raw JSON in a bottom sheet modal. Full URLs are captured in `host`.
- Privacy and security: keep bodies strictly in memory (ring buffer only, no disk persistence, no OSLog emission); avoid logging authorization secrets or sensitive headers, adhering to `SECURITY.md`. Note: additional log UI corrections were subsequently applied in [task-log-viewer-correctness](task-log-viewer-correctness.md).
- Search and filtering: replace kind chips and segmented toggles with a focused search bar querying chapter numbers, statuses, and event descriptions.

Non-goals: No persisted logging to SQLite or filesystem; no JSON copy/share export utilities; no syntax highlighting; no changes to prefetch or retry algorithms.

## Acceptance

- [x] Failed rewrite of ch20 → ch20 row with "Thất bại" badge; inside shows the exact failed chunk/API + attempts 1/2.
- [x] Manual "Xử lý lại" on ch20 → separate new row, not merged with the old row.
- [x] Prefetch of 21,22,23 → 3 separate rows (1 row per chapter-run).
- [x] API detail opens a bottom sheet showing the full raw request + response JSON.
- [x] No more book/chapter filters, chips, segmentation; search no longer matches requestId/host/error codes.
- [x] No entry persists raw content to disk/OSLog (`debugSummary` has no raw content).
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/decisions/diagnostic-log-viewer.md](../docs/decisions/diagnostic-log-viewer.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [SECURITY.md](../SECURITY.md)
- [apps/novels/Domain/DiagnosticsEntry.swift](../apps/novels/Domain/DiagnosticsEntry.swift)
- [apps/novels/Services/DiagnosticsLog.swift](../apps/novels/Services/DiagnosticsLog.swift)
- [apps/novels/Features/Diagnostics/LogScreen.swift](../apps/novels/Features/Diagnostics/LogScreen.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, unit tests (including `LogScreenGroupingTests` 11/11 and `AIClientTests` payload tests), and drift checks. Superseded flat-timeline behavior is documented in `docs/decisions/diagnostic-log-viewer.md`. Further UI refinements occurred in [task-log-viewer-correctness](task-log-viewer-correctness.md).
- Blockers: None.
- Next: HISTORICAL: Manual verification of chapter-run rows, error expansion, and raw JSON presentation.
