# Implementation Plan — feat-011: AI Prompt Setting & Inline Rewrite Reading Sheet

## Overview

Refactor AI settings and reading modes:
1. Replace `AI_PROCESS_ACTIONS` setting key with single `AI_PROMPT` setting (label "Prompt", multiline).
2. Change `AIMode` from `(none, translate, summary)` to `(none, rewrite)` representing "Không" and "Rewrite".
3. Update `AIPromptBuilder` and `AIReadingService` to build prompts and process chapters using `AI_PROMPT` under mode `.rewrite`.
4. Update `ReaderBottomSheet` UI: display "AI Rewrite" with inline segmented picker ("Không" / "Rewrite") and "Xử lý lại" button placed side-by-side.
5. Update unit tests to reflect updated setting key, modes, prompt builder, and view model behavior.

## User Requirements & Acceptance Criteria

- **Setting Key**: "Prompt" (key `AI_PROMPT` in `DefaultsKeys` / `SettingsStore`). Label in Settings list: "Prompt". Description/Placeholder indicates system prompt for translation, summarization, or rewriting.
- **Reading Sheet UI**: Display label "AI Rewrite", inline picker with 2 options: "Không" (`.none`) and "Rewrite" (`.rewrite`). Right beside the inline picker, display the "Xử lý lại" (Reprocess) button in the same row.
- **Mode Execution**: Mode `.none` renders raw chapter text. Mode `.rewrite` checks cache for `(bookId, chapter, "rewrite")` or calls `AIReadingService` using configured system prompt `AI_PROMPT`.

## Plan Tasks

### Task 1: Domain & Persistence Refactor (`AIMode`, `DefaultsKeys`, `SettingsStore`, `SettingsModels`)
- Update `AIMode` enum: cases `.none`, `.rewrite`. Raw values `"none"`, `"rewrite"`. Add display titles: `title` -> "Không" / "Rewrite".
- Update `DefaultsKeys`: replace `aiProcessActionsJSON` with `aiPrompt = "AI_PROMPT"`.
- Update `SettingsStore`:
  - Replace `aiProcessActionsJSON: String` with `aiPrompt: String`.
  - Default value `SettingsDefaults.defaultPrompt`: `"Dịch truyện sang tiếng Việt tự nhiên, giữ nguyên xưng hô (ta, ngươi, huynh, đệ...), bảo tồn 100% nội dung và văn phong."`
  - Update `load()`, `sanitize()`, `setValue(_:forKey:)`, `value(forKey:)`.
- Update `SettingsModels`: remove `AIAction` if no longer used or retain simplified model; update `SettingDescriptor` for key `"AI_PROMPT"`.

### Task 2: AI Services Refactor (`AIPromptBuilder`, `AIReadingService`, `PrefetchManager`)
- `AIPromptBuilder`: simplified method `prompt(for mode: AIMode, systemPrompt: String) -> String`. If mode is `.none`, return `""`. If `systemPrompt` is empty, use `SettingsDefaults.defaultPrompt`.
- `AIReadingService`: pass system prompt to `AIPromptBuilder`. Use mode `.rewrite` for cache key when rewrite mode is active.
- `PrefetchManager`: prefetch is eligible when `mode != .none` (i.e. `mode == .rewrite`).

### Task 3: Settings UI Refactor (`SettingsView`, `SettingsViewModel`, `SettingEditorView`)
- `SettingsView`: replace row `key: "AI_PROCESS_ACTIONS"` with `key: "AI_PROMPT"`, label `"Prompt"`.
- `SettingsViewModel`: descriptor for `"AI_PROMPT"` (label `"Prompt"`, multiline editor, non-JSON, default `SettingsDefaults.defaultPrompt`).
- `SettingEditorView`: support multiline string input for `"AI_PROMPT"`.

### Task 4: Reading Sheet & ViewModel Refactor (`ReaderBottomSheet`, `ReaderViewModel`, `ReaderView`)
- `ReaderViewModel`: `aiMode` defaults to `.none`. `setAIMode(_:)` supports `.none` and `.rewrite`. `reprocess()` clears mode `.rewrite` cache and re-fetches.
- `ReaderBottomSheet`:
  - Lay out AI Rewrite section: `HStack` with inline `Picker("AI Rewrite", selection: ...)` (`.pickerStyle(.segmented)`) and right beside it the `Button("Xử lý lại")`.
  - Display label "AI Rewrite" above or inline, with options "Không" and "Rewrite".

### Task 5: Unit Tests Update & Full Verification
- Update `DomainCodableTests`, `SettingsStoreTests`, `SettingsStoreCoercionTests`, `SettingsEditorValidationTests`, `RouterSettingsTests`, `AIPromptBuilderTests`, `AIReadingServiceTests`, `AIReadingViewModelTests`, `PrefetchManagerTests`, `ReaderPrefetchIntegrationTests`.
- Run `./init.sh` (full: format + lint + build + test + drift).

## Dependencies

- No external packages or framework changes.
