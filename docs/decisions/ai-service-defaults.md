# ADR — Single OpenAI-Compatible Endpoint and Defaults

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Settings exposed multiple AI-related keys and a provider flag, but wire behavior and defaults were not anchored in a contract. Catalog and AI URLs need canonical defaults; header/body handling and retry/chunk/cache must align with existing product docs without inventing storage or logging policy.

## Decision

- **One AI endpoint:** single OpenAI-compatible `POST` to `http://localhost:8317/v1/chat/completions`. No second service.
- **Catalog endpoint:** `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` via `POST` `Content-Type: application/json` returning `{success, data: ExportedBook[], message?}` with numeric ids and preserved nullable fields.
- **Model/provider/chunk/prefetch:** `OPENAI_MODEL=gpt-4o`, `AI_PROVIDER='openai'` (unknown → `openai`), `AI_MIN_CHUNK_SIZE=1300`, `PREFETCH_COUNT=3` (1..10 else 3).
- **Headers/body:** `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` are user-entered JSON objects merged into each AI request; API key lives inside `AI_CUSTOM_HEADERS` when needed; invalid JSON is ignored (existing spec behavior).
- **Behavior alignment:** chunk ~1300 per request, retry 3× (1000 ms after attempt 1, 2000 ms after attempt 2), single `ProcessedChapter` cache `bookId+chapterNumber+mode`, de-duplication, prefetch N=3 sequential cancellable. Do not invent credential storage or log retention (see `SECURITY.md`).
- **Legacy mapping (superseded 2026-08-24 by `local-persistence.md` + `settings-schema.md` current-only):** then open; now only current keys exist, unknown/legacy keys are ignored and defaults apply — no migration map.

## Consequence

- Contracts `docs/contracts/catalog-api.md`, `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md` are canonical; `docs/product/integrations.md` links to them without duplicating wire details.
- Specs `docs/product/functional-specs/ai-reading.md`, `chapter-prefetch.md`, `settings-management.md` link to these contracts.

## Links

- `docs/contracts/catalog-api.md` · `docs/contracts/ai-service.md` · `docs/contracts/settings-schema.md` · `SECURITY.md` · `ARCHITECTURE.md` §1
