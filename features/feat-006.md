# feat-006 — AI Reading

## Goal

Deliver cache-first translate/summary rendering for the current chapter via an OpenAI-compatible service.

## Scope

- Modes `none` (raw), `translate`, `summary`; cache-first lookup `bookId(slug)+chapterNumber+mode` in `processed_chapters.sqlite`.
- On miss: chunk ~1300, `URLSession` POST to `OPENAI_API_URL` per chunk merging `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` JSON (ignore invalid), retry 3× (1000/2000 ms), `actor` de-duplication, header/body merge, join/clean/HTML, `INSERT OR REPLACE` cache.
- Mode switch + reprocess added to Reading bottom sheet owned by feat-004; this feature contributes mode controls + cache-first logic; Vietnamese natural translation keeping honorifics, summary 50–60% keeping plot/dialogue per `ai-service.md`.
- `localhost`-only `ATS` exception for `http://localhost:8317`.

## Non-goals

- No prefetch batch runner/status, no reader navigation changes beyond mode UI, no Settings UI changes — AI keys owned by feat-005; this feature only consumes them.

## Acceptance

- [ ] Cache hit returns without network; miss chunks, retries, merges, and caches under slug identity.
- [ ] De-duplication prevents parallel duplicate requests for same `(bookId, chapter, mode)`.
- [ ] Reprocess overwrites cache; mode switch shows cached content or triggers processing.
- [ ] `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON headers/body ignored at merge per `docs/contracts/ai-service.md:17`, localhost ATS `http://localhost:8317` only.
- [ ] `mode == "none"` never cached.
- [ ] Unit test asserts prompts contain BR-03/04 constraints (keep honorifics ta/ngươi/huynh..., natural Vietnamese 100%) and BR-05/06 (summary 50-60% keep plot/dialogue, no hallucination).

## Relevant docs

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan required at activation (≥4 files expected) — create docs/plans/feat-006.md per feat-001 template

- Link: `docs/plans/feat-006.md` (to be created at activation)
- Ownership: `AIClient (URLSession), Chunking (1300), PromptBuilder, ProcessedChapterCache (SQLite), AI Reading ViewModel + mode UI in Reading sheet, actor dedup`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-004 and feat-005 completion before activation
