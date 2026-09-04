# feat-019 — Log theo chapter-run + xem JSON thô

## Goal

Màn Nhật ký gom 1 row = 1 chapter-1 lần xử lý với trạng thái rõ ràng (Thành công/Thất bại/Đang xử lý); nhấn vào thấy đầy đủ events + retry bên trong; chi tiết API xem được JSON thô toàn bộ (request + response) trong bottom sheet.

## Context

- Log hiện tại là timeline phẳng từng entry + filter sách/chương + chips Tất cả/Sự kiện/API/Lỗi + toggle Dòng thời gian/Theo chương; tìm kiếm cả requestId/host/mã lỗi. Khi chapter lỗi, user không biết lỗi nằm ở chunk/API nào.
- Retry manual cùng chapter phải thành row mới (phân biệt các lần xử lý), không trộn vào nhau.
- Ràng buộc cũ (ADR `diagnostic-log-viewer.md`): không raw body. feat-019 nới đúng 1 điểm: JSON thô giữ **trong RAM** (entry ring buffer, không persist, không OSLog), chỉ hiển thị trong app; headers không hiển thị ở UI nữa nên không lộ secret.

## Scope

- `Domain/DiagnosticsEntry.swift`: `LogEntry` thêm 3 field defaulted (source-compatible): `runId: UUID? = nil`, `requestBody: String? = nil`, `responseBody: String? = nil`. `AIDiagnosticsContext` thêm `runId: UUID? = nil`. `debugSummary` không đổi (không raw).
- `Services/AIClient.swift`: capture `requestBody` (JSON gửi đi, string) + `responseBody` (data trả về, UTF-8 string) vào mọi entry API (success + mọi nhánh fail). `host` ghi full URL thay vì redacted display.
- `Services/AIReadingService.swift`: `processedContent`/`reprocess` thêm param `runId: UUID? = nil` (`let run = runId ?? UUID()`); mọi log của lần gọi (cache hit/miss/save, chunk start/success/fail, context truyền client) dùng `run`.
- `Services/PrefetchManager.swift`: mỗi chapter trong loop tạo `runId = UUID()`; truyền vào `processedContent(..., runId:)`; các log `prefetch.error-continue` của chapter đó (missing/empty/aiError) gắn cùng `runId`.
- `Features/Diagnostics/LogScreen.swift` (@designer): xóa filter sách/chương, xóa chips kind, xóa group toggle; giữ ô tìm kiếm, chỉ khớp số chương/trạng thái/sự kiện/chi tiết (không requestId/host/mã lỗi). List gom theo `runId` DESC theo thời gian mới nhất: row "Rewrite · Ch 20" + badge trạng thái + số chunk; nhấn mở rộng events (giữ `LogRowView` cho inner entries incl. retry attempts); nhấn API event mở bottom sheet JSON (request + response, mono, cuộn, dùng `BottomSheetView`).
- Xóa ở UI: block headers, dòng Mô hình. `Router.apiLog(bookId:initialFilter:)` giữ nguyên chữ ký; `initialFilter == .error` thì mở rộng sẵn các group failed.
- Tests: runId phân biệt 2 lần xử lý cùng chapter; retry cùng run; body đầy đủ; host full URL; grouping/status; search hẹp; UI identifiers mới.

## Non-goals

- Không persist log (SQLite/file) — giữ spirit `local-persistence.md`.
- Không copy/share JSON, không syntax highlight.
- Không đổi retry/chunk/prefetch logic, không thêm setting.

## Acceptance

- [x] Rewrite ch20 fail → row ch20 badge Thất bại; bên trong thấy đúng chunk/API lỗi + attempt 1/2.
- [x] Manual "Xử lý lại" ch20 → row mới riêng, không trộn row cũ.
- [x] Prefetch 21,22,23 → 3 rows riêng (mỗi chapter-run 1 row).
- [x] Chi tiết API mở bottom sheet thấy JSON thô request + response toàn bộ.
- [x] Không còn filter sách/chương, chips, segmentation; search không khớp requestId/host/mã lỗi.
- [x] Không entry nào persist raw ra disk/OSLog (`debugSummary` không raw).
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/decisions/diagnostic-log-viewer.md` (Amendment feat-019)
- `docs/contracts/ai-service.md` (ghi chú body RAM-only)
- `docs/design/screens.md` (row Log mới)
- `docs/plans/feat-014.md` (ownership gốc: @fixer logic / @designer UI — giữ nguyên)

## Plan (inline)

1. @fixer (data): entry fields + context runId + AIClient capture + host full URL + service/prefetch runId threading + logic tests; `./init.sh --quick` + targeted suites.
2. @designer (UI, sau 1): LogScreen regroup + JSON bottom sheet + xóa filters + UI tests; `./init.sh --quick` + targeted.
3. Orchestrator: `./init.sh` full + đóng feat.

## Verify

- `./init.sh` full (format + lint + build + test + drift).

## Handoff

- State: done — @fixer data (runId threading + bodies RAM-only + host full URL, 47/47 targeted) + @designer UI (regroup runId + JSON bottom sheet + xóa filters, quick + targeted PASS) + full `./init.sh` PASS 2026-09-04.
- Evidence: `LogRunBuilder`/`LogRunGroup` + `LogScreenGroupingTests` 11/11; `AIClientTests` bodies tests; full suite ** TEST SUCCEEDED ** + drift PASS.
- Blockers: none (tree uncommitted — chưa commit vì chưa được yêu cầu).
- Next: repo idle — user retest màn Nhật ký: row chapter-run + badge trạng thái, expand xem retry, "Xem JSON thô".

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
