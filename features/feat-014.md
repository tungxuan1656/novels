# feat-014 — Diagnostic Log Viewer (in-session, timeline)

## Goal

View API logs + story-translation events over time for early diagnosis: chunk start/success/fail, retries 1-3, timeout, 429/quota/5xx, empty choices, invalid headers/body ignored, cache hit/miss/save, shared dedup, prefetch batch-check/skip/cancel/error-continue. AI timeout hardcoded to 180s. Entry from the reading bottom sheet → new Log screen (DESC timeline by default + group-by-chapter toggle).

## Context

- Currently zero logs (`AIClient`/`AIReadingService`/`PrefetchManager` have no print/OSLog). `AIClient.swift:55` uses `URLSession.shared` + `request.timeoutInterval = 15` per attempt. Retry 3x with 1s/2s backoff only for 5xx/URLError; 4xx/429/decode/noResponse throw immediately without retry. Status is read at `AIClient.swift:57-62` but drops `allHeaderFields`/error body. Sequential chunks at `AIReadingService.swift:42-45`. Prefetch range `current+1..+N` + `batchStatus` skips cached + sequential + `errors[]` (`PrefetchManager.swift:41-67,86-125`).
- `ReaderBottomSheet` is an overlay (not a route). Insertion point: new row below the AI section, full-width `apiLogButton` (does not break the inline `aiModePicker` + `reprocessButton` on the same row). Push a new route after `onClose()` like gear → Settings.
- Conflict: `docs/decisions/network-logger-removed.md` (Accepted) removed the Network Logger for missing retention/redaction. This feature partially reverses that via new ADR `diagnostic-log-viewer.md` (runtime-only + codified redaction, no persisted secrets).

## Scope

- `Services/DiagnosticsLog.swift`: `actor DiagnosticsLog` ring buffer of 500 entries FIFO, in-memory only, cleared on launch + parallel `os.Logger(subsystem: com.tungxuan.novels.diagnostics, privacy: .private)` emit.
- `Domain/DiagnosticsEntry.swift` (or inside Services): `LogEntry` with common fields `timestamp/requestId/sessionId/kind/bookId/chapterNumber/mode/chunkIndex/chunkTotal/attempt/latencyMs` + kind-specific fields per `docs/plans/feat-014.md` §1.
- Instrumentation: `AIClient.complete` (request event before `data(for:)` + response event in catch, including `statusCode/host/model/errorDomain/code/elapsedMs/timeoutKind`, auth redacted), `AIReadingService` (chunkCount after `chunk()` + outputHash after join, per-chunk wrapper outside `client.complete`), `PrefetchManager.updateStatus/finish` (batchCheck/skip/cancel/error-continue/budgetExhausted).
- Hardcoded timeout: `URLSessionConfiguration.timeoutIntervalForRequest = 180`, `timeoutIntervalForResource = 600`, `waitsForConnectivity = true`. No new setting. Prefetch budget: 600s/chapter + 1800s/global → `prefetch.cancel reason=budgetExhausted`.
- UI: `Features/Diagnostics/LogScreen.swift` DESC timeline + kind/book/chapter/search filter + timeline/group-by-chapter toggle + row expand (redacted headers, body len+hash+snippet only when verbose). `ReaderBottomSheet` adds a "Nhật ký" button (`doc.text.magnifyingglass`, `apiLogButton`) after the AI section. `Router.Route.apiLog(bookId: String?)` + `AppRoot` destination. Vietnamese, iPhone-only.
- Docs: ADR `docs/decisions/diagnostic-log-viewer.md`, update `ARCHITECTURE.md` §3, `navigation.md` §1 (`Reading --> Log`), `screens.md`, `SECURITY.md` (redaction), `settings-schema.md` (`DIAGNOSTICS_VERBOSE` default false).

## Non-goals

- No persisted logs (SQLite/file) — keep the spirit of `local-persistence.md`.
- No logging of raw `Authorization`/`Cookie`/secrets, raw `AI_PROMPT`, or raw chapter/response text beyond snippets.
- No new timeout setting, no new Settings entry, no second cache.
- No change to the hard chunk split (1300) or retry policy (3x 1s/2s) apart from the timeout value.

## Acceptance

- [x] Bottom sheet has a "Nhật ký" button pushing to `LogScreen`; back returns to Reading.
- [x] `LogScreen` lists ≤500 entries DESC; has common + API/event fields per plan §1.
- [x] No entry contains a literal auth value (always `<redacted>`); no raw prompt; snippets ≤100-200 chars only when verbose.
- [x] `DIAGNOSTICS_VERBOSE` defaults to false; snippets/host+path only when enabled.
- [x] Kind/book/chapter/search filter + group toggle work; tap expands detail.
- [x] Relaunch → empty log; timeout config 180/600 + waitsForConnectivity; prefetch budget markers present.
- [x] Redaction/ring-buffer/filter tests PASS; `./init.sh` full PASS.

## Relevant docs

- `docs/plans/feat-014.md` (Separate plan — source of truth for tasks/ownership)
- `docs/decisions/diagnostic-log-viewer.md` (partially supersedes `network-logger-removed.md`)
- `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`, `docs/contracts/local-data.md`
- `docs/product/functional-specs/ai-reading.md`, `docs/product/functional-specs/chapter-prefetch.md`
- `docs/design/navigation.md`, `docs/design/screens.md`, `SECURITY.md`, `ARCHITECTURE.md` §3

## Plan

External plan: `docs/plans/feat-014.md`. Ownership:
- @designer owns `ReaderBottomSheet.swift` (button row), `Features/Diagnostics/LogScreen.swift`, `Router.swift`/`AppRoot.swift` navigation wiring (UI scope only).
- @fixer owns `Services/DiagnosticsLog.swift`, `Domain/DiagnosticsEntry.swift`, `AIClient.swift`, `AIReadingService.swift`, `PrefetchManager.swift`, timeout/budget, redaction tests + ring-buffer tests (logic scope only).
- Shared contract: `LogEntry` fields + redaction table in plan §1-§2; route name `apiLog(bookId:)`.

## Verify

- `./init.sh` full (format + lint + build + test + drift)
- Targeted: redaction unit tests, eviction 501→500, filter/group/search binding, verbose toggle

## Handoff (done)

- State: done — des-1 UI + fix-1 core + fix-2 prefetch-bookDeleted guard done; docs follow-up (ARCHITECTURE §1/§3, navigation, screens, SECURITY, settings-schema) done; `./init.sh` full PASS.
- Evidence: `Domain/DiagnosticsEntry.swift`, `Services/DiagnosticsLog.swift` (ring 500 + OSLog private), `AIClient` 180/600 + waitsForConnectivity + request/response/retry/invalid events, `AIReadingService` chunk.start/success/fail + cache/dedup, `PrefetchManager` batchCheck/skip/cancel/error-continue + budget 600/1800 + loop-top bookDeleted guard, `ReaderBottomSheet.apiLogButton` + `Features/Diagnostics/LogScreen.swift` timeline/filter/group/expand + `Router.apiLog` + `AppRoot`, `DiagnosticsLogTests` 10 tests, `./init.sh` full PASS (format/lint/build/test/drift).
- Blockers: none
- Next: repo idle — user retests on Simulator: reading + AI Rewrite + prefetch, then opens the "Nhật ký" log to check timeline, filter, expand, verbose toggle.
