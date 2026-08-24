# ADR — Local Book Identity is `book.json.id` String Slug

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Remote catalog returns numeric `ExportedBook.id` and `ExportedBook.bookId`; local packages carry `book.json.id` as a string slug (e.g. `van-gioi-chi-rut-thuong-he-thong`). Identity mapping was open, risking numeric↔string coercion or cache-key mismatch.

## Decision

- **Local identity:** `book.json.id` (string slug) is the sole local identity for a book. It determines the repository folder name, the Reader route `bookId` param, `ReadingSession.bookId`, `Typography` association, and the SQLite `processed_chapters.book_id`.
- **Remote ids are metadata only:** `ExportedBook.id` and `ExportedBook.bookId` (both `number` per `docs/contracts/catalog-api.md`) are displayed/stored as metadata; they are not coerced to or from the slug and never used as the local folder or cache key.
- **Client behavior:** on import, the client passes `ExportedBook.exportUrl` to download; it does not construct URLs from ids and does not coerce ids to strings. After extraction it reads `book.json.id` and uses that slug for all local operations.
- **Cache key normalization:** `ProcessedChapter` cache key is `book_id(slug) + chapter_number + mode` per `docs/contracts/local-data.md`; remote numeric ids do not appear in the key.

## Consequences

- Folder path: `Application Support/novels/books/<slug>/` where `<slug> == book.json.id`.
- Deleting a book removes `.../books/<slug>/` and makes its `book_id == <slug>` cache entries unreachable; re-import overwrites the same slug folder.
- Navigation `Reading(bookId: string)` carries the slug; restoring offset and prefetch both filter by slug.
- No migration or fallback between numeric catalog ids and local slugs.

## Links

- `docs/contracts/catalog-api.md` (remote numeric types) · `docs/contracts/book-package.md` (`book.json.id` slug) · `docs/contracts/local-data.md` (folder + SQLite `book_id`) · `docs/decisions/local-persistence.md` · `docs/product/domain-model.md`
