# feat-012 — Prompt Sync & Inline AI Rewrite Picker

## Goal

Complete documentation sync that still drifted after feat-011 to the single Prompt model and ensure the Reading sheet shows "AI Rewrite" with an inline picker that has 2 options "Không"/"Rewrite" + a "Xử lý lại" button placed beside the picker in the same row.

## Scope

- **Docs sync**: Fix remaining drift from model `translate`/`summary`/`AI Action` to `Prompt`/`rewrite`:
  - `docs/product/overview.md` (Purpose/Scope/Features)
  - `docs/product/glossary.md` (AI Prompt / AI Mode)
  - `docs/product/integrations.md` (§2 Purpose via single Prompt)
  - `docs/product/domain-model.md` (Relationship Map AI_PROMPT)
  - `docs/design/screens.md` (Cases Bad JSON for AI Actions → Invalid headers/body + Empty Prompt)
- **Settings**: Confirm key `AI_PROMPT` label "Prompt" (multiline), no remaining "AI action" (`AI_PROCESS_ACTIONS`). Default prompt is Vietnamese and keeps honorifics.
- **Reading Sheet UI**: Label "AI Rewrite" + Picker inline ("Không" / "Rewrite") + Button "Xử lý lại" placed beside the picker in the same HStack, disabled when `aiMode == .none` or `isAIProcessing`.

## Non-goals

- No SQLite schema change (mode TEXT `none`/`rewrite` stays as is).
- No new endpoint/provider.
- No chunk/prefetch logic change beyond feat-011.

## Acceptance

- [x] No remaining mention of "AI action" / `AI_PROCESS_ACTIONS` / `translate`/`summary` as a mode in the 5 docs that were synced (grep clean for 5 target files).
- [x] `SettingsView`/`SettingsViewModel` show row "Prompt" with `AI_PROMPT`, Vietnamese placeholder, empty → fallback to default (BR-12).
- [x] `ReaderBottomSheet` shows `Text("AI Rewrite")` + `Picker` inline with 2 options `Không`/`Rewrite` + `Button("Xử lý lại")` in the same `HStack` beside the picker, with `accessibilityIdentifier` `aiModePicker`/`reprocessButton`, disabled when `none`/processing.
- [x] Switch Không ↔ Rewrite reloads correctly (none = raw, rewrite = cache-first via Prompt), Reprocess overwrites cache.
- [x] `./init.sh` full PASS (format, lint, build, test, drift).

## Relevant docs

- `docs/contracts/settings-schema.md`
- `docs/contracts/local-data.md`
- `docs/contracts/ai-service.md`
- `docs/product/overview.md`
- `docs/product/glossary.md`
- `docs/product/domain-model.md`
- `docs/product/business-rules.md`
- `docs/product/functional-specs/ai-reading.md`
- `docs/product/functional-specs/settings-management.md`
- `docs/design/screens.md`

## Plan

- Link: `docs/plans/feat-012.md` (inline plan, no external plan needed — <4 files, <200 lines).

## Verify

- `grep -R "AI Action\|AI_PROCESS_ACTIONS" docs/product docs/design --exclude-dir=plans` clean (except history in features)
- `grep -R "translate.*summary" docs/product/overview.md docs/product/glossary.md` clean
- UI smoke: ReaderBottomSheet HStack contains Picker + Button side-by-side
- `./init.sh` full

## Handoff

- State: done
- Evidence: docs/product/overview.md L9/L18/L27 → Prompt/rewrite, glossary AI Prompt/AI Mode none-rewrite, integrations Purpose single Prompt, domain-model Relationship Map AI_PROMPT, screens Cases Invalid headers/body + Empty Prompt; apps/novels/Features/Reading/ReaderBottomSheet.swift pickerStyle .inline + Button beside (aiModePicker/reprocessButton); Settings AI_PROMPT Prompt verified; ./init.sh full PASS 2026-09-03 (format 0/89, lint 0/89, build PASS, test PASS ~130 tests, drift PASS 21/22)
- Blockers: none
- Next: repo idle — all Prompt/AI Rewrite docs & picker inline synced
