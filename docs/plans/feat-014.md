# Plan — feat-014 Diagnostic Log Viewer

> Separate plan (>=4 files + phases). Feature: `features/feat-014.md`. ADR: `docs/decisions/diagnostic-log-viewer.md`.

## 1. LogEntry contract (shared — designer + fixer both follow)

```swift
enum LogKind { case event, api }
struct LogEntry: Identifiable {
  let id: UUID
  let timestamp: Date // ISO8601 ms khi render
  let requestId: UUID // per chunk POST, xuyên attempts
  let sessionId: UUID // per launch
  let kind: LogKind
  let bookId: String // slug only
  let chapterNumber: Int
  let mode: String // "rewrite"
  let chunkIndex: Int? // nil cho prefetch/cache events
  let chunkTotal: Int?
  let attempt: Int // 1..3
  let latencyMs: Int
  // api-only
  let host: String? // default host-only
  let statusCode: Int?
  let errorDomain: String?
  let errorCode: Int?
  let model: String?
  let responseLen: Int?
  let responseHashPrefix: String? // 8 hex SHA256
  // redacted payloads
  let headersRedacted: [String: String]? // auth value = "<redacted>"
  let bodyLen: Int?
  let bodyHashPrefix: String?
  let snippet: String? // ≤100 req / ≤200 resp, chỉ khi verbose
  // event detail
  let event: String? // chunk.start/success/fail, retry.scheduled, cache.hit/miss/save, dedup.shared, prefetch.batchCheck/skip/cancel/error-continue, chapter.switch.cancel, invalid.headers/body
  let detail: String? // backoffMs, reason, rangeFrom/To, hit/miss count, keyHashPrefix, originalRequestId
}
```

Scenario → fields (minimum): per oracle ora-1 §1. Always include the 9 common fields. `requestId` correlates attempts. `contentHashPrefix` for chunk in/out. `retryAfterMs` from the header on 429 (read `allHeaderFields` case-insensitive).

## 2. Redaction (safe default, verbose opt-in)

| Field | Default | Verbose (`DIAGNOSTICS_VERBOSE=true`) |
|---|---|---|
| Header match `/(?i)(authorization|token|api[-_]?key|secret|bearer|x-api-key|cookie|set-cookie)/` | key kept, value `"<redacted>"` | still `"<redacted>"` |
| Request body / chunk input / response text | `len + hashPrefix`, empty snippet | + snippet ≤100 (req) / ≤200 (resp, `choices[0].message.content` head + "…") |
| `AI_PROMPT` | `len + hashPrefix`, never raw | still never raw |
| Endpoint | host only | host + path, no query |
| errorMessage | `len + hashPrefix` | + snippet ≤200 |

Route name (final): `Router.Route.apiLog(bookId: String?)`. Button: new row in `ReaderBottomSheet` below the AI section, label "Nhật ký", icon `doc.text.magnifyingglass`, id `apiLogButton`, action `onClose(); router?.push(.apiLog(bookId))`.

## 3. Timeout + budget (hardcoded, no setting)

- `URLSessionConfiguration.timeoutIntervalForRequest = 180`, `timeoutIntervalForResource = 600`, `waitsForConnectivity = true`. Replace `.shared` with an ephemeral/default config in `AIClient` (keeping actor isolation).
- Keep retry 3x 1s/2s, only 5xx/URLError; throw 4xx immediately (unchanged so logs can distinguish, no policy change).
- Prefetch budget: 600s/chapter + 1800s/global → log `prefetch.cancel reason=budgetExhausted` then continue/cancel.

## 4. Presentation (timeline default)

- Default flat timeline DESC. Filter chips: kind (Tất cả/Sự kiện/API/Lỗi) + book + chapter dropdown + search (requestId/host/errorCode/snippet).
- Group toggle: Dòng thời gian | Theo chương (secondary preference).
- Row collapsed: timestamp + kind icon + book/chapter/chunk + status badge + latency. Tap expand: headers (redacted) + body (len/hash/snippet) + status.
- Entry: bottom sheet → push `Reading --> Log`, back to Reading. Vietnamese. iPhone-only.

## 5. Phases + ownership (song song sau plan)

Phase 0 — Docs (orchestrator done): feat file + plan + ADR + index.
Phase 1a — Core (@fixer, owns logic): `Domain/DiagnosticsEntry.swift`, `Services/DiagnosticsLog.swift` (actor ring 500 + store + OSLog), instrument `AIClient`/`AIReadingService`/`PrefetchManager`, timeout/budget, `SettingsStore.DIAGNOSTICS_VERBOSE` + sanitize, unit tests (redaction, eviction 501→500, timeout values, prefetch markers).
Phase 1b — UI (@designer, owns UI): `ReaderBottomSheet` button row, `Features/Diagnostics/LogScreen.swift` (list/filter/group/expand), `Router.apiLog` + `AppRoot` destination, a11y identifiers (`apiLogButton`, `logList`, `logFilter-*`, `logRow-*`), Vietnamese copy review.
→ No overlapping writes: fixer does not touch `ReaderBottomSheet/LogScreen/Router/AppRoot`; designer does not touch `Services/*`/timeout/tests logic. Shared contract §1-§2 is immutable; contract changes go through the orchestrator.
Phase 2 — Docs follow-up (whoever finishes first notifies the orchestrator): `ARCHITECTURE.md` §3, `navigation.md`, `screens.md`, `SECURITY.md`, `settings-schema.md` — merge into 1 docs commit to avoid conflicts.
Phase 3 — Reconcile + `./init.sh` full + progress block.

## 6. Tests

- Redaction: any auth header value → entry `<redacted>`; raw prompt never appears.
- Eviction: push 501 → count 500, oldest lost.
- Filter/group/search binding + verbose toggle off default.
- Timeout: config values 180/600 + waitsForConnectivity true.
- Prefetch: batchCheck hit/miss counts, skip/cancel reasons, budgetExhausted marker.

## 7. Rollback

- Revert `AIClient` session config to `.shared` + 15s if the provider regresses.
- Hide the `apiLogButton` button (view feature flag) without removing core logging.
- ADR keeps append-only history; do not delete `network-logger-removed.md`.
