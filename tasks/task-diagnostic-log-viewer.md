# Diagnostic Log Viewer (In-Session Timeline)

- Status: done
- Owner: Tung Doan
- Required to start: [feat-006](task-ai-reading.md), [feat-007](task-chapter-prefetch.md), [feat-011](task-ai-prompt-rewrite.md)
- Required to integrate/release: none
- Previous ID: feat-014

## Scope and non-goals

Provide an in-memory, session-only diagnostic log viewer accessible from the reader bottom sheet to inspect API requests, retries, chunk progress, prefetch events, and cache operations:
- Memory-only ring buffer: `actor DiagnosticsLog` storing up to 500 entries FIFO, cleared on application launch, paired with `os.Logger(subsystem: com.tungxuan.novels.diagnostics, privacy: .private)` emission.
- Domain entry: `LogEntry` with structured metadata (timestamps, request/session IDs, event kind, book/chapter IDs, chunk indices, latency, status codes, and error codes). Note: flat timeline filtering and structured logging were later refined in [task-chapter-run-json-log](task-chapter-run-json-log.md) and [task-log-viewer-correctness](task-log-viewer-correctness.md); canonical security policies in `SECURITY.md` remain authoritative.
- Redaction and privacy: Strict redaction of secrets (`Authorization`, `Cookie`), no raw prompt leakage, and snippet capping (100–200 characters) gated behind `DIAGNOSTICS_VERBOSE`.
- Timeout configuration: Hardcoded 180s request timeout and 600s resource timeout on `URLSessionConfiguration` with `waitsForConnectivity = true`.
- User interface: `LogScreen` timeline with event filter, search, chapter grouping, and expandable detail rows. "Nhật ký" button in reader bottom sheet wired to `Router.Route.apiLog(bookId:)`.

Non-goals: No persisted logging (SQLite or disk files), no raw secret or full prompt exposure, and no custom timeout settings UI.

## Acceptance

- [x] Bottom sheet has a "Nhật ký" button pushing to `LogScreen`; back returns to Reading.
- [x] `LogScreen` lists ≤500 entries DESC; has common + API/event fields per plan §1.
- [x] No entry contains a literal auth value (always `<redacted>`); no raw prompt; snippets ≤100-200 chars only when verbose.
- [x] `DIAGNOSTICS_VERBOSE` defaults to false; snippets/host+path only when enabled.
- [x] Kind/book/chapter/search filter + group toggle work; tap expands detail.
- [x] Relaunch → empty log; timeout config 180/600 + waitsForConnectivity; prefetch budget markers present.
- [x] Redaction/ring-buffer/filter tests PASS; `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/decisions/diagnostic-log-viewer.md](../docs/decisions/diagnostic-log-viewer.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/functional-specs/chapter-prefetch.md](../docs/product/functional-specs/chapter-prefetch.md)
- [docs/design/navigation.md](../docs/design/navigation.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [SECURITY.md](../SECURITY.md)
- [apps/novels/Features/Diagnostics/](../apps/novels/Features/Diagnostics/)
- [apps/novels/Services/DiagnosticsLog.swift](../apps/novels/Services/DiagnosticsLog.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, unit tests (including `DiagnosticsLogTests` 10 tests for redaction, ring buffer eviction at 501->500, and filtering), and drift check. Session-only diagnostic architecture documented in `docs/decisions/diagnostic-log-viewer.md`. Later flat timeline and JSON run refinements are detailed in [task-chapter-run-json-log](task-chapter-run-json-log.md) and [task-log-viewer-correctness](task-log-viewer-correctness.md).
- Blockers: None.
- Next: HISTORICAL: Manual verification of log screen timeline, filtering, and redaction behavior during reader AI runs.
