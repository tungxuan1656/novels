# feat-018 — Rewrite + Prefetch Correctness (gom feat-015/016/017)

## Goal

Hành vi rewrite + tải trước đúng như user chốt 2026-09-04: batch chunk song song join đúng thứ tự, retry 1 lần đúng chunk lỗi, prefetch sequential chỉ khi đổi chapter thật, header spinner duy nhất cho chapter hiện tại, back từ Nhật ký zero-API.

## Context

- feat-015/016/017 chồng nhau cho cùng 1 vấn đề (song song + retry + kẹt spinner + decode 200-lạ), hiện uncommitted nhưng đã mark done. Đóng băng 3 feat này ở trạng thái lưu trữ, dồn toàn bộ hành vi đúng vào feat-018 duy nhất. Không tạo feat mới cho mỗi lần sửa nhỏ nữa.
- Bug gốc: vào Nhật ký rồi back lại Reading ch22 thì retry prefetch dù trước đó đã lỗi-dừng; spinner nằm trong content + bottom-sheet gây nhầm chapter hiện tại vs prefetch.

## Scope

- `Services/AIClient.swift`: loop tối đa 2 attempts/chunk (mọi loại lỗi, đúng chunk lỗi, cùng requestId, log attempt 1/2 riêng, `Task.checkCancellation`).
- `Services/AIReadingService.swift`: giữ TaskGroup song song index-keyed ordered join `"\n"`, fail-fast 1 chunk sau 2 attempts → abort chapter, không cache partial.
- `Services/PrefetchManager.swift` + `Features/Reading/ReaderViewModel.swift`: trigger prefetch chỉ khi chapterNumber đổi thật (goNext/goPrev/goToChapter/References/mode switch/reprocess); `load(source)` phân biệt chapterChange vs return-from-Log; back từ Log cùng chapter → zero API, giữ terminal status; batchStatus all-cached → zero call; miss → sequential từng chapter batch; lỗi skip + `errors[]` + `prefetch.error-continue`; 2 đường tải lại (next-chapter auto-check, ngoài window manual "Xử lý lại").
- `Features/Reading/ReaderView.swift`: xóa `aiSection` spinner + `prefetchIndicator` khỏi content; header hàng 2 thêm spinner 12px trái capsule prev/next, visible chỉ khi `isAIProcessing` chapter hiện tại.
- `Features/Reading/ReaderBottomSheet.swift`: xóa hoàn toàn indicator loading; giữ picker + "Xử lý lại" + nút Nhật ký (badge lỗi).
- Lỗi: `CancellationError` riêng (clear flag, không toast); chapter fail toast 1 lần + raw fallback; prefetch fail silent (badge + Log).
- Docs (đã cập nhật trước code trong brainstorm này): `docs/contracts/ai-service.md`, `docs/product/functional-specs/ai-reading.md`, `docs/product/functional-specs/chapter-prefetch.md`, `docs/design/screens.md`.
- Tests extend (không file mới trừ khi cần): per-chunk retry đúng chunk, join đúng thứ tự delay ngược, back-from-Log zero-API, header spinner chỉ current, prefetch sequential-skip.

## Non-goals

- Không đổi timeout 180/600, chunk hint 1300, cache key, ATS localhost-only, Log shape fields hiện có.
- Không thêm setting, không envelope `{data:...}` thành success, không raw log.
- Không refactor ngoài scope rewrite/prefetch/header.

## Acceptance

- [x] 1 chunk lỗi → retry 1 lần đúng chunk đó (requests==2 cho chunk lỗi, chunk khác==1), success thì join đúng thứ tự.
- [x] 1 chunk fail 2 lần → abort chapter, toast 1 lần, raw fallback, không cache partial, manual "Xử lý lại" được.
- [x] Đổi chapter → batchStatus: all-cached zero API; còn miss → sequential từng chapter batch, lỗi skip tiếp.
- [x] Ở ch22 vào Nhật ký back lại → zero API (không reload current, không prefetch), giữ status cũ.
- [x] Header spinner chỉ khi chapter hiện tại rewrite; content + bottom-sheet không spinner; prefetch chạy không hiện header.
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/contracts/ai-service.md` (Chunking + Retry bounded per-chunk)
- `docs/product/functional-specs/ai-reading.md` (batch join + manual retry)
- `docs/product/functional-specs/chapter-prefetch.md` (trigger chapter-change + sequential + back-zero-API)
- `docs/design/screens.md` (Loading header-only)
- `features/feat-015.md`, `features/feat-016.md`, `features/feat-017.md` (lưu trữ, không sửa tiếp)

## Plan

External: `docs/plans/feat-018.md`. Ownership:
- @fixer: `AIClient`, `AIReadingService`, `PrefetchManager`, `ReaderViewModel`, tests logic.
- @designer: `ReaderView` header spinner + xóa content indicator, `ReaderBottomSheet` xóa spinner.
- Shared: trigger source + zero-API + toast/raw-fallback.

## Verify

- `./init.sh` full (format + lint + build + test + drift).

## Handoff

- State: done — fix-1 (Tasks 1-3: AIClient 2 attempts stable requestId + TaskGroup join verify + LoadSource zero-API + stale a11y fix) + des-1 (Tasks 4-5: header aiProgressHeader + xóa content/sheet spinner) + Task 6 full verify done 2026-09-04.
- Evidence: `./init.sh` full PASS (format 0/lint 0/build PASS/test ** TEST SUCCEEDED ** incl. AIClientTests 12/12, AIReadingServiceTests 11/11, Prefetch 7/7+6/6, ReaderHeaderSpinnerTests 3/3, ReaderViewFixTests 18/18/drift PASS); plan `docs/plans/feat-018.md`.
- Blockers: none (working tree vẫn giữ uncommitted gộp feat-015/016/017 + feat-018 — chưa commit vì user chưa yêu cầu).
- Next: repo idle — user retest thiết bị thật: ch22 fail → toast + raw + header tắt; vào Nhật ký back lại zero-API; đổi chapter prefetch sequential.
- Follow-up 2026-09-04: header thêm text "Đang xử lý" (caption, muted) ngay phải spinner trong cùng HStack height 28 — quick PASS + HeaderSpinner/ViewFix 22/22 + A11y/Regression PASS.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
