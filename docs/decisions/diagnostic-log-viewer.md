# ADR — Add Diagnostic Log Viewer (in-session ring buffer)

- **Date:** 2026-09-04
- **Status:** Accepted
- **Supersedes (partial):** `network-logger-removed.md` — only the "no Network Logger screen or route" aspect. Retention/redaction concerns of that ADR are codified here.

## Context

AI rewrite via OpenAI-compatible endpoint runs silently. User needs visibility into chunk start/success/fail, retry attempts, timeout, HTTP status (429/401/403/5xx), quota, empty `choices[0]`, invalid JSON headers/body, cache hit/miss/save, dedup, prefetch batch-check/skip/cancel, chapter switch cancel. Prefetch introduces failures invisible until next chapter fails. Previous Network Logger was removed because no retention/redaction policy was defined. Recon: zero log today; `AIClient.swift:55` timeout 15s/request on `.shared`; retry 3x 1s/2s only 5xx/URLError; status read without headers/body.

## Decision

1. Add in-memory ring buffer `actor DiagnosticsLog` + `@Observable DiagnosticsStore`, last ≤500 entries FIFO, cleared on launch. No persistence.
2. Add `LogScreen` push from `ReaderBottomSheet` (`Reading --> Log`). Do NOT add to Settings.
3. Default safe level per redaction table below. Verbose opt-in via `DIAGNOSTICS_VERBOSE` (default false). Never log raw secret/prompt/chapter text.
4. Parallel emit `os.Logger(subsystem: com.tungxuan.novels.diagnostics, privacy: .private)`.
5. Hardcode `timeoutIntervalForRequest=180`, `timeoutIntervalForResource=600`, `waitsForConnectivity=true`. No setting until user data warrants.
6. Prefetch budgets: per-chapter 600s, global 1800s; log `prefetch.cancel reason=budgetExhausted` on breach.

## Redaction Policy

- Header match `/(?i)(authorization|token|api[-_]?key|secret|bearer|x-api-key|cookie|set-cookie)/`: keep key, value `"<redacted>"` always (even verbose).
- Body/chunk/response: default `len + SHA256-8`, no snippet. Verbose: req snippet ≤100 head + "…", resp snippet ≤200 head.
- `AI_PROMPT`: `len + hash`, never raw.
- Endpoint: default host-only; verbose host+path, never query.
- errorMessage: default `len + hash`; verbose snippet ≤200.

## Alternatives

- SQLite persisted → rejected: retention + credential-at-rest risk.
- File JSONL → rejected: same.
- OSLog only (no UI) → rejected: user explicitly needs timeline UI.

## Consequences

- `ARCHITECTURE.md` §3: replace "No Network Logger screen or route" with "No persisted Network Logger; in-session diagnostic viewer allowed per this ADR".
- `docs/design/navigation.md` §1: add `Reading --> Log`.
- `docs/design/screens.md`: add `LogScreen` row.
- `SECURITY.md`: reference redaction policy.
- `ARCHITECTURE.md` §1 + `docs/contracts/settings-schema.md`: add `DIAGNOSTICS_VERBOSE`.
- `settings-schema.md` sanitize BR-12 covers new boolean.

## Links

- `../network-logger-removed.md` (partial reversal) · `../../SECURITY.md` · `../../ARCHITECTURE.md` §3 · `../../docs/design/navigation.md` · `../../docs/design/screens.md` · `../../docs/contracts/ai-service.md` · `../../docs/contracts/settings-schema.md` · `../../docs/product/functional-specs/ai-reading.md` · `../../docs/product/functional-specs/chapter-prefetch.md`

## Amendment 2026-09-04 — feat-019 grouped chapter-run view + in-RAM JSON bodies

- Log groups 1 row = 1 chapter × 1 processing run (`runId` per `processedContent`/`reprocess` call, threaded through chunk/api/cache entries; prefetch assigns one `runId` per chapter attempt). Manual retry = new row. Row shows run status (Thành công/Thất bại/Đang xử lý) + chunk counts; expand reveals inner events incl. retry attempts.
- One deliberate exception to "never raw body": full request/response JSON is kept **in RAM only** on the api entry (`requestBody`/`responseBody`), shown in-app in a bottom sheet viewer. Never persisted, never in `debugSummary`/OSLog. Headers block removed from Log UI; model row removed; server shows full URL.
- Filters removed (book/chapter pickers, kind chips, timeline/chapter segmentation). Search kept, narrowed to chapter number/status/event/detail (no requestId/host/error code).
