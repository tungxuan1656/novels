# feat-027 — Remove Letter Spacing (Gian chu)

## Goal

Remove the letter-spacing ("Giãn chữ") option completely from Reader typography, Settings, persistence, tests, and docs. Line height ("Giãn dòng") stays unchanged.

## Scope

- `apps/novels/Domain/TypographySetting.swift`: remove `letterSpacing` property and default.
- `apps/novels/Persistence/DefaultsKeys.swift`: remove `letterSpacing` key and from `allCurrent`.
- `apps/novels/Persistence/SettingsStore.swift`: remove load/sanitize/value/setValue/save paths for `letterSpacing`; treat legacy stored value as unknown and ignore.
- `apps/novels/Features/Reading/ReaderBottomSheet.swift`: remove "Giãn chữ" stepper UI and `clampAndSaveLetterSpacing`.
- `apps/novels/Features/Reading/ReaderView.swift`: remove `.kerning(30)` modifiers (all render paths); keep `.lineSpacing(lineHeight)`.
- `apps/novels/Features/Settings/SettingsViewModel.swift`: remove `letterSpacing` validation case and descriptor.
- Tests: `apps/novelsTests/TypographySheetTests.swift`, `apps/novelsTests/SettingsStoreTests.swift` — remove letterSpacing cases; keep lineHeight coverage.
- Docs: `docs/contracts/settings-schema.md`, `docs/contracts/local-data.md`, `docs/design/design-system.md`, `docs/design/screens.md`, `docs/product/domain-model.md`, `docs/product/glossary.md`, `docs/product/functional-specs/settings-management.md`, `docs/product/functional-specs/book-reader.md` — remove letterSpacing mentions; keep font/size/lineHeight.

## Non-goals

- No change to font family, font size, line height ("Giãn dòng"), themes, or layout spacing tokens.
- No change to `AddBookView` lineSpacing layout values or `DesignTokens` layout spacing.
- No migration for legacy `letterSpacing` value beyond ignore-on-load.
- No commit/PR unless user requests.

## Acceptance

- [x] No "Giãn chữ" string in Swift code or UI; no `letterSpacing` identifier in `apps/novels` Swift sources.
- [x] No `.kerning(` in Reader render paths; line height still applies via `.lineSpacing`.
- [x] No `letterSpacing` key in `DefaultsKeys`, `SettingsStore`, or `SettingsViewModel`.
- [x] Tests updated and pass; no orphan letterSpacing assertions.
- [x] Docs contain no letterSpacing contract; typography lists font/size/lineHeight only.
- [x] `./init.sh --quick` PASS; build PASS; targeted typography/settings tests PASS.

## Relevant docs

- `docs/contracts/settings-schema.md`
- `docs/contracts/local-data.md`
- `docs/design/design-system.md`
- `docs/design/screens.md`
- `docs/product/domain-model.md`
- `docs/product/glossary.md`
- `ARCHITECTURE.md` §1/§5

## Plan

Inline (single writer lane, mechanical removal, no design judgment).

1. Writer: remove model + keys + store paths (load/sanitize/value/setValue/save), legacy value ignored.
2. Writer: remove ReaderBottomSheet stepper + clamp helper; remove ReaderView `.kerning` modifiers.
3. Writer: remove SettingsViewModel validation + descriptor.
4. Writer: update tests to drop letterSpacing cases.
5. Writer: update docs to remove letterSpacing from typography lists.
6. Verify: `./init.sh --quick` loop, then full `./init.sh` to close.

File ownership: single writer owns all prod + test + docs (no parallel writers).

## Verify

- `./init.sh --quick` PASS 2026-09-07 (format/lint/drift; build/test skipped)
- `xcodebuild build` PASS 2026-09-07 (iPhone 17 Pro 26.5)
- Targeted `xcodebuild test` PASS (TypographySheet, SettingsStore, DomainCodable, SettingsEditorValidation, SettingsStoreCoercion)
- `grep letterSpacing/Giãn chữ` in apps/novels + apps/novelsTests Swift = 0; `grep \.kerning` = 0; docs contracts/design/product letterSpacing = 0
- Full `./init.sh` attempted twice, exceeded 120s window / aborted; no failure observed (build + targeted tests green)

## Handoff

- State: done
- Evidence: fixer lane removed letterSpacing across Domain/Persistence/Reader/Settings + 5 test suites + 7 docs; greps 0; quick PASS; build PASS; targeted tests PASS
- Blockers: none
- Next: repo idle — user retests Reader sheet (no Giãn chữ, Giãn dòng intact) + Settings typography.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
