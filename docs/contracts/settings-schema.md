# Contract — Settings Schema

> Canonical persistent keys, defaults, and sanitization. Store: `UserDefaults` via `@Observable` (see `../decisions/local-persistence.md`). Consumers: `../../docs/product/functional-specs/settings-management.md`, `../../docs/product/flows.md` §7, `../../ARCHITECTURE.md` §1. Security notes: `../../SECURITY.md`.

## Keys and Defaults

All keys are strings (or string-stored numbers/JSON) in `UserDefaults`. Sanitization runs offline on launch: missing/invalid → defaults; unknown/legacy → ignored (BR-12).

| Key | Type | Default | Notes |
|---|---|---|---|
| `BOOKS_API_URL` | `string` | `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` | Catalog endpoint (`catalog-api.md`) |
| `OPENAI_API_URL` | `string` | `http://localhost:8317/v1/chat/completions` | Single AI endpoint (`ai-service.md`) |
| `OPENAI_MODEL` | `string` | `gpt-4o` | |
| `AI_PROVIDER` | `string` | `openai` | Only `openai` supported; unknown → `openai` |
| `AI_CUSTOM_HEADERS` | `string` (JSON object) | `""` / empty | User-entered JSON; API key lives here as `Authorization` header if needed; stored with normal settings (no Keychain) — see `../../SECURITY.md`; invalid JSON → ignored |
| `AI_EXTRA_BODY` | `string` (JSON object) | `""` / empty | User-entered JSON merged into AI body; invalid JSON → ignored |
| `AI_PROMPT` | `string` | `Dịch truyện sang tiếng Việt tự nhiên, giữ nguyên xưng hô (ta, ngươi, huynh, đệ...), bảo tồn 100% nội dung và văn phong.` | System prompt for AI rewrite; missing/empty → reset to default |
| `AI_MIN_CHUNK_SIZE` | `number` (string-stored) | `1300` | Chunk hint in characters |
| `PREFETCH_COUNT` | `number` (string-stored) | `3` | Allowed `0..1000`, else `3` on read (BR-08) |
| `AI_MODE` | `string` | `none` | App-wide AI reading mode (`none` / `rewrite`); unknown → `none` |
| `readingTheme` | `string` | `vangGiay` | Reading theme trio (`vangGiay` / `trang` / `den`); unknown → `vangGiay`; offline-first via `SettingsStore` |
| `DIAGNOSTICS_VERBOSE` | `boolean` | `false` | Opt-in snippet detail for Log timeline (body ≤100/200 chars, host+path); secrets stay `<redacted>`, prompt never raw |
| Typography: `font`, `fontSize`, `lineHeight`, `letterSpacing` | mixed | per `../../docs/product/business-rules.md` BR-11 | Persisted, applies to every render; missing → defaults |

UI groups: catalog address, AI (URL/model/provider/headers/body/chunk/prompt), prefetch N, typography (font/size/line height/spacing), reading theme (`Màu nền` in Reader sheet, not in Settings list) — see `settings-management.md` Flow step 2.

## Validation Rules

- **URLs:** non-empty string; on invalid fall back to default on next launch; edit screen blocks save and shows error.
- **Headers/Body:** must be valid JSON object when non-empty; invalid → treated as empty, request proceeds without merge. No throw.
- **Provider:** case-insensitive compare; only `openai` accepted.
- **Prompt:** non-empty string. If empty → sanitize to default prompt.
- **Chunk size / Prefetch N:** numeric string coerced to number; out of range or NaN → `1300` / `3`.
- **AI mode:** rawValue string of `AIMode`; missing or not `none`/`rewrite` → `none`.
- **Reading theme:** rawValue string of `ReadingTheme` (`vangGiay` / `trang` / `den`); missing, non-string, or unknown → `vangGiay`. Persisted via `UserDefaults` key `readingTheme`, applied live to `ReaderView` + `ReaderBottomSheet`.
- **Diagnostics verbose:** boolean, default `false`; unknown → `false`.
- **Typography:** `fontSize 12..40 step 1`, `lineHeight 1.0..50 step 0.5`, `letterSpacing 0..3.0 step 0.1`; invalid → defaults.

## Current Keys Only

There is no legacy migration. Unknown keys — including any `COPILOT`/`DEEPSEEK`/`SUPABASE` or other historical names — are ignored. On launch the store sanitizes only the current keys above against `../../docs/product/business-rules.md` BR-12 and persists defaults where needed. Do not add a migration map.

## Rules

- Use current keys only; ignore unknown or legacy keys.
- If `PREFETCH_COUNT` is outside `0..1000`, use `3`.
- If `AI_MODE` is not `none` or `rewrite`, use `none`.
- If `readingTheme` is not `vangGiay`, `trang`, or `den`, use `vangGiay`.
- If `AI_CUSTOM_HEADERS` or `AI_EXTRA_BODY` is invalid JSON, ignore it and continue.

## Avoid

- Do not store secrets outside `AI_CUSTOM_HEADERS` JSON.
- Do not add migration for old keys.
- Do not use `Keychain` for these keys.

## Examples

- Canonical: `PREFETCH_COUNT=3` (range `0..1000` else `3`); `AI_CUSTOM_HEADERS=""` when empty.

## Verification

- Run `../../init.sh` (format → lint → build).

## Links

- Sanitize lifecycle: `../../docs/product/functional-specs/settings-management.md` States/Cases
- Store: `../decisions/local-persistence.md` · Identity: `../decisions/book-identity.md` · Typographic rendering: `../../docs/design/design-system.md` §3, `../../docs/product/functional-specs/book-reader.md`
