# SECURITY.md — Novels

> No invented credential store, encryption, or log-retention mechanism here.

## Confirmed Boundaries

- **Single user, single device.** No account, no multi-user, no cloud sync, no server-side session. Library and Reader work offline after import (BR-01).
- **Catalog auth:** none. Listing is read-only; download link is public `exportUrl`. See `docs/contracts/catalog-api.md`.
- **AI auth:** the masked `AI_API_KEY` setting generates `Authorization: Bearer ...`. Custom `AI_CUSTOM_HEADERS` authentication wins case-insensitively. Native Anthropic authentication still uses custom `x-api-key`; the app does not convert Bearer. No secret is hard-coded in docs or business rules. See `docs/contracts/ai-service.md` and `docs/contracts/settings-schema.md`.
- **Storage for `AI_API_KEY` and `AI_CUSTOM_HEADERS`:** `UserDefaults` via `@Observable`. No `Keychain`. See `docs/contracts/local-data.md` and `docs/contracts/settings-schema.md`.
- **No persisted Network Logger:** removed from product and design (see `docs/decisions/network-logger-removed.md`). In-session diagnostic timeline only, with redaction per `docs/decisions/diagnostic-log-viewer.md`. No credential at-rest, no retention.
- **Network scope:** catalog (`BOOKS_API_URL`), AI (`OPENAI_API_URL`), and explicit Google sentence lookup need network. Google lookup opens the system browser sheet and sends only the selected sentence in a search query, never a chapter automatically. No scraping or Google account/API integration. English speech uses the iOS synthesizer; voices may need an initial system download. Reading, library, settings sanitize, offset, and typography restore need no network. ATS permits insecure HTTP for the `localhost` domain and its subdomains, without a port restriction. Port `8317` belongs to the default endpoint.
- **No secrets in repo:** docs and examples contain no real API keys, tokens, or credentials. Use redacted placeholders (`Bearer ...`). Do not add them.

## Sensitive Inputs

- `AI_API_KEY` and custom JSON settings can contain credentials. Mask the key in Settings and redact authentication headers in diagnostics. Treat their values as sensitive and keep them out of docs and examples. The app ignores invalid JSON (see `docs/contracts/settings-schema.md`).

## Guidance for Contributors

- Use redacted placeholders in docs (for example `{"Authorization":"Bearer ..."}`).
- Link settings handling to `docs/contracts/settings-schema.md` and local boundaries to `docs/contracts/local-data.md` rather than duplicating.
- Do not add `Keychain` or persisted log-retention/network-logging mechanisms. In-session diagnostics only per `docs/decisions/diagnostic-log-viewer.md`. See `docs/decisions/local-persistence.md`.
