# Prompt Sync & Inline AI Rewrite Picker

- Status: done
- Owner: Tung Doan
- Required to start: [feat-011](task-ai-prompt-rewrite.md)
- Required to integrate/release: none
- Previous ID: feat-012

## Scope and non-goals

Complete documentation alignment that drifted after [task-ai-prompt-rewrite](task-ai-prompt-rewrite.md) and finalize the reading sheet inline rewrite layout:
- Documentation synchronization: Purge legacy references to multi-mode actions (`AI_PROCESS_ACTIONS`, `translate`, `summary`) across `docs/product/overview.md`, `docs/product/glossary.md`, `docs/product/integrations.md`, `docs/product/domain-model.md`, and `docs/design/screens.md`.
- Settings verification: Confirm setting key `AI_PROMPT` with label “Prompt” and default fallback behavior (BR-12).
- Reader bottom sheet UI: Ensure label “AI Rewrite” with an inline segmented picker (“Không” / “Rewrite”) and button “Xử lý lại” sit beside each other in a single `HStack`, disabled when mode is `none` or processing is active.

Non-goals: No SQLite schema alterations, no additional provider endpoints, and no chunking or prefetch algorithmic adjustments.

## Acceptance

- [x] No remaining mention of "AI action" / `AI_PROCESS_ACTIONS` / `translate`/`summary` as a mode in the 5 docs that were synced (grep clean for 5 target files).
- [x] `SettingsView`/`SettingsViewModel` show row "Prompt" with `AI_PROMPT`, Vietnamese placeholder, empty → fallback to default (BR-12).
- [x] `ReaderBottomSheet` shows `Text("AI Rewrite")` + `Picker` inline with 2 options `Không`/`Rewrite` + `Button("Xử lý lại")` in the same `HStack` beside the picker, with `accessibilityIdentifier` `aiModePicker`/`reprocessButton`, disabled when `none`/processing.
- [x] Switch Không ↔ Rewrite reloads correctly (none = raw, rewrite = cache-first via Prompt), Reprocess overwrites cache.
- [x] `./init.sh` full PASS (format, lint, build, test, drift).

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/product/overview.md](../docs/product/overview.md)
- [docs/product/glossary.md](../docs/product/glossary.md)
- [docs/product/domain-model.md](../docs/product/domain-model.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/functional-specs/settings-management.md](../docs/product/functional-specs/settings-management.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Features/Reading/ReaderBottomSheet.swift](../apps/novels/Features/Reading/ReaderBottomSheet.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed documentation grep audits verifying zero legacy "AI Action" references in target documentation. Executed `./init.sh` full verification (format 0/89, lint 0/89, build PASS, test PASS ~130 tests, drift PASS). Historical test coverage recorded per `docs/decisions/verification.md`.
- Blockers: None.
- Next: HISTORICAL: Documentation and inline picker synchronization complete.
