# feat-021 — Reading Themes Trio (Vàng giấy / Trắng / Đen)

## Goal

Màn đọc có 3 theme nền chọn tay (Vàng giấy mặc định / Trắng / Đen), persist offline, reader + sheet đồng bộ theo theme, đủ contrast WCAG AA cho body.

## Scope

- `apps/novels/Domain/ReadingTheme.swift` (new): enum `vangGiay/trang/den`, Codable, default `vangGiay`, title VI.
- `apps/novels/Persistence/DefaultsKeys.swift`: key `readingTheme` + `allCurrent`.
- `apps/novels/Persistence/SettingsStore.swift`: `var readingTheme`, load/save/coerce unknown → `vangGiay`. UserDefaults-only, no SwiftData/Keychain.
- `apps/novels/Resources/DesignTokens.swift`: per-theme palette extension (giữ non-reader tokens untouched). Hex giữ nguyên approved.
- `apps/novels/Features/Reading/ReaderView.swift`: thay `backgroundPaper/text/muted/systemGray5` bằng theme tokens; scope `preferredColorScheme` (.light Vàng/Trắng, .dark Đen) cho Reader stack; disabled opacity 0.35 light / 0.42 dark, giữ `.disabled`.
- `apps/novels/Features/Reading/ReaderBottomSheet.swift`: section đầu `Màu nền`, HStack 3 VStack (swatch 48pt + label VI), selected ring accent 2.5pt + check + semibold, unselected ring theme border, tap live-update + haptic nhẹ, no Save, a11y VI, force sheet colorScheme, divider dùng theme border.
- `apps/novelsTests/ReadingThemeTests.swift` (new): default/round-trip/unknown-fallback/palette-contract.
- `docs/contracts/settings-schema.md` + `docs/design/design-system.md`: thêm `readingTheme`, resolve drift `#FDFCF8` → giữ code `#F5F1E5`.

## Non-goals

- Không đổi Library/Settings/Cache/AI/Prefetch/Log ngoài Reader.
- Không chạm `SharedUI/BottomSheetView.swift` (handle giữ nguyên, đã đồng bộ gián tiếp qua forced scheme).
- Không migration legacy, không Keychain/SwiftData, không đổi TARGETED_DEVICE_FAMILY/ATS.

## Acceptance

- [x] `ReadingTheme` Codable `vangGiay/trang/den`, default `vangGiay`; `UserDefaults` key `readingTheme`; unknown/non-string → `vangGiay`; relaunch vẫn nhớ.
- [x] Hex giữ nguyên từng số: Vàng bg/header `#F5F1E5` text `#111111` muted/icon `#6B7280` chip `#E8DDC0` border `#DCD2B6` accent `#2563EB`; Trắng bg/header `#FFFFFF` text `#111111` muted/icon `#6B7280` chip `#EFEFF1` border `#E5E7EB` accent `#2563EB`; Đen bg/header `#171512` text `#ECE7DF` muted/icon `#A8A29E` chip `#2A2724` border `#3B3732` accent `#60A5FA`.
- [x] `ReaderView` không còn `backgroundPaper`/`systemGray5` cho chrome đọc; body/muted/chip/border/accent lấy từ theme; `preferredColorScheme` scoped Reader only.
- [x] Disabled prev/next opacity 0.35 (Vàng/Trắng) / 0.42 (Đen), giữ `.disabled`.
- [x] `ReaderBottomSheet` có section `Màu nền` đầu tiên, 3 swatch 48pt + nhãn `Vàng giấy/Trắng/Đen`, selected ring accent 2.5pt + check + semibold, tap đổi live + haptic, a11y VI, divider theme border, sheet không chói khi Đen + máy Light.
- [x] Docs cập nhật, drift `#FDFCF8` resolved về `#F5F1E5`.
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/contracts/settings-schema.md:20-22`
- `docs/contracts/local-data.md` (UserDefaults-only)
- `docs/design/design-system.md`
- `ARCHITECTURE.md` §1/§5
- `AGENTS.md` (harness)

## Plan

Inline (per orchestrator directive — single writer lane, không tách `docs/plans/`).

1. Orchestrator: baseline `./init.sh --quick`, tạo `feat-021.md` + `feature_index.json` active.
2. Writer: `Domain/ReadingTheme.swift` + `DefaultsKeys` + `SettingsStore` (load/save/coerce).
3. Writer: `DesignTokens.swift` palette extension (8 token/theme + scheme + disabledOpacity).
4. Writer: `ReaderView.swift` thay tokens + preferredColorScheme + disabled opacity.
5. Writer: `ReaderBottomSheet.swift` picker + theme hóa text/divider + force scheme.
6. Writer: `ReadingThemeTests.swift` + docs (`settings-schema.md`, `design-system.md`).
7. Writer: `./init.sh --quick` loop, full `./init.sh` để close, cập nhật feature done + `progress.md`.

File ownership: single writer owns all (no parallel).

## Verify

- `./init.sh --quick` (loop)
- `./init.sh` (full để close)
- `grep -rn readingTheme apps/novels --include=*.swift`
- `grep -rn "0xF5F1E5\|0xE8DDC0\|0x171512\|0x60A5FA" apps/novels/Resources --include=*.swift`

## Handoff

- State: done
- Evidence: `apps/novels/Domain/ReadingTheme.swift` (vangGiay/trang/den + title VI), `Persistence/DefaultsKeys.swift` key `readingTheme`, `Persistence/SettingsStore.swift` load/save/coerce + `loadDiagnosticsTypographySession` refactor (fix function_body_length), `Resources/DesignTokens.swift` palette extension exact hex + scheme + disabledOpacity, `Features/Reading/ReaderView.swift` theme tokens + preferredColorScheme Reader-only + disabled 0.35/0.42, `Features/Reading/ReaderBottomSheet.swift` section `Màu nền` + 3 swatch 48pt + ring 2.5pt + haptic + a11y VI + theme border + force scheme, `apps/novelsTests/ReadingThemeTests.swift` 6/6, `docs/contracts/settings-schema.md` + `docs/design/design-system.md` (drift `#FDFCF8`→`#F5F1E5`); `./init.sh` full PASS 2026-09-05 (format 0/96, lint 0/96, build PASS, test PASS incl. ReadingTheme 6/6 + UITests, drift PASS 21/22); `feature_index.json` feat-021 done (zero active).
- Blockers: none (tree còn uncommitted các feat trước + feat-021 — chưa commit theo quy tắc, chờ user yêu cầu).
- Next: repo idle — user retest trên Simulator: đổi 3 theme live, relaunch nhớ theme, Đen + máy Light sheet không chói.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
