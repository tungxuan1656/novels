# Reading Themes Trio (Paper Sepia / White / Dark)

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-005](task-settings-cache-manager.md)
- Required to integrate/release: none
- Previous ID: feat-021

## Scope and non-goals

Provide a 3-theme palette picker (Paper Sepia / White / Dark) for the reader screen with offline persistence, synchronized reader chrome, and WCAG AA contrast:
- Domain model: enum `ReadingTheme` with cases `vangGiay` (default), `trang`, and `den`, Codable with localized Vietnamese display names. Note: this 3-theme selection was subsequently expanded and superseded by [task-reader-five-themes](task-reader-five-themes.md).
- Settings persistence: key `readingTheme` stored in `UserDefaults` via `SettingsStore`, falling back gracefully to `vangGiay` for missing or invalid values.
- Design tokens: theme-specific color tokens in `DesignTokens.swift` covering background, text, muted elements, chips, borders, and accents.
- Reader interface: update `ReaderView` and `ReaderBottomSheet` to dynamically apply theme tokens, scope `preferredColorScheme` (.light for Sepia/White, .dark for Dark) to the reader stack, and render 48pt color swatches with selected accent rings and haptic feedback.

Non-goals: No changes to Library, Settings, AI, Prefetch, or Diagnostics screens; no Keychain or database migrations; no changes to bottom sheet handle presentation.

## Acceptance

- [x] `ReadingTheme` Codable `vangGiay/trang/den`, default `vangGiay`; `UserDefaults` key `readingTheme`; unknown/non-string → `vangGiay`; relaunch still remembers choice.
- [x] Hex colors match specification: Sepia bg/header `#F5F1E5` text `#111111` muted/icon `#6B7280` chip `#E8DDC0` border `#DCD2B6` accent `#2563EB`; White bg/header `#FFFFFF` text `#111111` muted/icon `#6B7280` chip `#EFEFF1` border `#E5E7EB` accent `#2563EB`; Dark bg/header `#171512` text `#ECE7DF` muted/icon `#A8A29E` chip `#2A2724` border `#3B3732` accent `#60A5FA`.
- [x] `ReaderView` removes legacy paper background and system gray tokens; body, muted, chip, border, and accent derive from theme; `preferredColorScheme` scoped to reader only.
- [x] Disabled navigation buttons have opacity 0.35 (Sepia/White) or 0.42 (Dark), keeping `.disabled` modifier.
- [x] `ReaderBottomSheet` includes top "Màu nền" section with 3 swatches (48pt) and Vietnamese labels, 2.5pt accent ring when selected, live update with haptics, and accessible labels.
- [x] Documentation updated; resolved `#FDFCF8` design drift to canonical `#F5F1E5`.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/design/design-system.md](../docs/design/design-system.md)
- [apps/novels/Domain/ReadingTheme.swift](../apps/novels/Domain/ReadingTheme.swift)
- [apps/novels/Resources/DesignTokens.swift](../apps/novels/Resources/DesignTokens.swift)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS (format 0/96, lint 0/96, build PASS, unit tests passed including `ReadingThemeTests` 6/6 and UI tests, drift PASS). This 3-theme trio palette was later expanded into a 5-theme system in [task-reader-five-themes](task-reader-five-themes.md).
- Blockers: None.
- Next: HISTORICAL: Manual testing on Simulator: switching among the 3 themes, relaunch persistence, and dark sheet appearance in light mode.
