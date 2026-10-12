# Reading Themes Full 5-Palette Expansion

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-021](task-reader-theme-trio.md)
- Required to integrate/release: none
- Previous ID: feat-026

## Scope and non-goals

Expand the reader theme system from the 3-theme trio in [task-reader-theme-trio](task-reader-theme-trio.md) to a full 5-theme palette meeting WCAG AA contrast standards:
- Domain model: enum `ReadingTheme` with 5 cases: `sach` (Paper Book, default `#F7F1E3` / `#38342E`), `xanhDiu` (Soft Mint `#EEF3F0` / `#29332F`), `xanhLam` (Light Blue `#EEF4F8` / `#29343B`), `dem` (Night `#1C1C1E` / `#D2D2D2`), and `amoled` (AMOLED Black `#000000` / `#C8C8C8`).
- Persistence and backward compatibility: retain `readingTheme` key in `UserDefaults`; coerce legacy trio cases (`vangGiay`, `trang`, `den`) and unknown strings gracefully to default `sach`.
- Design tokens: define complete palettes for all 5 themes in `DesignTokens.swift` (background, header, primary text, muted text, chip background, borders, and accents) ensuring text contrast >= 4.5:1 and icons >= 3:1.
- Interface update: redesign bottom sheet "Màu nền" section for 5 swatches with live preview, haptic feedback, accessibility labels, and scoped `preferredColorScheme` (.light for Book/Mint/Blue, .dark for Night/AMOLED).

Non-goals: No changes to non-reader screens; no changes to font sizes, line heights, or typography beyond colors; no addition of a sixth theme.

## Acceptance

- [x] 5 cases Codable, default `sach`; key `readingTheme`; unknown/non-string/legacy (`vangGiay/trang/den`) → `sach`; relaunch remembers theme.
- [x] bg/text hex colors strictly adhere to approved specifications; colorScheme: `sach/xanhDiu/xanhLam` → `.light`, `dem/amoled` → `.dark`; disabled opacity 0.35 light / 0.42 dark.
- [x] Body text contrast AA (≥4.5:1) for all 5 themes; muted/icon contrast AA on corresponding backgrounds.
- [x] `ReaderView` implements full theme tokens and `preferredColorScheme` scoped to reader only.
- [x] Sheet "Màu nền" displays all 5 options, switches live with haptics, provides full accessibility identifiers, and preserves contrast in light/dark system modes.
- [x] Documentation updated with 5-theme specification; `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/design/design-system.md](../docs/design/design-system.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Domain/ReadingTheme.swift](../apps/novels/Domain/ReadingTheme.swift)
- [apps/novels/Resources/DesignTokens.swift](../apps/novels/Resources/DesignTokens.swift)
- [apps/novels/Features/Reading/ReaderBottomSheet.swift](../apps/novels/Features/Reading/ReaderBottomSheet.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, unit tests (`ReadingThemeTests` 11/11 covering all 5 themes, palette contrast contracts, and legacy trio fallback), and drift checks. Superseded the earlier 3-theme system from [task-reader-theme-trio](task-reader-theme-trio.md).
- Blockers: None.
- Next: HISTORICAL: Manual testing on Simulator: testing all 5 themes, relaunch persistence, and dark sheet appearance when system mode is light.
