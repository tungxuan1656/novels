# feat-029 — Chapter scroll reset on swipe

## Goal

Vuốt ngang sang chapter mới luôn mở ở đầu chapter, kể cả khi vuốt nhanh trong lúc ScrollView còn quán tính dọc.

## Scope

- `apps/novels/Features/Reading/ReaderView.swift`: ép `ScrollView` tạo identity mới theo `chapterNumber` để triệt quán tính + state cuộn cũ.
- Giữ nguyên `scrollToTop()` hiện tại làm backup, giữ nguyên `restoreOffset()` cho return-from-log.

## Non-goals

- Không đổi gesture, throttle, `EdgeSwipeDecision`, `ReaderViewModel.goNext/goPrev/load`.
- Không đổi behavior khi đổi `aiMode` trong cùng chapter.
- Không thêm debounce/timer/delay hack, không commit/PR trừ khi user yêu cầu.

## Acceptance

- [x] Vuốt ngang nhanh ở cuối chapter sang chapter mới luôn ở top, không giữ offset cũ.
- [x] Bấm prev/next vẫn về top như cũ.
- [x] Quay lại cùng chapter (return-from-log) vẫn restore offset đã lưu.
- [x] `./init.sh --quick` PASS.

## Relevant docs

- `docs/product/functional-specs/book-reader.md`
- `docs/design/screens.md`
- `ARCHITECTURE.md` §1/§5

## Plan

Bounded inline: 1 file, 1 dòng, 1 workspace, <200 lines.

### Task 1: Reset ScrollView theo chapter

File: `apps/novels/Features/Reading/ReaderView.swift` (khối `ScrollViewReader { proxy in ... ScrollView { ... } .scrollPosition(...)`, hiện ~dòng 46-71).

Change duy nhất — gắn identity theo chapter lên chính `ScrollView`:
- Tìm `ScrollView {` nằm trực tiếp trong `ScrollViewReader`.
- Thêm modifier `.id(viewModel.chapterNumber)` lên `ScrollView` đó (đặt ngay sau `ScrollView { ... }` closing, trước hoặc sau `.scrollPosition`, miễn là trên `ScrollView`, ví dụ `.scrollPosition($scrollPosition).id(viewModel.chapterNumber)`).

Giá trị chuẩn (dùng verbatim): `viewModel.chapterNumber`. Không đặt id lên inner `VStack`, không gộp `aiMode` vào id, không đổi `"top"`/`"bottom"` ids.

Constraints:
- Chỉ chạm `ReaderView.swift`, đúng 1 thay đổi identity này. Không sửa gesture, ViewModel, throttle, debounce, `scrollToTop`, `restoreOffset`.
- Giữ `scrollPosition = .zero` + `scrollTo("top")` hiện tại nguyên vẹn.
- Không thêm file, dependency, timer, Task.sleep, animation mới.
- Chạy `swiftformat`/`swiftlint` sạch cho file chạm (qua `./init.sh --quick`).

Verify cho Task 1: `./init.sh --quick` PASS + `git diff --stat` chỉ 1 file.

## Verify

- `./init.sh --quick` (Task 1): PASS — format 0/57, lint 0 violations, drift 21/22
- Full `./init.sh`: PASS — format 0/57, lint 0, build PASS iPhone 17 Pro iOS 26.5, drift PASS 21/22, `=== Verification passed ===`
- Task review (@oracle): Spec ✅ Approved, 1 minor deferred (feature_index attribution, không chạm code)
- `git diff`: `ReaderView.swift | 1 +` (`.id(viewModel.chapterNumber)` lên ScrollView) + setup `feature_index.json` (+6)

## Handoff

- State: done
- Evidence: SDD Task 1 report + review-task1.diff + full `./init.sh` PASS trên
- Blockers: none
- Next: commit + PR branch `fix/029-chapter-scroll-reset` khi user yêu cầu; user tự vuốt kiểm tra trên máy thật.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
