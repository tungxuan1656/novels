# Contracts — Novels

> Technical wire and storage contracts. Business meaning stays in `docs/product/integrations.md` and `docs/product/domain-model.md`; behavior in `docs/product/functional-specs/*` and `docs/product/flows.md`.

## Index

| Contract | Owns | Links |
|---|---|---|
| [catalog-api.md](./catalog-api.md) | Remote Book Catalog POST wire format, defaults, and failure mapping | `docs/product/integrations.md` §1, `docs/product/functional-specs/book-import.md` |
| [ai-service.md](./ai-service.md) | Single OpenAI-compatible endpoint, chunk/retry/cache, defaults | `docs/product/integrations.md` §2, `docs/product/functional-specs/ai-reading.md`, `docs/product/functional-specs/chapter-prefetch.md` |
| [book-package.md](./book-package.md) | ZIP producer shape (`book.json` + `chapters/chapter-N.html` at root) + sample ZIP note | `docs/product/domain-model.md` Invariants, `docs/product/functional-specs/book-import.md`, `docs/product/functional-specs/book-library.md` |
| [settings-schema.md](./settings-schema.md) | Persistent keys, defaults, validation, JSON-header/body handling | `docs/product/functional-specs/settings-management.md`, `SECURITY.md` |
| [local-data.md](./local-data.md) | Logical local boundaries (repository, ProcessedChapter cache, settings/session/typography); physical technology open | `docs/product/domain-model.md`, `docs/product/functional-specs/book-library.md`, `docs/product/functional-specs/book-reader.md` |

Each file is the canonical source for its wire/storage shape. Do not duplicate payload examples elsewhere — link here.
