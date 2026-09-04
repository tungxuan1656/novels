# Contract — AI Processing Service (OpenAI-Compatible)

> Canonical wire contract for AI rewrite (single prompt). Business view: `../../docs/product/integrations.md` §2. Consumers: `../../docs/product/functional-specs/ai-reading.md`, `../../docs/product/functional-specs/chapter-prefetch.md`. Settings: `settings-schema.md`. Topology: `../../ARCHITECTURE.md`.

## Endpoint

- **Three families by URL path substring (case-insensitive):** the app branches request/response handling on the configured endpoint URL.
  - URL contains `/responses` → Responses family.
  - Else URL contains `/messages` → Anthropic Messages family.
  - Else → Chat Completions family (default, preserves `http://localhost:8317/v1/chat/completions`).
- **Defaults:** defaults live in `settings-schema.md`. This file owns chunk, retry, and cache behavior only.

| Family | URL substring | Input keys | Output location | Token key | Reasoning key |
| --- | --- | --- | --- | --- | --- |
| Chat Completions | (default) | `model`, `messages: [{system: prompt}, {user: chunk}]` | `choices[0].message.content`, fallback `reasoning_content` | via `AI_EXTRA_BODY` (e.g. `max_tokens`) | `reasoning_content` fallback |
| Responses | `/responses` | `model`, `instructions: prompt`, `input: chunk` | `output_text` preferred, else `output[]` (`type == "message"` → `content[]` (`type == "output_text"` → `text`)) | `max_output_tokens` (no default cap) | `reasoning: {"effort": "medium", "summary": "auto"}` |
| Anthropic Messages | `/messages` | `model`, `system: prompt`, `messages: [{user: chunk}]` | `content[]` (`type == "text"` → `text` joined) | `max_tokens` (default `1024`, overridable) | `thinking: {"type": "adaptive"}` + `output_config: {"effort": "high"}` |

- **Streaming:** all families send `"stream": false` explicitly. Streaming responses are not supported.
- **Anthropic headers:** when the family is Anthropic and configured headers lack `anthropic-version` (case-insensitive), the app injects `"anthropic-version": "2023-06-01"`. A user-supplied value wins. Anthropic temperature range is `0...1`.
- **Verbosity (Responses):** via extra `{"text": {"verbosity": "medium"}}`.

## Request Construction

For each chunk of chapter text (see Chunking):

1. Base body depends on the endpoint family (see table above) and always includes `"stream": false` explicitly. Chat: `model` + `messages` (`system` = `AI_PROMPT`, `user` = chunk). Responses: `model` + `instructions` (`AI_PROMPT`) + `input` (chunk string). Anthropic: `model` + `system` (`AI_PROMPT`) + `messages` (`user` = chunk) + `max_tokens` (default `1024` when `AI_EXTRA_BODY` lacks it).
2. If `AI_EXTRA_BODY` is valid JSON object, merge it shallowly into the request body. Reserved keys are stripped per family and never overridden from extra: chat `{model, messages, stream}`; responses `{model, input, instructions, stream}`; anthropic `{model, messages, system, stream}` (`max_tokens` IS overridable via extra). `JSONSerialization` failure (invalid value types) fails fast with no retry. If the JSON is invalid, ignore it and continue. The request does not fail. Per-family passthrough examples:
   - Chat: `{"temperature": 0.7}`.
   - Responses: `{"reasoning": {"effort": "medium", "summary": "auto"}}`, `{"max_output_tokens": 512}`, `{"text": {"verbosity": "medium"}}`.
   - Anthropic: `{"thinking": {"type": "adaptive"}}`, `{"output_config": {"effort": "high"}}`, `{"temperature": 0.7}`, `{"max_tokens": 512}` (override).
3. If `AI_CUSTOM_HEADERS` is valid JSON object, add its entries as HTTP headers. The API key is not a separate setting. When auth is needed, the user puts it inside `AI_CUSTOM_HEADERS` JSON (for example `{"Authorization":"Bearer ..."}`). Anthropic family additionally injects `"anthropic-version": "2023-06-01"` when missing (case-insensitive). If the JSON is invalid, ignore it.
4. `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` are user-entered JSON objects. The app stores them verbatim with normal settings (`UserDefaults` via `@Observable` — see `../decisions/local-persistence.md`). No secret is hard-coded. No real secret appears in docs per `../../SECURITY.md`.

### Request and Response Shape

Chat completions:

```json
{
  "model": "gpt-4o",
  "messages": [
    { "role": "system", "content": "<prompt>" },
    { "role": "user", "content": "<chapter chunk>" }
  ],
  "stream": false
}
```

Responses:

```json
{
  "model": "gpt-4o",
  "instructions": "<prompt>",
  "input": "<chapter chunk>",
  "stream": false
}
```

Anthropic messages:

```json
{
  "model": "claude-x",
  "system": "<prompt>",
  "messages": [{ "role": "user", "content": "<chapter chunk>" }],
  "stream": false,
  "max_tokens": 1024
}
```

Read the result tolerantly (all optional, never throw on missing; decode failure or empty resolves to no-response with shape log):
- Chat: `choices[0].message.content` (tolerant). `content` may be `null`/missing/empty; fallback to `choices[0].message.reasoning_content` trim non-empty → dùng; else it is an AI processing error. `tool_calls` decodes tolerantly (miss → nil) and never counts as content. Envelope `{data:...}` is not unwrapped — it fails as no-response with shape log.
- Responses: prefer `output_text` trim non-empty; else join `output[]` where `type == "message"` → `content[]` where `type == "output_text"` → `text`, concatenated with `""` then trimmed. Refusal-only or empty → no-response.
- Anthropic: join `content[]` where `type == "text"` → `text` (concatenated with `""` then trimmed). `thinking`/`redacted_thinking`/`tool_use` blocks are ignored. Empty → no-response.

## Chunking

- Hint `AI_MIN_CHUNK_SIZE = 1300` characters. Values outside `500...10000` sanitize to `1300`. The app uses one chunk for short chapters. For long chapters the app splits text into chunks. Each chunk triggers one service call. The app waits for every chunk call to succeed, then joins chunk outputs in source order (`"\n"`), saves the joined text as one cache entry, and renders it.
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

- Use one `POST` per chunk to the configured endpoint; branch body/shape by family (chat `/chat/completions`, responses `/responses`, anthropic `/messages`).
- Merge `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` only when valid JSON object; otherwise ignore. Strip reserved keys per family; always send `"stream": false`.
- Bounded retry: max 2 attempts per failed chunk only, then stop; user reprocesses manually.
- Check cache before call; save on success.

## Avoid

- Do not redefine defaults here; see `settings-schema.md`.
- Do not store secrets; use `AI_CUSTOM_HEADERS` JSON.
- Do not add a second AI cache.

## Examples

- Canonical chat: `POST` `http://localhost:8317/v1/chat/completions` with merged headers and body.
- Responses: `POST` `https://api.openai.com/v1/responses` with `{"model":"...","instructions":"...","input":"...","stream":false}` plus extra `{"reasoning":{"effort":"medium","summary":"auto"}}`.
- Anthropic: `POST` `https://api.anthropic.com/v1/messages` with `anthropic-version: 2023-06-01` header and `{"model":"...","system":"...","messages":[...],"stream":false,"max_tokens":1024}`.

## Verification

- Run `../../init.sh` (format → lint → build).

## Notes

- `AI_CUSTOM_HEADERS` persists with normal settings (no `Keychain`); no Network Logger or credential log exists — see `../../SECURITY.md` and `../decisions/local-persistence.md`. Keep docs free of real secrets. ATS exception is `localhost`-only for `http://localhost:8317`.
