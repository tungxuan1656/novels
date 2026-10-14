# Bilingual Partial Language Hiding

- Status: active
- Owner: Agent
- Required to start: none
- Required to integrate/release: `./init.sh` passing

## Scope and Non-goals

Scope:
- In Reader bottom sheet (under bilingual mode settings), add a control under "Ngôn ngữ chính" (Primary Language).
- Name: "Ẩn một phần".
- Values: "Không", "Tiếng Việt", "Tiếng Anh".
- Rule: When hiding one language, default/switch the primary language to the remaining visible language.
- Reading view: Render only the non-hidden language when a partial hide option is active.
- Non-goals: Monolingual reading modes unaffected; underlying translation cache unchanged.

## Acceptance

- [ ] "Ẩn một phần" picker appears in reader bottom sheet when bilingual mode is active, positioned directly below "Ngôn ngữ chính".
- [ ] Values provided: "Không", "Tiếng Việt", "Tiếng Anh".
- [ ] Selecting "Tiếng Việt" hides Vietnamese paragraphs/sentences and ensures English is set as primary language.
- [ ] Selecting "Tiếng Anh" hides English paragraphs/sentences and ensures Vietnamese is set as primary language.
- [ ] Selecting "Không" displays both languages as normal.
- [ ] If primary language is changed while a language is hidden or if hiding is selected, the primary language rule is upheld.
- [ ] Settings persist appropriately.
- [ ] Unit tests added/updated for hiding logic and primary language auto-switch.
- [ ] Full `./init.sh` passes.

## Sources and Plan

- Reader bottom sheet view: `apps/novels/Features/Reading/ReaderBottomSheet.swift`.
- Bilingual reader view: `apps/novels/Features/Reading/BilingualReaderBody.swift` and `ReaderView.swift`.
- Settings & Persistence: `apps/novels/Persistence/SettingsStore.swift`, `DefaultsKeys.swift`, and new domain model `BilingualHideOption.swift`.
- Unit tests: `apps/novelsTests/BilingualSettingsTests.swift`.

### Step-by-step Plan
1. **Domain Model & Persistence**:
   - Create `apps/novels/Domain/BilingualHideOption.swift` with cases `.none`, `.vietnamese`, `.english` and localized titles ("Không", "Tiếng Việt", "Tiếng Anh").
   - Update `DefaultsKeys.swift` to register `bilingualHideOption`.
   - Update `SettingsStore.swift` to load/save `bilingualHideOption` and implement `setBilingualHideOption(_ option: BilingualHideOption)` that automatically switches `bilingualEnglishPrimary`:
     - `.vietnamese` -> `bilingualEnglishPrimary = true`
     - `.english` -> `bilingualEnglishPrimary = false`
     - `.none` -> preserves existing primary language.
   - Commit: `feat(settings): add bilingual partial hide option and primary language synchronization`
2. **Reader Bottom Sheet UI**:
   - Update `ReaderBottomSheet.swift` in `bilingualLanguageSection`:
     - Add "Ẩn một phần" segmented picker directly below "Ngôn ngữ chính".
     - Disable/dim primary language swap button when a language is hidden to avoid contradictory state.
   - Commit: `feat(reader): add partial hide picker to bilingual reader bottom sheet`
3. **Reader Body Rendering**:
   - Update `BilingualReaderBody.swift` to accept `hideOption: BilingualHideOption`.
   - Conditionally render paragraphs:
     - Hide Vietnamese when `hideOption == .vietnamese`.
     - Hide English when `hideOption == .english`.
     - Show both when `hideOption == .none`.
   - Update `ReaderView.swift` to pass `settingsStore.bilingualHideOption` to `BilingualReaderBody`.
   - Commit: `feat(reader): support hiding vietnamese or english in bilingual view`
4. **Unit Tests & Verification**:
   - Add comprehensive tests in `BilingualSettingsTests.swift` covering `BilingualHideOption`, persistence, and automatic primary language switching.
   - Run `./init.sh` (format, lint, build, focused unit tests).
   - Commit: `test(bilingual): add tests for bilingual hide option and language synchronization`

## Verification and Handoff

- Evidence: to be captured after `./init.sh`.
- Delivery: commits on `feat/bilingual-partial-hide`.
