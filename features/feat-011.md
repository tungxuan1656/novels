# feat-011 — AI Prompt Setting & Inline Rewrite Reading Sheet

## Goal

Replace multi-action setting with a single "Prompt" setting, and simplify AI modes to "AI Rewrite" with inline options "Không" and "Rewrite" alongside a side-by-side reprocess button in the reading sheet.

## Scope

- **Settings**: Replace `AI_PROCESS_ACTIONS` with key `AI_PROMPT` (label "Prompt", multiline text setting). Default prompt is natural Vietnamese translation with honorifics.
- **Domain & Service**: Update `AIMode` enum cases to `.none` ("Không") and `.rewrite` ("Rewrite"). Update `AIPromptBuilder` to use `AI_PROMPT` setting directly. Update `AIReadingService` to operate with `AIMode.rewrite` and single prompt.
- **Reading Sheet UI**: Display label "AI Rewrite" with inline segmented picker ("Không" / "Rewrite") and side-by-side Reprocess button ("Xử lý lại").
- **Chapter Prefetch**: Update prefetch eligibility and batch checks to work with mode `rewrite`.
- **Docs & Verification**: Ensure all contracts and unit tests pass.

## Non-goals

- No change to local SQLite cache table structure (mode column `TEXT` continues to store mode string `'none'` / `'rewrite'`).
- No secondary endpoints or provider logic.

## Acceptance

- [x] Settings screen displays "Prompt" instead of "Hành động AI (JSON)" and allows editing.
- [x] Reader bottom sheet displays "AI Rewrite" with an inline picker ("Không", "Rewrite") and "Xử lý lại" button placed beside it.
- [x] Switching between "Không" and "Rewrite" reloads raw text or AI rewritten text using the configured Prompt.
- [x] Reprocess button invalidates/overwrites cache and triggers re-processing.
- [x] Chapter prefetch works when mode is `.rewrite`.
- [x] `./init.sh` passes completely with 0 errors.

## Relevant docs

- `docs/contracts/settings-schema.md`
- `docs/contracts/ai-service.md`
- `docs/contracts/local-data.md`
- `docs/product/domain-model.md`
- `docs/product/business-rules.md`
- `docs/product/functional-specs/ai-reading.md`
- `docs/product/functional-specs/settings-management.md`
- `docs/design/screens.md`

## Plan

- Link: `docs/plans/feat-011.md`

## Verify

- `./init.sh` (full)

## Handoff

- State: done
- Evidence: ./init.sh full verification passed 100% (format, lint, build/test, drift)
- Blockers: none
- Next: feature complete, ready for session wrap-up
