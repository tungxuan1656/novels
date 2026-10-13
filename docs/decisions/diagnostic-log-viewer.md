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

- Log groups 1 row = 1 chapter × 1 processing run (`runId` per `processedContent`/`reprocess` call, threaded through chunk/api/cache entries; prefetch assigns one `runId` per chapter attempt). Manual retry = new row. Row shows run status (Success/Failure/Processing) + chunk counts; expand reveals inner events incl. retry attempts.
- One deliberate exception to "never raw body": full request/response JSON is kept **in RAM only** on the api entry (`requestBody`/`responseBody`), shown in-app in a bottom sheet viewer. Never persisted, never in `debugSummary`/OSLog. Headers block removed from Log UI; model row removed; server shows full URL.
- Filters removed (book/chapter pickers, kind chips, timeline/chapter segmentation). Search kept, narrowed to chapter number/status/event/detail (no requestId/host/error code).

## Amendment 2026-10-13 — Reader lifetime and explanatory outcomes

- Opening Log must not cancel current-chapter processing or prefetch. Only an accepted Log push preserves the reader work; normal Reader exit still cancels it. Returning to the same chapter does not restart a paid request.
- Distinguish cancelled from failed runs. Transport cancellation is silent, never retried, and cannot overwrite a real failure in another chunk. A later terminal cache success can clear a transient retry failure.
- Explain API and event outcomes in Vietnamese while keeping technical codes available. Failed-run summaries include the affected chunk/attempt and underlying API cause; a later semantic pairing failure remains visible rather than being replaced with a recovered API error.
- Log opens scoped to the current book. An optional error-focused entry expands failed runs instead of filtering individual events, retaining the full timeline and later recovery. Search additionally covers human explanations and error codes, never raw request/response bodies. Retention and redaction are unchanged.

## Amendment 2026-10-13 — AI timeline and cache inventory

- Main Log lists AI-processing runs by book/chapter/mode, newest first, with book title, reader/prefetch/manual origin, elapsed time, chunk progress, outcome and cause. Cache-only reads and general prefetch queue events remain in the ring but are omitted from the AI timeline.
- Status and mode filters select whole runs; error-focused entry selects failed runs. The Reader warning counts failed runs for the same book, not individual error entries or other books. Recovered retries remain inspectable without triggering a failure warning. The initial filter is checked again against fresh scoped runs on entry so a newly recovered run is not hidden. Search never strips surrounding request/retry context. This supersedes the earlier no-filter and error-expansion-only presentation.
- Invalid custom headers/body warnings remain searchable and visible in run details, including linked shared requests. Detect invalid/non-object JSON before adding generated request headers; blank input and valid empty objects do not warn. Explain that invalid JSON was ignored without turning a successful run into a failure.
- While the Reader sheet is visible, observe fresh Diagnostics snapshots so failed-run warnings follow new outcomes and recovery without reopening it. Subscribe before the initial refresh and cancel the observer on dismissal; stale teardown must not end a replacement Log observer.
- Each API attempt shows one current/final outcome; retry attempts remain separate. Sending and outcome entries remain separate in the append-only ring; only presentation coalesces them and hidden sending entries still count toward its 500-entry limit. Request detail includes model and endpoint with URL credentials, query and fragment removed, plus the existing RAM-only JSON viewer. This supersedes removal of the model row and display of the full URL.
- Consumer run start/success/failure/cancellation are explicit. Shared runs link to origin requests, retaining their own source and terminal outcome. Cancellation cannot hide an unresolved chunk failure belonging to that consumer; a deliberately cancelled shared consumer does not inherit the origin's failures. A failed shared consumer retains the origin's chunk/attempt and cause. HTTP success remains separate from bilingual validation and cache save; recovered HTTP retries never replace a later local-cache failure.
- Cache Manager is current-state inventory from the single SQLite cache, not history derived from the ring: book title/slug, chapter, mode and updated time. Distinguish saved versions from distinct chapters. Keep existing confirmed per-book/all deletion; do not add a second cache, persisted log or migration. Log links to that existing screen.
