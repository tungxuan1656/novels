# feat-014 — Diagnostic Log Viewer (in-session, timeline)

## Goal

Xem log API + sự kiện dịch truyện theo thời gian để diagnose sớm: chunk start/success/fail, retry 1-3, timeout, 429/quota/5xx, empty choices, invalid headers/body ignored, cache hit/miss/save, dedup shared, prefetch batch-check/skip/cancel/error-continue. Timeout AI hardcode 180s. Entry từ reading bottom sheet → màn hình Log mới (timeline DESC mặc định + toggle group-by-chapter).

## Context

- Hiện tại zero log (`AIClient`/`AIReadingService`/`PrefetchManager` không có print/OSLog). `AIClient.swift:55` dùng `URLSession.shared` + `request.timeoutInterval = 15` mỗi attempt. Retry 3x backoff 1s/2s chỉ cho 5xx/URLError; 4xx/429/decode/noResponse ném ngay không retry. Status đọc tại `AIClient.swift:57-62` nhưng bỏ `allHeaderFields`/error body. Chunk sequential tại `AIReadingService.swift:42-45`. Prefetch range `current+1..+N` + `batchStatus` skip cached + sequential + `errors[]` (`PrefetchManager.swift:41-67,86-125`).
- `ReaderBottomSheet` là overlay (không phải route). Vị trí chèn: row mới dưới AI section, full-width `apiLogButton` (không phá inline `aiModePicker` + `reprocessButton` cùng row). Push route mới sau `onClose()` như gear → Settings.
- Xung đột: `docs/decisions/network-logger-removed.md` (Accepted) đã xóa Network Logger vì thiếu retention/redaction. Feature này đảo một phần qua ADR mới `diagnostic-log-viewer.md` (runtime-only + redaction codified, không persisted secret).

## Scope

- `Services/DiagnosticsLog.swift`: `actor DiagnosticsLog` ring buffer 500 entries FIFO, in-memory only, clear on launch + `os.Logger(subsystem: com.tungxuan.novels.diagnostics, privacy: .private)` parallel emit.
- `Domain/DiagnosticsEntry.swift` (hoặc trong Services): `LogEntry` với fields chung `timestamp/requestId/sessionId/kind/bookId/chapterNumber/mode/chunkIndex/chunkTotal/attempt/latencyMs` + kind-specific per `docs/plans/feat-014.md` §1.
- Instrument: `AIClient.complete` (request event trước `data(for:)` + response event trong catch, gồm `statusCode/host/model/errorDomain/code/elapsedMs/timeoutKind`, redact auth), `AIReadingService` (chunkCount sau `chunk()` + outputHash sau join, per-chunk wrap ngoài `client.complete`), `PrefetchManager.updateStatus/finish` (batchCheck/skip/cancel/error-continue/budgetExhausted).
- Timeout hardcode: `URLSessionConfiguration.timeoutIntervalForRequest = 180`, `timeoutIntervalForResource = 600`, `waitsForConnectivity = true`. Không thêm setting. Prefetch budget: 600s/chương + 1800s/global → `prefetch.cancel reason=budgetExhausted`.
- UI: `Features/Diagnostics/LogScreen.swift` timeline DESC + filter kind/book/chapter/search + toggle timeline/group-by-chapter + row expand (headers redacted, body len+hash+snippet nếu verbose). `ReaderBottomSheet` thêm button "Nhật ký" (`doc.text.magnifyingglass`, `apiLogButton`) sau AI section. `Router.Route.apiLog(bookId: String?)` + `AppRoot` destination. Vietnamese, iPhone-only.
- Docs: ADR `docs/decisions/diagnostic-log-viewer.md`, update `ARCHITECTURE.md` §3, `navigation.md` §1 (`Reading --> Log`), `screens.md`, `SECURITY.md` (redaction), `settings-schema.md` (`DIAGNOSTICS_VERBOSE` default false).

## Non-goals

- Không persisted log (SQLite/file) — giữ spirit `local-persistence.md`.
- Không log raw `Authorization`/`Cookie`/secret, raw `AI_PROMPT`, raw chapter/response text vượt snippet.
- Không thêm timeout setting, không thêm entry Settings, không cache thứ hai.
- Không thay đổi chunk split (cắt cứng 1300) hay retry policy (3x 1s/2s) ngoài timeout value.

## Acceptance

- [x] Bottom sheet có button "Nhật ký" push tới `LogScreen`; back về Reading.
- [x] `LogScreen` list ≤500 entries DESC; đủ fields chung + API/event fields per plan §1.
- [x] Không entry nào chứa literal auth value (luôn `<redacted>`); không raw prompt; snippet ≤100-200 chars chỉ khi verbose.
- [x] `DIAGNOSTICS_VERBOSE` default false; bật mới cho snippet/host+path.
- [x] Filter kind/book/chapter/search + group toggle hoạt động; tap expand detail.
- [x] Relaunch → log rỗng; timeout config 180/600 + waitsForConnectivity; prefetch budget markers có mặt.
- [x] Redaction/ring-buffer/filter tests PASS; `./init.sh` full PASS.

## Relevant docs

- `docs/plans/feat-014.md` (Separate plan — nguồn thật cho tasks/ownership)
- `docs/decisions/diagnostic-log-viewer.md` (partial supersede `network-logger-removed.md`)
- `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`, `docs/contracts/local-data.md`
- `docs/product/functional-specs/ai-reading.md`, `docs/product/functional-specs/chapter-prefetch.md`
- `docs/design/navigation.md`, `docs/design/screens.md`, `SECURITY.md`, `ARCHITECTURE.md` §3

## Plan

External plan: `docs/plans/feat-014.md`. Ownership:
- @designer owns `ReaderBottomSheet.swift` (button row), `Features/Diagnostics/LogScreen.swift`, `Router.swift`/`AppRoot.swift` navigation wiring (UI scope only).
- @fixer owns `Services/DiagnosticsLog.swift`, `Domain/DiagnosticsEntry.swift`, `AIClient.swift`, `AIReadingService.swift`, `PrefetchManager.swift`, timeout/budget, redaction tests + ring-buffer tests (logic scope only).
- Shared contract: `LogEntry` fields + redaction table trong plan §1-§2; route name `apiLog(bookId:)`.

## Verify

- `./init.sh` full (format + lint + build + test + drift)
- Targeted: redaction unit tests, eviction 501→500, filter/group/search binding, verbose toggle

## Handoff (done)

- State: done — des-1 UI + fix-1 core + fix-2 prefetch-bookDeleted guard done; docs follow-up (ARCHITECTURE §1/§3, navigation, screens, SECURITY, settings-schema) done; `./init.sh` full PASS.
- Evidence: `Domain/DiagnosticsEntry.swift`, `Services/DiagnosticsLog.swift` (ring 500 + OSLog private), `AIClient` 180/600 + waitsForConnectivity + request/response/retry/invalid events, `AIReadingService` chunk.start/success/fail + cache/dedup, `PrefetchManager` batchCheck/skip/cancel/error-continue + budget 600/1800 + loop-top bookDeleted guard, `ReaderBottomSheet.apiLogButton` + `Features/Diagnostics/LogScreen.swift` timeline/filter/group/expand + `Router.apiLog` + `AppRoot`, `DiagnosticsLogTests` 10 tests, `./init.sh` full PASS (format/lint/build/test/drift).
- Blockers: none
- Next: repo idle — user retest trên Simulator: đọc + AI Rewrite + prefetch rồi mở Nhật ký kiểm tra timeline, filter, expand, verbose toggle.
