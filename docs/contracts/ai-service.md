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

Read the result from `choices[0].message.content` (tolerant). `content` may be `null`/missing/empty; fallback to `choices[0].message.reasoning_content` trim non-empty → dùng; else it is an AI processing error. `tool_calls` decodes tolerantly (miss → nil) and never counts as content. Envelope `{data:...}` is not unwrapped — it fails as no-response with shape log.

## Chunking

- Hint `AI_MIN_CHUNK_SIZE = 1300` characters. The app uses one chunk for short chapters. For long chapters the app splits text into chunks. Each chunk triggers one service call. The app waits for every chunk call to succeed, then joins chunk outputs in source order (`"\n"`), saves the joined text as one cache entry, and renders it.
- Within one chapter, chunk calls run in parallel (TaskGroup, index-keyed ordered join). Across prefetch chapters, chapters run sequentially — one chapter batch at a time, never all N chapters at once.
- Prefetch processes chapters sequentially (BR-08, `chapter-prefetch.md`).

## Retry and Failure

- **Retry:** Bounded per-chunk retry — max 2 attempts per chunk (1 initial + 1 retry of exactly the failed chunk, never the whole batch). Retry applies to every failure kind (4xx, 5xx, network, timeout, decode/no-response). Both attempts share one `requestId`; each attempt is logged separately with `attempt` 1/2.
- **Success:** join chunk outputs in source order, clean, save to ProcessedChapter cache as text, render with `SwiftUI.Text`.
- **Failure mapping:**
  - One chunk still failing after its 2nd attempt aborts the whole chapter: no partial cache write, toast once, render raw fallback. Manual "Xử lý lại" retries the chapter on demand.
  - No content → "no response from AI service."
  - Shape log (no raw body/prompt/auth in shape fields): `responseJsonKeys` (top keys ≤10), `choicesCount`, `contentKind` (`null`/`missing`/`empty-string`/`ok`), `hasReasoningContent`, `hasToolCalls`.
  - Full request/response JSON is additionally retained in RAM on the api log entry for in-app inspection only (feat-019 bottom sheet viewer). Never persisted to disk, never emitted to OSLog/`debugSummary`. Log UI shows no headers block and full server URL.
  - Network/server error after the single retry → show provider error or "AI processing failed."
  - Invalid headers/body JSON → the app ignores the value; this is not a failure.
  - After failure: the app writes no cache entry. Concurrent requests for the same key de-duplicate (single call, shared result). `CancellationError` (navigation/mode switch) clears the flag silently with no toast.

## Cache

- Single ProcessedChapter cache keyed by `bookId + chapterNumber + mode` (mode = `none`/`rewrite`). Mode `none` bypasses cache and service. The app checks the cache before calling. The app saves on success (upsert). No second cache exists. See `local-data.md` and `../../docs/product/business-rules.md` BR-07. Prefetch batch-checks then skips cached entries.

## Defaults and Sanitization

Defaults and sanitize rules live in `settings-schema.md` (catalog, AI, prefetch, typography, chunk `1300`, provider `openai`, `AI_PROMPT` default). Prefetch `N=3` is separate.

## Rules

- Use one `POST` to chat completions per chunk.
- Merge `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` only when valid JSON object; otherwise ignore.
- Bounded retry: max 2 attempts per failed chunk only, then stop; user reprocesses manually.
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
