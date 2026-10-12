# Settings + Cache Manager

- Status: done
- Owner: Tung Doan
- Required to start: [feat-001](task-persistence-foundation.md), [feat-002](task-app-shell-library.md)
- Required to integrate/release: none
- Previous ID: feat-005

## Scope and non-goals

Expose editable settings screens and cache management controls persisted via `UserDefaults` and SQLite:
- Settings groups and Setting Editor with validation and persistence on save; invalid values block saving and display descriptive errors.
- Enforce BR-12 sanitization on load via `SettingsStore` (defaults for missing/invalid keys; unknown and legacy keys ignored).
- Editor controls for `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `AI_CUSTOM_HEADERS`, `AI_EXTRA_BODY`, `AI_PROVIDER`, `AI_PROCESS_ACTIONS`, `PREFETCH_COUNT`, `AI_MIN_CHUNK_SIZE`, and typography. Note: `AI_PROCESS_ACTIONS` was later superseded by single `AI_PROMPT` in [task-ai-prompt-rewrite](task-ai-prompt-rewrite.md).
- Invalid JSON for custom headers and extra body stored verbatim but ignored during request merging per `docs/contracts/ai-service.md:17`.
- Cache Manager: chapter count card, clear-all with confirmation alert, and clear-by-book; immediately updates SQLite cache statistics.

Non-goals: No AI request execution, chunking, or retry logic; no prefetch batch runner; no catalog downloads; no reader content rendering changes.

## Acceptance

- [x] Sanitize on launch applies defaults for missing/invalid keys, unknown keys ignored — defaults validated: `OPENAI_MODEL` gpt-4o, `PREFETCH_COUNT` 3 (1..10 else 3), `AI_MIN_CHUNK_SIZE` 1300, provider openai.
- [x] All listed settings editable, validate, and persist; invalid JSON or out-of-range values blocked or coerced per schema.
- [x] Cache Manager shows count, clears all and by-book with confirm, and updates immediately (reflects `processed_chapters.sqlite`).
- [x] Settings changes survive relaunch.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/settings-schema.md](../docs/contracts/settings-schema.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [docs/product/functional-specs/settings-management.md](../docs/product/functional-specs/settings-management.md)
- [apps/novels/Features/Settings/](../apps/novels/Features/Settings/)
- [apps/novels/Persistence/](../apps/novels/Persistence/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `xcodebuild build` PASS; `swiftlint --strict` found 0 violations; `swiftformat --lint` 0 require formatting; `xcodebuild test` passed 23 targeted tests (RouterSettingsTests 5, SettingsEditorValidationTests 7, CacheManagerTests 5, SettingsStoreTests 6); relaunch persistence and invalid JSON header handling confirmed. The full historical run hit a test-bundle flake (`Failed to create bundle instance`); the 23 targeted passes are not a full-suite pass. Rerun testing is governed by the focused unit testing policy in `docs/decisions/verification.md`. `AI_PROCESS_ACTIONS` was subsequently replaced by `AI_PROMPT` in [task-ai-prompt-rewrite](task-ai-prompt-rewrite.md) (`docs/contracts/settings-schema.md`).
- Blockers: None.
- Next: HISTORICAL: feat-006 AI Reading ready to activate.
