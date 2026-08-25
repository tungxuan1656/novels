# Technical Decisions — Novels

> ADR index for technical scope. Business decisions stay canonical in `docs/product/decisions.md`. Topology in `ARCHITECTURE.md`. Contracts in `docs/contracts/`.

## Active

| ADR | Title | Status | Links |
|---|---|---|---|
| [ios-scope.md](./ios-scope.md) | iPhone-only, iOS 26+, Vietnamese UI | Accepted | `ARCHITECTURE.md` §1, `docs/product/overview.md`, `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md` |
| [network-logger-removed.md](./network-logger-removed.md) | Remove Network Logger from product/design scope | Accepted | `docs/design/navigation.md`, `docs/design/screens.md`, `SECURITY.md` |
| [ai-service-defaults.md](./ai-service-defaults.md) | Single OpenAI-compatible endpoint and settings defaults | Accepted | `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`, `docs/contracts/catalog-api.md` |
| [book-package-shape.md](./book-package-shape.md) | ZIP producer shape at archive root; sample ZIP non-canonical | Accepted | `docs/contracts/book-package.md`, `docs/contracts/local-data.md` |
| [local-persistence.md](./local-persistence.md) | Native Swift persistence (FileManager+Codable, Application Support, SQLite cache, UserDefaults@Observable, unzipItem, SwiftUI.Text pipeline, URLSession, localhost ATS) | Accepted | `ARCHITECTURE.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`, `docs/contracts/book-package.md`, `docs/contracts/ai-service.md`, `SECURITY.md` |
| [book-identity.md](./book-identity.md) | Local slug identity (`book.json.id`) vs remote numeric catalog ids | Accepted | `docs/contracts/catalog-api.md`, `docs/contracts/book-package.md`, `docs/contracts/local-data.md` |

## Open

- Operational detail: file backup exclusion for Application Support (only if not covered by system defaults). Do not invent a value until needed.

Add new ADRs append-only; do not edit history. Technical ADRs live here; business domain ADRs live in `docs/product/decisions.md`.
