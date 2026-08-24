# Contract — AI Processing Service (OpenAI-Compatible)

> Canonical wire contract for AI translate/summary. Business view: `docs/product/integrations.md` §2. Consumers: `docs/product/functional-specs/ai-reading.md`, `docs/product/functional-specs/chapter-prefetch.md`. Settings: `settings-schema.md`. Topology: `ARCHITECTURE.md`.

## Endpoint

- **Single endpoint:** one OpenAI-compatible `POST` to chat completions. No second provider endpoint. [Intended]
- **Default URL:** `http://localhost:8317/v1/chat/completions` [Intended]
- **Default model:** `gpt-4o` [Intended — `OPENAI_MODEL`; BR-12 fallback]
- **Provider flag:** `AI_PROVIDER='openai'` only supported today; unknown → `openai` on sanitize. [Intended — `settings-schema.md`]

## Request Construction

For each chunk of chapter text (see Chunking):

1. Base body includes `model` and `messages`. Each message has `role` (`system`, `user`, or `assistant`) and `content` string. The active `AIAction.prompt` is the system content, and the chunk text is the user content.
2. Merge `AI_EXTRA_BODY` when it is valid JSON object — shallow merge into the request body. If invalid JSON, ignore it and proceed (no failure). [Intended — per scope: invalid JSON ignored]
3. Merge `AI_CUSTOM_HEADERS` when it is valid JSON object — add as HTTP headers. API key is **not** a separate setting; when the user wants auth they put it inside `AI_CUSTOM_HEADERS` JSON (e.g. `{"Authorization":"Bearer ..."}`). If invalid JSON, ignore. [Intended]
4. `AI_EXTRA_BODY` / `AI_CUSTOM_HEADERS` are user-entered JSON objects stored verbatim with normal settings (`UserDefaults` via `@Observable` — see `docs/decisions/local-persistence.md`); no secret is hard-coded and no real secret appears in docs/examples per `SECURITY.md`.

### Request and Response Shape

```json
{
  "model": "gpt-4o",
  "messages": [
    { "role": "system", "content": "<prompt>" },
    { "role": "user", "content": "<chapter chunk>" }
  ]
}
```

Read the result from `choices[0].message.content`. An absent or empty value is an AI processing error.

## Chunking

- Hint `AI_MIN_CHUNK_SIZE = 1300` characters. Short chapters → single chunk. Long chapters → split into chunks, each chunk is one service call; chunk outputs retain source order when joined. Per-chunk concurrency is unspecified by product docs. [Intended — BR-12, `flows.md` §5]
- Prefetch chapters are processed sequentially by product rule (BR-08, `chapter-prefetch.md`); chunk-level sequencing is as above.

## Retry and Failure

- **Retry:** up to 3 attempts per chunk; no retry after attempt 3. Delays: ~1000 ms after failure of attempt 1 and ~2000 ms after failure of attempt 2 (index 0→1000 ms, 1→2000 ms in supplied implementation). [Supplied implementation; business docs state "up to 3 attempts" without fixing the backoff indexing in detail]
- **Success:** join chunk outputs in source order, clean, convert to HTML, save to ProcessedChapter cache, render.
- **Failure mapping:**
  - No content → "no response from AI service." [Observed — `flows.md` Cases]
  - Network/server error after retries → show provider error or "AI processing failed." [Observed — `integrations.md` §2]
  - Invalid headers/body JSON → ignored, not a failure. [Intended]
  - After final failure: no cache write. Concurrent same-key requests de-duplicate (single call, shared result). [Observed — BR-07]

## Cache

- Single ProcessedChapter cache keyed by `bookId + chapterNumber + mode` (mode = `AIAction.key` = `translate`/`summary`). Mode `none` bypasses cache/service. Check before calling; save on success (upsert). No second cache. See `local-data.md` and `business-rules.md` BR-07. Prefetch batch-checks then skips cached.

## Defaults and Sanitization

Defaults and sanitize rules live in `settings-schema.md` (catalog/AI/prefetch/typography, chunk 1300, provider `openai`, `AI_PROCESS_ACTIONS` defaults). Prefetch `N=3` is separate.

## Notes

- `AI_CUSTOM_HEADERS` persists with normal settings (no Keychain); no Network Logger or credential/redaction log feature is in scope — see `SECURITY.md` and `docs/decisions/local-persistence.md`. Keep docs/examples free of real secrets. ATS exception is `localhost`-only for `http://localhost:8317`.
