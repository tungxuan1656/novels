# feat-005 — Settings + Cache Manager

## Goal

Expose editable settings and cache controls persisted via the `UserDefaults` + `@Observable` boundary from feat-001.

## Scope

- Settings groups and Setting Editor with validation/persistence on save (invalid blocks save, shows error).
- Consume store sanitize from feat-001 (BR-12) — unknown/legacy keys ignored, no re-implementation.
- Controls for `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `AI_CUSTOM_HEADERS` JSON, `AI_EXTRA_BODY` JSON, `AI_PROVIDER`, `AI_PROCESS_ACTIONS`, `PREFETCH_COUNT`, `AI_MIN_CHUNK_SIZE`, typography.
- Invalid JSON for headers/body stored verbatim, ignored at request merge per `docs/contracts/ai-service.md:17`.
- Cache Manager: count card + clear all (confirm) + clear-by-book if design supports — align with `docs/design/screens.md:25`; reflect SQLite immediately.

## Non-goals

- No AI request pipeline/chunking/retry, no prefetch runner, no catalog download, no reader content changes.

## Acceptance

- [ ] Sanitize on launch applies defaults for missing/invalid keys, unknown keys ignored — defaults validated: `OPENAI_MODEL` gpt-4o, `PREFETCH_COUNT` 3 (1..10 else 3), `AI_MIN_CHUNK_SIZE` 1300, provider openai.
- [ ] All listed settings editable, validate, and persist; invalid JSON or out-of-range values blocked or coerced per schema.
- [ ] Cache Manager shows count, clears all and by-book with confirm, and updates immediately (reflects `processed_chapters.sqlite`).
- [ ] Settings changes survive relaunch.

## Relevant docs

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan required at activation (≥4 files expected) — create docs/plans/feat-005.md per feat-001 template

- Link: `docs/plans/feat-005.md` (to be created at activation)
- Ownership: `SettingsView, CacheManagerView, SettingEditorView, SettingsStore/UserDefaults boundary via feat-001`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001 and feat-002 completion before activation
