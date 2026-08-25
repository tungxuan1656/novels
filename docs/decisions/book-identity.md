# ADR — Local Book Identity is `book.json.id` String Slug

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Remote catalog returns numeric `ExportedBook.id` and `ExportedBook.bookId`. Local packages carry `book.json.id` as a string slug (for example `van-gioi-chi-rut-thuong-he-thong`). Identity mapping was open. Coercion between numeric and string risks cache-key mismatch.

## Decision

Use `book.json.id` (string slug) as the sole local identity. Remote numeric ids remain metadata only. The client passes `ExportedBook.exportUrl` as-is and does not coerce numeric ids to strings. Canonical folder and cache key live in `../contracts/local-data.md`.

## Alternatives

| Option | Reason not chosen |
|---|---|
| Numeric `ExportedBook.bookId` as folder | Numeric id can change per export; slug stays stable across imports |
| Numeric `ExportedBook.id` as cache key | Same instability; mismatch with `book.json.id` breaks cache lookup |
| Generate UUID on import | Requires extra mapping and breaks re-import determinism |

## Consequences

- Re-import overwrites the same slug folder; no migration between numeric ids and slugs.
- Navigation `Reading(bookId: string)` and prefetch filter by slug.
- Remote ids display as metadata only.

## Links

- Identity canonical: `../contracts/local-data.md` · Remote types: `../contracts/catalog-api.md` · Package: `../contracts/book-package.md` · Persistence: `local-persistence.md` · Domain: `../../docs/product/domain-model.md`
