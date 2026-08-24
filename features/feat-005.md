# feat-005 — Settings + Cache Manager

## Goal

Expose editable settings and cache controls persisted via the `UserDefaults` + `@Observable` boundary from feat-001.

## Scope

- Settings groups and Setting Editor with validation/persistence on save (invalid blocks save, shows error).
- Current-key-only sanitize on launch per `docs/contracts/settings-schema.md` BR-12; unknown/legacy keys ignored.
- Controls for `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `AI_CUSTOM_HEADERS` JSON, `AI_EXTRA_BODY` JSON, `AI_PROVIDER`, `AI_PROCESS_ACTIONS`, `PREFETCH_COUNT`, `AI_MIN_CHUNK_SIZE`, typography.
- Invalid JSON for headers/body ignored at request merge time but stored verbatim.
- Cache Manager: count/clear all/clear-by-book with confirmation, reflecting `processed_chapters.sqlite` state.

## Non-goals

- No AI request pipeline/chunking/retry, no prefetch runner, no catalog download, no reader content changes.

## Acceptance

- [ ] Sanitize on launch applies defaults for missing/invalid keys, unknown keys ignored.
- [ ] All listed settings editable, validate, and persist; invalid JSON or out-of-range values blocked or coerced per schema.
- [ ] Cache Manager shows count, clears all and by-book with confirm, and updates immediately.
- [ ] Settings changes survive relaunch.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/settings-schema.md`, `docs/contracts/local-data.md`, `docs/contracts/ai-service.md`
- `docs/decisions/local-persistence.md`, `SECURITY.md`
- `docs/product/functional-specs/settings-management.md`

## Plan

Detailed planning deferred until activation; inline plan only if bounded.

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001 and feat-002 completion before activation
