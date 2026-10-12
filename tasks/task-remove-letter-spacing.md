# Remove Letter Spacing (Gian chu)

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-005](task-settings-cache-manager.md)
- Required to integrate/release: none
- Previous ID: feat-027

## Scope and non-goals

Completely remove letter spacing ("Giãn chữ") from Reader typography, Settings, persistence, tests, and documentation while preserving line height ("Giãn dòng"):
- Domain & Persistence: Remove `letterSpacing` property from `TypographySetting`, remove key from `DefaultsKeys`, and purge sanitize/save/load paths in `SettingsStore.swift`. Legacy stored keys are ignored on load without migration.
- Reader Interface: Remove "Giãn chữ" stepper and clamp logic in `ReaderBottomSheet.swift`. Remove `.kerning()` modifiers across all reader rendering paths in `ReaderView.swift`, keeping `.lineSpacing(lineHeight)`.
- Settings: Remove `letterSpacing` descriptor and validation from `SettingsViewModel.swift`.
- Purge documentation across settings schemas, local data contracts, design systems, screens, and functional specifications.

Non-goals: No changes to font family, font size, line height ("Giãn dòng"), reading themes, or layout spacing tokens; no persistent migration routine.

## Acceptance

- [x] No "Giãn chữ" string in Swift code or UI; no `letterSpacing` identifier in `apps/novels` Swift sources.
- [x] No `.kerning(` in Reader render paths; line height still applies via `.lineSpacing`.
- [x] No `letterSpacing` key in `DefaultsKeys`, `SettingsStore`, or `SettingsViewModel`.
- [x] Tests updated and pass; no orphan letterSpacing assertions.
- [x] Docs contain no letterSpacing contract; typography lists font/size/lineHeight only.
- [x] `./init.sh --quick` PASS; build PASS; targeted typography/settings tests PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/design/design-system.md](../docs/design/design-system.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [docs/product/domain-model.md](../docs/product/domain-model.md)
- [docs/product/glossary.md](../docs/product/glossary.md)
- [apps/novels/Domain/TypographySetting.swift](../apps/novels/Domain/TypographySetting.swift)
- [apps/novels/Persistence/SettingsStore.swift](../apps/novels/Persistence/SettingsStore.swift)
- [apps/novels/Features/Reading/ReaderBottomSheet.swift](../apps/novels/Features/Reading/ReaderBottomSheet.swift)
- [apps/novels/Features/Reading/ReaderView.swift](../apps/novels/Features/Reading/ReaderView.swift)

## Verification and handoff

- Evidence: Historical verification completed with recorded timeout nuance: `./init.sh --quick` passed cleanly (format, lint, drift check 21/22); `xcodebuild build` passed; targeted test suites passed (`TypographySheetTests`, `SettingsStoreTests`, `DomainCodableTests`, `SettingsEditorValidationTests`, `SettingsStoreCoercionTests`). Full `./init.sh` timed out and was aborted twice; no failure was observed, but no full pass was established. Historical `done` is retained from the owner-approved legacy state, not re-certified during migration. Codebase greps confirmed zero occurrences of `letterSpacing` or `.kerning` in production code.
- Blockers: None.
- Next: HISTORICAL: Manual verification of typography sheet confirming letter spacing removal while line height remains functional.
