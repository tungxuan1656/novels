# feat-026 — Reading Themes Full 5 (Sách / Xanh dịu / Xanh lam / Đêm / AMOLED)

## Goal

Mở rộng màn đọc từ trio (feat-021) lên full 5 themes theo palette user đã chốt, persist offline, reader + sheet đồng bộ, đủ contrast WCAG AA cho đọc lâu.

Approved bg/text (user chốt Full 5):

| Theme | bg/header | text | Cảm giác |
|---|---|---|---|
| Sách (default) | `#F7F1E3` | `#38342E` | Ấm, giống sách giấy |
| Xanh dịu | `#EEF3F0` | `#29332F` | Mát, thư giãn, nhận diện riêng |
| Xanh lam nhạt | `#EEF4F8` | `#29343B` | Sạch, nhẹ, hiện đại |
| Đêm | `#1C1C1E` | `#D2D2D2` | Dịu khi đọc tối |
| AMOLED | `#000000` | `#C8C8C8` | Tối sâu |

Không dùng nền vàng đậm / xanh đậm / tím đậm cho nền đọc chính (chỉ làm accent).

## Scope

- `apps/novels/Domain/ReadingTheme.swift`: enum 5 cases (`sach/xanhDiu/xanhLam/dem/amoled`), Codable, default `sach`, title VI (`Sách/Xanh dịu/Xanh lam/Đêm/AMOLED`).
- `apps/novels/Persistence/DefaultsKeys.swift`: giữ key `readingTheme` + `allCurrent` (không đổi key).
- `apps/novels/Persistence/SettingsStore.swift`: default `sach`; load/save/coerce unknown/non-string/legacy trio (`vangGiay/trang/den`) → `sach`. Không migration map riêng (đúng luật settings-schema hiện tại).
- `apps/novels/Resources/DesignTokens.swift`: full palette/theme (background/header/textPrimary/textMuted-iconTint/chipBackground/borderColor/accentColor + scheme + disabledOpacity). bg/text giữ nguyên số approved; muted/chip/border/accent do designer chốt sao cho đạt AA (text 4.5:1, icon 3:1) và đọc lâu nhẹ mắt.
- `apps/novels/Features/Reading/ReaderView.swift`: giữ dùng theme tokens; chỉ sửa nếu cần (scope `preferredColorScheme` Reader-only giữ nguyên).
- `apps/novels/Features/Reading/ReaderBottomSheet.swift`: section `Màu nền` redesign cho 5 swatch (designer owns layout: size/spacing/wrap/scroll), giữ live-update + haptic + a11y VI + ring accent 2.5pt + check + divider theme border + force scheme.
- `apps/novelsTests/ReadingThemeTests.swift`: update default/round-trip/fallback/palette-contract/sheet-contract cho 5 themes; legacy trio fallback test.
- Docs: `docs/contracts/settings-schema.md` + `docs/design/design-system.md` (bảng 5 themes + nguyên tắc scheme/disabled như feat-021).

## Non-goals

- Không đổi Library/Settings/Cache/AI/Prefetch/Log ngoài Reader theme.
- Không chạm `SharedUI/BottomSheetView.swift`.
- Không đổi key `readingTheme`, không Keychain/SwiftData, không đổi TARGETED_DEVICE_FAMILY/ATS.
- Không thêm theme thứ 6, không chỉnh font/size/line-height.

## Acceptance

- [x] 5 cases Codable, default `sach`; key `readingTheme`; unknown/non-string/legacy (`vangGiay/trang/den`) → `sach`; relaunch nhớ theme.
- [x] bg/text giữ nguyên từng số approved (5 cặp trên); scheme: `sach/xanhDiu/xanhLam` → `.light`, `dem/amoled` → `.dark`; disabled opacity 0.35 light / 0.42 dark.
- [x] Body contrast AA (≥4.5:1) cho cả 5 themes; muted/icon đạt AA trên nền tương ứng (đặc biệt 2 dark).
- [x] `ReaderView` full theme tokens + `preferredColorScheme` scoped Reader-only; không còn `backgroundPaper`/`systemGray5` cho chrome đọc.
- [x] Sheet `Màu nền` hiển thị đủ 5 options, tap đổi live + haptic, a11y VI (`themePicker`, `theme-<rawValue>`, hint `Chọn màu nền …`), divider theme border, sheet không chói khi dark + máy Light.
- [x] Docs cập nhật bảng 5 themes; `./init.sh` full PASS.

## Relevant docs

- `docs/contracts/settings-schema.md`
- `docs/design/design-system.md`
- `docs/design/screens.md` §3 (Bottom Sheet)
- `ARCHITECTURE.md` §1/§5
- `features/feat-021.md` (trio cũ, để đối chiếu migration)

## Plan

Inline (1 writer lane, designer-first vì cần chốt palette phụ + layout picker 5).

1. Designer: chốt muted/chip/border/accent cho 5 themes (AA) + layout picker 5 (size/wrap/scroll) + scheme/disabled rule.
2. Writer: `ReadingTheme.swift` + `SettingsStore` (default/coerce incl. legacy trio) + `DefaultsKeys` (nếu cần).
3. Writer: `DesignTokens.swift` palette 5 themes exact hex.
4. Writer: `ReaderBottomSheet.swift` picker 5 + theme hóa + force scheme; `ReaderView.swift` nếu cần.
5. Writer: `ReadingThemeTests.swift` update + docs 2 files.
6. Verify: `./init.sh --quick` loop, full `./init.sh` để close.

File ownership: single writer owns all prod + test + docs (no parallel writers).

## Verify

- `./init.sh --quick` (loop)
- `./init.sh` (full để close)
- `grep -rn readingTheme apps/novels --include=*.swift`
- Contrast check: tính ratio bg/text + muted/bg cho 5 themes (ghi evidence)

## Handoff

- State: done
- Evidence: `apps/novels/Domain/ReadingTheme.swift` (5 cases + title VI), `Resources/DesignTokens.swift` (full palette: bg/text approved + muted `#655C4E/#55645D/#55636E/#A8A8A8/#A0A0A0`, chip, border, accent `#2563EB` light / `#7AB8FF` dark), `Persistence/SettingsStore.swift` (default `.sach`, legacy trio → `.sach`), `Features/Reading/ReaderBottomSheet.swift` (picker 5-across 42pt), `apps/novelsTests/ReadingThemeTests.swift`, docs `settings-schema.md` + `design-system.md` (bảng 5 themes); contrast body 11-12.5 (AAA), muted ≥4.5; `./init.sh` full PASS (format/lint/build/test incl. UITests/drift); version bump 1.0.3 → 1.0.4 (`project.pbxproj` novels Debug/Release).
- Blockers: none
- Next: repo idle — user retest 5 themes live + relaunch persist + dark + máy Light trên Simulator; PR tạo từ branch `feat/026-reading-themes-full-5`.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
