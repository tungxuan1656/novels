# ADR — Single OpenAI-Compatible Endpoint and Defaults

- **Date:** 2026-08-24
- **Status:** Superseded by `../contracts/settings-schema.md` (current keys) and `local-persistence.md`

## Context

Settings exposed multiple AI-related keys and a provider flag. Wire behavior and defaults were not anchored in a contract. Catalog and AI URLs need canonical defaults. Header and body handling and retry, chunk, and cache must align with product docs.

## Decision

- **One AI endpoint:** single OpenAI-compatible `POST` to chat completions. No second service.
- **Canonical defaults live in `../contracts/settings-schema.md`.** This ADR keeps only behavior alignment: chunk ~1300 per request, retry 3× (`1000 ms` after attempt 1, `2000 ms` after attempt 2), single `ProcessedChapter` cache, de-duplication, prefetch `N=3` sequential cancellable.

## Alternatives

| Option | Reason not chosen |
|---|---|
| Two AI endpoints or provider switch | Adds branching and key management; product uses one OpenAI-compatible endpoint |
| `Keychain` for API key | Scope keeps `AI_CUSTOM_HEADERS` in `UserDefaults`; no `Keychain` |
| Custom migration map for legacy keys | Current keys are canonical; unknown and legacy keys are ignored |

## Consequences

- Contracts `../contracts/catalog-api.md`, `../contracts/ai-service.md`, `../contracts/settings-schema.md` are canonical. Product specs link to them.
- Historical detail about open vs current keys no longer drives behavior. Before 2026-08-24 keys were open; now only current keys exist and unknown keys are ignored. No migration map exists.

## Links

- `../contracts/catalog-api.md` · `../contracts/ai-service.md` · `../contracts/settings-schema.md` · `../../SECURITY.md` · `../../ARCHITECTURE.md` §1
