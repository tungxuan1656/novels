# SECURITY.md — Novels

> No invented credential store, encryption, or log-retention mechanism here.

## Confirmed Boundaries

- **Single user, single device.** No account, no multi-user, no cloud sync, no server-side session. Library and Reader work offline after import (BR-01).
- **Catalog auth:** none. Listing is read-only; download link is public `exportUrl`. See `docs/contracts/catalog-api.md`.
- **AI auth:** not a separate setting. If auth is needed, the user enters it as a JSON object in `AI_CUSTOM_HEADERS` (e.g. `{"Authorization":"Bearer ..."}`) which is merged as headers per request. No secret is hard-coded in docs or business rules. See `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`.
- **Storage for `AI_CUSTOM_HEADERS`:** normal settings storage — `UserDefaults` via `@Observable` (see `docs/decisions/local-persistence.md`). No `Keychain` or special credential store. See `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`.
- **No Network Logger:** removed from product/design (see `docs/decisions/network-logger-removed.md`). No credential or redaction log feature is in scope.
- **Network scope:** only catalog (`BOOKS_API_URL`) and AI (`OPENAI_API_URL`) need network; reading, library, settings sanitize, offset/typography restore do not. ATS exception is `localhost`-only for `http://localhost:8317`.
- **No secrets in repo:** docs and examples contain no real API keys, tokens, or credentials. Use redacted placeholders (`Bearer ...`). Do not add them.

## Sensitive Inputs

- `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` are user-entered JSON strings that may contain credentials (API key lives in `AI_CUSTOM_HEADERS` when needed). Treat their values as sensitive and keep them out of docs/examples. Invalid JSON is ignored (`settings-schema.md`).

## Guidance for Contributors

- Use redacted placeholders in docs (e.g. `{"Authorization":"Bearer ..."}`).
- Link settings handling to `docs/contracts/settings-schema.md` and local boundaries to `docs/contracts/local-data.md` rather than duplicating.
- Do not add `Keychain`, log-retention, or network-logging mechanisms — they are out of scope per `docs/decisions/local-persistence.md`.
