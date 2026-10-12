# Contract — Settings Schema

> Canonical persistent keys, defaults, and sanitization. Store: `UserDefaults` via `@Observable` (see `../decisions/local-persistence.md`). Consumers: `../../docs/product/functional-specs/settings-management.md`, `../../docs/product/flows.md` §7, `../../ARCHITECTURE.md` §1. Security notes: `../../SECURITY.md`.

## Keys and Defaults

All keys are strings (or string-stored numbers/JSON) in `UserDefaults`. Sanitization runs offline on launch: missing/invalid → defaults; unknown/legacy → ignored (BR-12).

| Key | Type | Default | Notes |
|---|---|---|---|
| `BOOKS_API_URL` | `string` | `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` | Catalog endpoint (`catalog-api.md`) |
| `OPENAI_API_URL` | `string` | `http://localhost:8317/v1/chat/completions` | Single AI endpoint (`ai-service.md`) |
| `OPENAI_MODEL` | `string` | `gpt-4o` | |
| `AI_PROVIDER` | `string` | `auto` | Auto or `openai`, `anthropic`, `muse`, `deepseek`, `mimo`, `glm`, `minimax`, `kimi`, `gemini`; unknown → `auto`; existing `openai` stays manual |
| `AI_API_KEY` | `string` | `""` | Masked UI; trimmed key becomes Authorization Bearer unless custom Authorization exists; UserDefaults, no Keychain |
| `AI_THINKING_EFFORT` | `string` | `""` | Unset emits no controls; explicit `none`, `low`, `medium`, `high`; unknown → unset |
| `AI_CUSTOM_HEADERS` | `string` (JSON object) | `""` / empty | User-entered JSON; custom authentication overrides generated Bearer; stored with normal settings (no Keychain) — see `../../SECURITY.md`; invalid JSON → ignored |
| `AI_EXTRA_BODY` | `string` (JSON object) | `""` / empty | User-entered JSON merged into AI body; invalid JSON → ignored |
| `AI_PROMPT` | `string` | `Dịch truyện sang tiếng Việt tự nhiên, giữ nguyên xưng hô (ta, ngươi, huynh, đệ...), bảo tồn 100% nội dung và văn phong.` | System prompt for AI rewrite; missing/empty → reset to default |
| `AI_BILINGUAL_PROMPT` | `string` | `SettingsDefaults.defaultBilingualPrompt` (preserve Vietnamese content/honorifics, add simple faithful English) | Independent editable prompt for bilingual; missing/blank → own default; app appends immutable JSON/ID protocol |
| `AI_MIN_CHUNK_SIZE` | `number` (string-stored) | `1300` | Chunk hint in characters |
| `PREFETCH_COUNT` | `number` (string-stored) | `3` | Allowed `0..1000`, else `3` on read (BR-08) |
| `AI_MODE` | `string` | `none` | App-wide AI reading mode (`none` / `rewrite` / `bilingual`; labels Bản gốc / Dịch / Song ngữ); unknown → `none` |
| `readingTheme` | `string` | `sach` | Reading theme Full 5 (`sach` / `xanhDiu` / `xanhLam` / `dem` / `amoled`); unknown → `sach`; offline-first via `SettingsStore` |
| `DIAGNOSTICS_VERBOSE` | `boolean` | `false` | Opt-in snippet detail for Log timeline (body ≤100/200 chars, host+path); secrets stay `<redacted>`, prompt never raw |
| Typography: `font`, `fontSize`, `lineHeight` | mixed | per `../../docs/product/business-rules.md` BR-11 | Persisted, applies to every render; missing → defaults |

UI groups: catalog address, AI (URL AI/model/API key/provider/thinking/headers/body/chunk/rewrite prompt/bilingual prompt), prefetch N, typography (font/size/line height), reading theme (`Màu nền` in Reader sheet, not in Settings list) — see `settings-management.md` Flow step 2.

## Validation Rules

- **URLs:** non-empty string; on invalid fall back to default on next launch; edit screen blocks save and shows error.
- **Headers/Body:** must be valid JSON object when non-empty; invalid → treated as empty, request proceeds without merge. No throw.
- **Provider:** trim and lowercase; accept the families above. Auto resolves model identity, then provider host, then OpenAI-compatible fallback. See `ai-service.md`.
- **API key:** allow empty; trim when sending, never display its value in the Settings row.
- **Thinking:** trim and lowercase; empty means provider default, not none. Invalid values sanitize to empty. Unsupported model values are not rewritten.
- **Prompts:** each uses its own default when blank. `AI_PROMPT` remains independent from `AI_BILINGUAL_PROMPT`; changing either does not invalidate cache (manual reprocess only).
- **Prefetch N parsing (one shared trim rule):** trim surrounding whitespace, then `Int`, then finite-`Double` truncation — so `" 20"`, `"20 "`, `"20.0"`/`"20.9"`→`20`, `"1e3"`→`1000`, `"+20"`→`20`. Shared by editor validation, `setValue`, and `intValue` for `PREFETCH_COUNT` only (chunk size still parses strict `Int`). Nothing numeric (or non-finite like `nan`/`inf`) → parse failure.
- **Prefetch N block-vs-coerce:** the editor **blocks** invalid or out-of-range input (save disabled, old value kept — it never writes a fallback). `save()` → `sanitize()` **coerces** an out-of-range stored value (`PREFETCH_COUNT` → `3`). Chunk size follows the same shape with fallback `1300`. Out of range or NaN on read → `1300` / `3`.
- **AI mode:** rawValue string of `AIMode`; missing or not `none`/`rewrite`/`bilingual` → `none`.
- **Reading theme:** rawValue string of `ReadingTheme` (`sach` / `xanhDiu` / `xanhLam` / `dem` / `amoled`); missing, non-string, unknown, or legacy trio (`vangGiay` / `trang` / `den`) → `sach`. Persisted via `UserDefaults` key `readingTheme`, applied live to `ReaderView` + `ReaderBottomSheet`.
- **Diagnostics verbose:** boolean, default `false`; unknown → `false`.
- **Typography:** `fontSize 12..40 step 1`, `lineHeight 1.0..50 step 0.5`; invalid → defaults.

## Current Keys Only

There is no legacy migration. Unknown keys — including any `COPILOT`/`DEEPSEEK`/`SUPABASE` or other historical names — are ignored. On launch the store sanitizes only the current keys above against `../../docs/product/business-rules.md` BR-12 and persists defaults where needed. Do not add a migration map.

## Rules

- Use current keys only; ignore unknown or legacy keys.
- If `PREFETCH_COUNT` is outside `0..1000`, use `3`.
- **Stored N vs effective N:** `prefetchCount` (stored) may transiently hold an out-of-range value until `save()` coerces it; readers (prefetch manager, Settings row) always use `effectivePrefetchCount()` (clamped, read-only). The Settings row shows the effective N. `prefetch.batchCheck` logs the single consumed N (`storedN=`/`effectiveN=`) so a settings fault is distinguishable from a cache/total cut.
- **No runtime cap (BR-08):** there is no runtime window cap; the effective N is honored as-is (N=1000 is paced by the sequential FIFO worker plus the 600s per-chapter / 1800s global budgets, not clamped). `prefetch.batchCheck` logs the single consumed N only, with no applied cap field. Range `0..1000` else `3` is unchanged.
- If `AI_MODE` is not `none`, `rewrite`, or `bilingual`, use `none`.
- If `readingTheme` is not `sach`, `xanhDiu`, `xanhLam`, `dem`, or `amoled` (including legacy `vangGiay`, `trang`, `den`), use `sach`.
- If `AI_CUSTOM_HEADERS` or `AI_EXTRA_BODY` is invalid JSON, ignore it and continue.

## Avoid

- Store credentials only in `AI_API_KEY` or custom JSON settings; never log or document their values.
- Do not add migration for old keys.
- Do not use `Keychain` for these keys.

## Examples

- Canonical: `PREFETCH_COUNT=3` (range `0..1000` else `3`, no runtime cap); `AI_CUSTOM_HEADERS=""` when empty.

## Verification

- Run `../../init.sh` (format → lint → build → focused unit tests). Test scope: [verification decision](../decisions/verification.md); no UI tests.

## Links

- Sanitize lifecycle: `../../docs/product/functional-specs/settings-management.md` States/Cases
- Store: `../decisions/local-persistence.md` · Identity: `../decisions/book-identity.md` · Typographic rendering: `../../docs/design/design-system.md` §3, `../../docs/product/functional-specs/book-reader.md`
