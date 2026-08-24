# Contract — Settings Schema

> Canonical persistent keys, defaults, and sanitization. Store: `UserDefaults` via `@Observable` (see `docs/decisions/local-persistence.md`). Consumers: `docs/product/functional-specs/settings-management.md`, `docs/product/flows.md` §7, `ARCHITECTURE.md` §1. Security notes: `SECURITY.md`.

## Keys and Defaults

All keys are strings (or string-stored numbers/JSON) in `UserDefaults`. Sanitization runs offline on launch: missing/invalid → defaults; unknown/legacy → ignored (BR-12).

| Key | Type | Default | Notes |
|---|---|---|---|
| `BOOKS_API_URL` | `string` | `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` | Catalog endpoint (`catalog-api.md`) |
| `OPENAI_API_URL` | `string` | `http://localhost:8317/v1/chat/completions` | Single AI endpoint (`ai-service.md`) |
| `OPENAI_MODEL` | `string` | `gpt-4o` | |
| `AI_PROVIDER` | `string` | `openai` | Only `openai` supported; unknown → `openai` |
| `AI_CUSTOM_HEADERS` | `string` (JSON object) | `""` / empty | User-entered JSON; API key lives here as `Authorization` header if needed; stored with normal settings (no Keychain) — see `SECURITY.md`; invalid JSON → ignored |
| `AI_EXTRA_BODY` | `string` (JSON object) | `""` / empty | User-entered JSON merged into AI body; invalid JSON → ignored |
| `AI_PROCESS_ACTIONS` | `string` (JSON array) | `translate` + `summary` | Each `{ key, name, prompt }`; invalid/empty → reset to defaults |
| `AI_MIN_CHUNK_SIZE` | `number` (string-stored) | `1300` | Chunk hint in characters |
| `PREFETCH_COUNT` | `number` (string-stored) | `3` | Allowed `1..10`, else `3` on read (BR-08) |
| Typography: `font`, `fontSize`, `lineHeight`, `letterSpacing` | mixed | per `business-rules.md` BR-11 | Persisted, applies to every render; missing → defaults |

UI groups: catalog address, AI (URL/model/provider/headers/body/chunk/actions), prefetch N, typography (font/size/line height/spacing) — see `settings-management.md` Flow step 2.

## Validation Rules

- **URLs:** non-empty string; on invalid fall back to default on next launch; edit screen blocks save and shows error.
- **Headers/Body:** must be valid JSON object when non-empty; invalid → treated as empty, request proceeds without merge. No throw. [Intended — scope: invalid JSON ignored]
- **Provider:** case-insensitive compare; only `openai` accepted.
- **Actions:** must be array of `{ key:string, name:string, prompt:string }` with `key` in `{translate, summary}`. If malformed/empty → sanitize to two defaults (translate keeps honorifics, summary 50–60%).
- **Chunk size / Prefetch N:** numeric string coerced to number; out of range or NaN → `1300` / `3`.
- **Typography:** `fontSize 12..24 step 1`, `lineHeight 1.2..2.0 step 0.1`, `letterSpacing 0..1.0 step 0.1`; invalid → defaults.

## Current Keys Only

There is no legacy migration. Unknown keys — including any `COPILOT`/`DEEPSEEK`/`SUPABASE` or other historical names — are ignored. On launch the store sanitizes only the current keys above against `business-rules.md` BR-12 and persists defaults where needed. Do not add a migration map.

## Links

- Sanitize lifecycle: `docs/product/functional-specs/settings-management.md` States/Cases
- Store: `docs/decisions/local-persistence.md` · Identity: `docs/decisions/book-identity.md` · Typographic rendering: `docs/design/design-system.md` §3, `docs/product/functional-specs/book-reader.md`
