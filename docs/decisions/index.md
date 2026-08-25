# Technical Decisions — Novels

> ADR index for technical scope. Business decisions stay canonical in `../../docs/product/decisions.md`. Topology in `../../ARCHITECTURE.md`. Contracts in `../contracts/`.

## Active

| ADR | Title | Status | Links |
|---|---|---|---|
| [ios-scope.md](./ios-scope.md) | iPhone-only, iOS 26+, Vietnamese UI | Accepted | `../../ARCHITECTURE.md` §1, `../../docs/product/overview.md`, `../../docs/design/navigation.md`, `../../docs/design/screens.md`, `../../docs/design/design-system.md` |
| [network-logger-removed.md](./network-logger-removed.md) | Remove Network Logger from product/design scope | Accepted | `../../docs/design/navigation.md`, `../../docs/design/screens.md`, `../../SECURITY.md` |
| [book-package-shape.md](./book-package-shape.md) | ZIP producer shape at archive root; sample ZIP non-canonical | Accepted | `../contracts/book-package.md`, `../contracts/local-data.md` |
| [local-persistence.md](./local-persistence.md) | Native Swift persistence (FileManager+Codable, SQLite cache, UserDefaults@Observable, unzipItem, SwiftUI.Text pipeline, URLSession, localhost ATS) | Accepted | `../../ARCHITECTURE.md`, `../contracts/local-data.md`, `../contracts/settings-schema.md`, `../contracts/book-package.md`, `../contracts/ai-service.md`, `../../SECURITY.md` |
| [book-identity.md](./book-identity.md) | Local slug identity (`book.json.id`) vs remote numeric catalog ids | Accepted | `../contracts/catalog-api.md`, `../contracts/book-package.md`, `../contracts/local-data.md` |

## Superseded

| ADR | Title | Status | Links |
|---|---|---|---|
| [ai-service-defaults.md](./ai-service-defaults.md) | Single OpenAI-compatible endpoint and settings defaults | Superseded by `../contracts/settings-schema.md` | `../contracts/ai-service.md`, `../contracts/settings-schema.md`, `../contracts/catalog-api.md` |

## Open

- Operational detail: file backup exclusion for Application Support (only if not covered by system defaults). Do not invent a value until needed.

Add new ADRs append-only; do not edit history. Technical ADRs live here; business domain ADRs live in `../../docs/product/decisions.md`.
