# SECURITY.md — Novels

> No invented credential store, encryption, or log-retention mechanism here.

## Confirmed Boundaries

- **Single user, single device.** No account, no multi-user, no cloud sync, no server-side session. Library and Reader work offline after import (BR-01).
- **Catalog auth:** none. Listing is read-only; download link is public `exportUrl`. See `docs/contracts/catalog-api.md`.
- **AI auth:** not a separate setting. If auth is needed, the user enters it as a JSON object in `AI_CUSTOM_HEADERS` (for example `{"Authorization":"Bearer ..."}`). The app merges this JSON as headers per request. No secret is hard-coded in docs or business rules. See `docs/contracts/ai-service.md` and `docs/contracts/settings-schema.md`.
- **Storage for `AI_CUSTOM_HEADERS`:** `UserDefaults` via `@Observable`. No `Keychain`. See `docs/contracts/local-data.md` and `docs/contracts/settings-schema.md`.
- **No Network Logger:** removed from product and design (see `docs/decisions/network-logger-removed.md`). No credential or redaction log feature is in scope.
- **Network scope:** only catalog (`BOOKS_API_URL`) and AI (`OPENAI_API_URL`) need network. Reading, library, settings sanitize, offset, and typography restore need no network. ATS exception is `localhost`-only for `http://localhost:8317`.
- **No secrets in repo:** docs and examples contain no real API keys, tokens, or credentials. Use redacted placeholders (`Bearer ...`). Do not add them.

## Sensitive Inputs

- `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` are user-entered JSON strings. They can contain credentials (API key lives in `AI_CUSTOM_HEADERS` when needed). Treat their values as sensitive and keep them out of docs and examples. The app ignores invalid JSON (see `docs/contracts/settings-schema.md`).

## Guidance for Contributors

- Use redacted placeholders in docs (for example `{"Authorization":"Bearer ..."}`).
- Link settings handling to `docs/contracts/settings-schema.md` and local boundaries to `docs/contracts/local-data.md` rather than duplicating.
- Do not add `Keychain`, log-retention, or network-logging mechanisms. They are out of scope. See `docs/decisions/local-persistence.md`.
