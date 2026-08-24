# feat-006 — AI Reading

## Goal

Deliver cache-first translate/summary rendering for the current chapter via an OpenAI-compatible service.

## Scope

- Modes `none` (raw), `translate`, `summary`; cache-first lookup `bookId(slug)+chapterNumber+mode` in `processed_chapters.sqlite`.
- On miss: chunk ~1300, `URLSession` POST to `OPENAI_API_URL` per chunk merging `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` JSON (ignore invalid), retry 3× (1000/2000 ms), `actor` de-duplication, header/body merge, join/clean/HTML, `INSERT OR REPLACE` cache.
- Mode switch/reprocess UI; Vietnamese natural translation keeping honorifics, summary 50–60% keeping plot/dialogue per `ai-service.md`.
- `localhost`-only `ATS` exception for `http://localhost:8317`.

## Non-goals

- No prefetch batch runner/status, no reader navigation changes beyond mode UI, no settings group changes beyond AI keys.

## Acceptance

- [ ] Cache hit returns without network; miss chunks, retries, merges, and caches under slug identity.
- [ ] De-duplication prevents parallel duplicate requests for same `(bookId, chapter, mode)`.
- [ ] Reprocess overwrites cache; mode switch shows cached content or triggers processing.
- [ ] `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON ignored at merge; localhost ATS only.
- [ ] `mode == "none"` never cached.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/ai-service.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`, `SECURITY.md`
- `docs/product/functional-specs/ai-reading.md`, `docs/product/business-rules.md`

## Plan

Detailed planning deferred until activation; substantial scope — external/separate plan may be used when activated. No plan created now.

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-004 and feat-005 completion before activation
