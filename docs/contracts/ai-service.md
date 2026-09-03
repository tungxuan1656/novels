# Contract — AI Processing Service (OpenAI-Compatible)

> Canonical wire contract for AI rewrite (single prompt). Business view: `../../docs/product/integrations.md` §2. Consumers: `../../docs/product/functional-specs/ai-reading.md`, `../../docs/product/functional-specs/chapter-prefetch.md`. Settings: `settings-schema.md`. Topology: `../../ARCHITECTURE.md`.

## Endpoint

- **Single endpoint:** one OpenAI-compatible `POST` to chat completions. No second provider endpoint.
- **Defaults:** defaults live in `settings-schema.md`. This file owns chunk, retry, and cache behavior only.

## Request Construction

For each chunk of chapter text (see Chunking):

1. Base body includes `model` and `messages`. Each message has `role` (`system`, `user`, or `assistant`) and `content` string. The configured `AI_PROMPT` setting is the system content. The chunk text is the user content.
2. If `AI_EXTRA_BODY` is valid JSON object, merge it shallowly into the request body. If the JSON is invalid, ignore it and continue. The request does not fail.
3. If `AI_CUSTOM_HEADERS` is valid JSON object, add its entries as HTTP headers. The API key is not a separate setting. When auth is needed, the user puts it inside `AI_CUSTOM_HEADERS` JSON (for example `{"Authorization":"Bearer ..."}`). If the JSON is invalid, ignore it.
4. `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` are user-entered JSON objects. The app stores them verbatim with normal settings (`UserDefaults` via `@Observable` — see `../decisions/local-persistence.md`). No secret is hard-coded. No real secret appears in docs per `../../SECURITY.md`.

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

- Hint `AI_MIN_CHUNK_SIZE = 1300` characters. The app uses one chunk for short chapters. For long chapters the app splits text into chunks. Each chunk triggers one service call. The app joins chunk outputs in source order.
- Per-chunk concurrency is unspecified by product docs.
- Prefetch processes chapters sequentially (BR-08, `chapter-prefetch.md`). Chunk-level sequencing follows the rule above.

## Retry and Failure

- **Retry:** retry 3× (`1000 ms` after attempt 1, `2000 ms` after attempt 2). The app makes no retry after attempt 3.
- **Success:** join chunk outputs in source order, clean, save to ProcessedChapter cache as text, render with `SwiftUI.Text`.
- **Failure mapping:**
  - No content → "no response from AI service."
  - Network/server error after retries → show provider error or "AI processing failed."
  - Invalid headers/body JSON → the app ignores the value; this is not a failure.
  - After final failure: the app writes no cache entry. Concurrent requests for the same key de-duplicate (single call, shared result).

## Cache

- Single ProcessedChapter cache keyed by `bookId + chapterNumber + mode` (mode = `none`/`rewrite`). Mode `none` bypasses cache and service. The app checks the cache before calling. The app saves on success (upsert). No second cache exists. See `local-data.md` and `../../docs/product/business-rules.md` BR-07. Prefetch batch-checks then skips cached entries.

## Defaults and Sanitization

Defaults and sanitize rules live in `settings-schema.md` (catalog, AI, prefetch, typography, chunk `1300`, provider `openai`, `AI_PROMPT` default). Prefetch `N=3` is separate.

## Rules

- Use one `POST` to chat completions per chunk.
- Merge `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` only when valid JSON object; otherwise ignore.
- Retry 3× with fixed delays; then stop.
- Check cache before call; save on success.

## Avoid

- Do not redefine defaults here; see `settings-schema.md`.
- Do not store secrets; use `AI_CUSTOM_HEADERS` JSON.
- Do not add a second AI cache.

## Examples

- Canonical: `POST` `http://localhost:8317/v1/chat/completions` with merged headers and body.

## Verification

- Run `../../init.sh` (format → lint → build).

## Notes

- `AI_CUSTOM_HEADERS` persists with normal settings (no `Keychain`); no Network Logger or credential log exists — see `../../SECURITY.md` and `../decisions/local-persistence.md`. Keep docs free of real secrets. ATS exception is `localhost`-only for `http://localhost:8317`.
