# Contract — AI Processing Service (OpenAI-Compatible)

> Canonical wire contract for independent rewrite and bilingual processing. Business view: `../../docs/product/integrations.md` §2. Consumers: `../../docs/product/functional-specs/ai-reading.md`, `../../docs/product/functional-specs/chapter-prefetch.md`. Settings: `settings-schema.md`. Topology: `../../ARCHITECTURE.md`.

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

1. Base body depends on the endpoint family (see table above) and always includes `"stream": false` explicitly. Chat: `model` + `messages` (`system` = the selected mode prompt, `user` = chunk). Responses: `model` + `instructions` (selected mode prompt) + `input` (chunk string). Anthropic: `model` + `system` (selected mode prompt) + `messages` (`user` = chunk) + `max_tokens` (default `1024` when `AI_EXTRA_BODY` lacks it).
2. If `AI_EXTRA_BODY` is valid JSON object, merge it shallowly into the request body (nested `output_config` preserves generated effort before custom entries override it). Reserved keys are stripped per family and never overridden from extra: chat `{model, messages, stream}`; responses `{model, input, instructions, stream}`; anthropic `{model, messages, system, stream}` (`max_tokens` IS overridable via extra). `JSONSerialization` failure (invalid value types) fails fast with no retry. If the JSON is invalid, ignore it and continue. The request does not fail. Per-family passthrough examples:
   - Chat: `{"temperature": 0.7}`.
   - Responses: `{"reasoning": {"effort": "medium", "summary": "auto"}}`, `{"max_output_tokens": 512}`, `{"text": {"verbosity": "medium"}}`.
   - Anthropic: `{"thinking": {"type": "adaptive"}}`, `{"output_config": {"effort": "high"}}`, `{"temperature": 0.7}`, `{"max_tokens": 512}` (override).
3. Generate `Authorization: Bearer <trimmed AI_API_KEY>` for a non-empty key unless custom headers already contain Authorization (case-insensitive). Add valid `AI_CUSTOM_HEADERS` string entries; custom authentication wins. Native Anthropic still needs custom `x-api-key`. Anthropic family additionally injects `"anthropic-version": "2023-06-01"` when missing (case-insensitive). When merged headers lack `x-opencode-session` (case-insensitive), the app injects `x-opencode-session: novels-<bookId>-c<chapter>-<mode>` from chapter context. A user-supplied value wins verbatim. Empty context sends no header. If the JSON is invalid, ignore it.
4. Determine invalid headers/body warnings from the same settings snapshot and JSON-object parser used for request merging, before generated headers are added. Non-empty malformed JSON or a non-object root is ignored with a length/hash-only warning. Blank input and valid empty objects are not warnings; valid header objects may contain non-string entries that are simply omitted.
5. `AI_API_KEY` is a masked credential setting. `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` are user-entered JSON objects. The app stores them verbatim with normal settings (`UserDefaults` via `@Observable` — see `../decisions/local-persistence.md`). No secret is hard-coded. No real secret appears in docs per `../../SECURITY.md`.

### Provider Identity and Thinking

- `AI_PROVIDER` selects Auto or a manual family, independently of endpoint transport.
- Auto trims surrounding model/URL whitespace, matching request preparation. It checks recognized model names first: `gpt`/`o` reasoning prefixes, `claude`, `muse`, `deepseek`, `mimo`, `glm`, `minimax`, `kimi`/`moonshot`, `gemini`.
- If model identity is unknown, Auto checks provider-owned hosts. Exact host or subdomain matching prevents lookalike domains.
- Host routes: `openai.com`, `anthropic.com`, `meta.ai`, `deepseek.com`, `xiaomimimo.com`, `z.ai`/`bigmodel.cn`, `minimax.io`/`minimaxi.com`, `moonshot.ai`/`moonshot.cn`/`kimi.ai`, `googleapis.com`.
- Otherwise use the OpenAI-compatible baseline. Proxy/localhost hosts do not identify their upstream provider.
- This is provider-only mapping, not a capability promise. Never inspect model versions or downgrade after rejection.
- Unset thinking adds no fields. Explicit none requests disabled thinking and is never replaced with low.

| Provider | Chat Completions generated control |
|---|---|
| OpenAI, Muse, Gemini | `reasoning_effort: <none/low/medium/high>` |
| Anthropic | Unsupported; use Messages or custom body |
| DeepSeek, GLM | none: `thinking.type=disabled`; depth: `thinking.type=enabled` plus `reasoning_effort` |
| Kimi | none: `thinking.type=disabled`; depth: `reasoning_effort` |
| MiniMax | none: `thinking.type=disabled`; depth: `thinking.type=adaptive` plus `reasoning_effort` |
| MiMo | none: `thinking.type=disabled`; depth: explicit configuration error; use provider default or custom binary thinking |

Responses uses `reasoning.effort` for all families except MiMo (unsupported generated thinking transport).
Messages supports Anthropic and MiniMax: none sends `thinking.type=disabled`; depth sends adaptive thinking plus `output_config.effort`.
Other Messages/provider combinations fail locally when thinking is selected. Unset controls preserve legacy passthrough.

Custom `thinking`, `reasoning_effort`, `reasoning`, `thinking_config`/`thinking_budget`/`thinking_level`, or `output_config.effort` suppress the whole generated thinking group. Gemini `google.thinking_config`/`thinkingConfig`, including inside `extra_body.google`, also suppress it.
An `output_config.format` alone does not suppress thinking. Custom body remains authoritative and is not capability-validated.
For an active schema, nested text/output_config merge retains unrelated verbosity/effort fields.

Model restrictions remain server-owned: Muse none, newer Claude/Gemini disable requests, GLM/Kimi medium, and older model fields can fail.
MiMo documents binary thinking, not depth. No prompt or invented token budget simulates effort.
Sources checked 2026-10-12: [OpenAI](https://developers.openai.com/api/docs/guides/reasoning), [Claude](https://platform.claude.com/docs/en/build-with-claude/thinking), [Muse](https://dev.meta.ai/docs/reasoning), [DeepSeek](https://api-docs.deepseek.com/guides/thinking_mode), [MiMo](https://mimo.mi.com/static/docs/quick-start/usage-guide/text-generation/deep-thinking.md), [GLM](https://docs.z.ai/api-reference/llm/chat-completion), [MiniMax](https://platform.minimax.io/docs/api-reference/text-openai-api.md), [Kimi](https://platform.kimi.ai/docs/api/chat), [Gemini](https://ai.google.dev/gemini-api/docs/openai).
OpenCode Go routes by transport; these mappings are not authenticated gateway verification.

### Optional Internal Output Schema

- `AIClient.complete` accepts `outputSchema: AIOutputSchema? = nil`; chapter rewrite passes nil and stays plain text.
- Schema is a named JSON Schema object with top-level `type=object`. Invalid name, JSON, or root type fails before network.
- Append JSON-only instructions and the schema to the system prompt only when provided. No schema setting exists.
- Chat OpenAI/Muse/Gemini/Kimi uses `response_format.type=json_schema`, named schema, and strict=true.
- Chat DeepSeek/GLM/MiMo uses `response_format.type=json_object`; this does not enforce the supplied schema.
- Chat MiniMax uses prompt instructions only because its documented compatible request has no structured format field.
- Responses uses `text.format` with type=json_schema, name, schema, and strict=true.
- Anthropic Messages uses `output_config.format` with type=json_schema and schema. MiniMax Messages uses prompt instructions only.
- Other Messages/provider schema combinations fail explicitly; no fallback transport is selected.
- Reject a conflicting custom response format or malformed nested text/output_config container instead of silently dropping the schema.
- Before sending strict=true, validate every object schema: `additionalProperties: false`, object `properties`, and `required` listing every property exactly once. Check nested properties, array items, schema alternatives, and definitions; preserve the schema without normalization. Other provider-specific schema limits remain server-owned.
- Structured responses require final answer text and a valid JSON object. Require Chat `finish_reason: stop`, Responses `status: completed`, or Messages `stop_reason: end_turn/stop_sequence`. Missing, null, or invalid markers fail; legacy text mode remains tolerant. Do not substitute reasoning_content or accept refusals.
- Return the JSON string; feature callers own typed decoding and schema/semantic validation. This seam is not a general JSON Schema validator.
- Server/gateway/model restrictions remain errors; retries keep the same body and never weaken format controls.

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
- Chat: `choices[0].message.content` (tolerant). `content` may be `null`/missing/empty; fallback to `choices[0].message.reasoning_content` trim non-empty → use; else it is an AI processing error. `tool_calls` decodes tolerantly (miss → nil) and never counts as content. Envelope `{data:...}` is not unwrapped — it fails as no-response with shape log.
- Responses: prefer `output_text` trim non-empty; else join `output[]` where `type == "message"` → `content[]` where `type == "output_text"` → `text`, concatenated with `""` then trimmed. Refusal-only or empty → no-response.
- Anthropic: join `content[]` where `type == "text"` → `text` (concatenated with `""` then trimmed). `thinking`/`redacted_thinking`/`tool_use` blocks are ignored. Empty → no-response.

## Chunking

- Hint `AI_MIN_CHUNK_SIZE = 1300` characters. Values outside `500...10000` sanitize to `1300`. The app uses one chunk for short chapters. For long chapters the app packs paragraphs (split on any newline run, so every non-empty line is its own unit) greedily into chunks joined with `"\n\n"`, never splitting a paragraph that fits within the size hard cap. An oversize paragraph splits at sentence boundaries (`. ! ? …` plus trailing closers, never inside digit-dot-digit or short uppercase abbreviations, joined with `" "`); an oversize sentence splits at the last space within budget so words stay whole; only a spaceless token longer than budget is hard-cut. Each chunk triggers one service call. The app waits for every chunk call to succeed, then joins chunk outputs in source order (`"\n\n"`), saves the joined text as one cache entry, and renders it.
- Within one chapter, chunk calls run in parallel (TaskGroup, index-keyed ordered join). Across prefetch chapters, chapters run sequentially — one chapter batch at a time, never all N chapters at once.
- **Title exclusion:** AI input is the body string by construction. The parser sets the title from the first heading block and skips it, so only the body is chunked; the raw title renders above the translated body and is never translated. Chapters without a heading chunk exactly as before.
- Prefetch processes chapters sequentially (BR-08, `chapter-prefetch.md`).

### Bilingual Chunk Contract

- `bilingual` uses independent `AI_BILINGUAL_PROMPT` plus a noneditable pairing protocol and `BilingualChapter.outputSchema`. `rewrite` still uses `AI_PROMPT` and plain text.
- Normalize CRLF/CR to LF; split on blank lines and keep internal single newlines for fitting paragraphs. Oversized paragraphs reuse sentence/word-safe chunking. Assign chapter-wide IDs after splitting, before packing. Source character size excludes JSON overhead.
- Input: `{"paragraphs":[{"id":"p001","text":"<source>"}]}`. Output: `{"paragraphs":[{"id":"p001","vi":"<Vietnamese>","en":"<English>"}]}`. Both languages required and nonempty after trimming. Exactly the requested ID set; duplicate/missing/unknown IDs reject. Returned order may differ; restore source order.
- Validate before `chunk.success`. Flatten successful chunks by input order into ONE version-1 chapter JSON for cache; never join JSON strings. Semantic pairing errors abort without a new paid repair/retry loop. Transport/final-JSON retry remains bounded below.
- Validate version, unique IDs and language fields on bilingual cache read. Corrupt/unknown-version cache fails explicitly; manual reprocess can replace it. Never render JSON or silently borrow rewrite.
- Caller cancellation releases that consumer from the shared flight. The inner pipeline is cancelled only when no live consumer remains; cancellation is checked before cache upsert. A live reader/prefetch consumer may still finish and save the shared result. Generation tokens keep old-flight cleanup from removing replacement work. Failed or cancelled reprocess retains an existing entry. Structural checks do not prove translation accuracy or detect repeated content assigned to distinct valid IDs.

## Retry and Failure

- **Retry:** Bounded per-chunk retry — max 2 attempts per chunk (1 initial + 1 retry of exactly the failed chunk, never the whole batch). Retry applies to transport and response-envelope/final-JSON failures (4xx, 5xx, network, timeout, decode/no-response); feature-level bilingual ID/pair validation fails without another retry. Both attempts share one `requestId`; each attempt is logged separately with `attempt` 1/2. Cancellation (`CancellationError` or `NSURLErrorDomain -999`) is not retryable; record it as cancellation, never an API failure.
- **Success:** assemble in source order and save atomically to the existing TEXT column: joined plain text for rewrite, one versioned JSON object for bilingual. The reader renders text or decoded pairs, never raw JSON.
- **Failure mapping:**
  - One chunk still failing after its 2nd attempt aborts the whole chapter: no partial cache write, toast once, render raw fallback. Manual "Xử lý lại" retries the chapter on demand.
  - No content → "no response from AI service."
  - Shape log (no raw body/prompt/auth in shape fields): `responseJsonKeys` (top keys ≤10), `choicesCount`, `contentKind` (`null`/`missing`/`empty-string`/`ok`), `hasReasoningContent`, `hasToolCalls`.
  - Full request/response JSON is additionally retained in RAM on the api log entry for in-app inspection only (feat-019 bottom sheet viewer). Never persisted to disk, never emitted to OSLog/`debugSummary`. Log UI shows no headers block; endpoint display removes URL credentials, query and fragment. Sending and outcome entries are appended separately to the 500-entry RAM ring. The UI coalesces the same request/attempt into its latest outcome; sending entries still consume ring capacity. This does not change retention or mutate recorded entries.
  - Network/server error after the single retry → show provider error or "AI processing failed."
  - Invalid headers/body JSON → the app ignores the value; this is not a failure.
  - After failure: the app writes no cache entry. Concurrent requests for the same key de-duplicate (single call, shared result). `CancellationError` (navigation/mode switch) clears the flag silently with no toast.

## Cache

- Single ProcessedChapter cache keyed by `bookId + chapterNumber + mode` (mode = `none`/`rewrite`/`bilingual`). Mode `none` bypasses cache and service. The app checks the cache before calling. The app saves on success (upsert). No second cache exists. See `local-data.md` and `../../docs/product/business-rules.md` BR-07. Prefetch batch-checks then skips cached entries.
- Entries written before the version-2 migration are never served. On upgrade from `user_version` 1 the app runs a one-time `DELETE FROM processed_chapters` and bumps `user_version` to 2, so stale heading-included entries cannot be read.

## Defaults and Sanitization

Defaults and sanitize rules live in `settings-schema.md` (catalog, AI, prefetch, typography, chunk `1300`, provider `auto`, `AI_PROMPT` default). Prefetch `N=3` is separate.

## Rules

- Use one `POST` per chunk to the configured endpoint; branch body/shape by family (chat `/chat/completions`, responses `/responses`, anthropic `/messages`).
- Merge `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` only when valid JSON object; otherwise ignore. Strip reserved keys per family; always send `"stream": false`.
- Bounded retry: max 2 attempts per failed chunk only, then stop; user reprocesses manually.
- Check cache before call; save on success.
- Inject `x-opencode-session: novels-<bookId>-c<chapter>-<mode>` when merged headers lack it (case-insensitive); user value wins, empty context sends nothing.

## Avoid

- Do not redefine defaults here; see `settings-schema.md`.
- Do not hard-code or log credentials; use masked `AI_API_KEY` or custom authentication headers.
- Do not add a second AI cache.

## Examples

- Canonical chat: `POST` `http://localhost:8317/v1/chat/completions` with merged headers including `x-opencode-session: novels-van-gioi-c12-rewrite` and body.
- Responses: `POST` `https://api.openai.com/v1/responses` with `{"model":"...","instructions":"...","input":"...","stream":false}` plus extra `{"reasoning":{"effort":"medium","summary":"auto"}}`.
- Anthropic: `POST` `https://api.anthropic.com/v1/messages` with `anthropic-version: 2023-06-01` header and `{"model":"...","system":"...","messages":[...],"stream":false,"max_tokens":1024}`.

## Verification

- Run `../../init.sh` (format → lint → build → focused unit tests). Test scope: [verification decision](../decisions/verification.md); no UI tests.

## Notes

- `AI_API_KEY` and `AI_CUSTOM_HEADERS` persist with normal settings (no `Keychain`); no Network Logger or credential log exists — see `../../SECURITY.md` and `../decisions/local-persistence.md`. Keep docs free of real secrets. ATS permits HTTP for all domains via `NSAllowsArbitraryLoads`. HTTP sends content and credentials without transport encryption; prefer HTTPS. Port `8317` belongs to the default endpoint.
