# AI Prompt Setting & Inline Rewrite Reading Sheet

- Status: done
- Owner: Tung Doan
- Required to start: [feat-005](task-settings-cache-manager.md), [feat-006](task-ai-reading.md)
- Required to integrate/release: none
- Previous ID: feat-011

## Scope and non-goals

Replace multi-action settings and multi-mode AI with a single "Prompt" setting and unified "AI Rewrite" mode:
- Settings: Replace `AI_PROCESS_ACTIONS` key with `AI_PROMPT` (multiline text setting labeled "Prompt"). Default prompt produces natural Vietnamese translations preserving honorifics.
- Domain & Service: Update `AIMode` enum cases to `.none` (“Không”) and `.rewrite` (“Rewrite”). Update `AIPromptBuilder` and `AIReadingService` to operate with the single prompt and `.rewrite` mode.
- Reading Sheet UI: Display label “AI Rewrite” with an inline segmented picker (“Không” / “Rewrite”) and a side-by-side Reprocess button (“Xử lý lại”).
- Prefetch: Align prefetch eligibility and batch cache verification to work with mode `.rewrite`.
- Ensure contract docs and unit tests reflect the simplified model.

Non-goals: No schema change to local SQLite cache table (mode column continues storing text values `'none'` and `'rewrite'`); no secondary provider endpoints.

## Acceptance

- [x] Settings screen displays "Prompt" instead of "Hành động AI (JSON)" and allows editing.
- [x] Reader bottom sheet displays "AI Rewrite" with an inline picker ("Không", "Rewrite") and "Xử lý lại" button placed beside it.
- [x] Switching between "Không" and "Rewrite" reloads raw text or AI rewritten text using the configured Prompt.
- [x] Reprocess button invalidates/overwrites cache and triggers re-processing.
- [x] Chapter prefetch works when mode is `.rewrite`.
- [x] `./init.sh` passes completely with 0 errors.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/functional-specs/settings-management.md](../docs/product/functional-specs/settings-management.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Services/](../apps/novels/Services/)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)
- [apps/novels/Features/Settings/](../apps/novels/Features/Settings/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed full `./init.sh` (format, lint, build/test, drift) with 0 errors. The multi-mode AI translation/summary behavior from [task-ai-reading](task-ai-reading.md) was officially replaced by the single prompt rewrite architecture documented in `docs/contracts/ai-service.md` and `docs/product/functional-specs/ai-reading.md`.
- Blockers: None.
- Next: HISTORICAL: Complete remaining documentation and picker sync in follow-up task.
