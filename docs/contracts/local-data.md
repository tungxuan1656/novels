# Contract — Local Data (Native Physical Stores)

> Canonical local boundaries and their accepted physical stores. Decisions: `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`. Domain: `docs/product/domain-model.md`. Library/Reader: `docs/product/functional-specs/book-library.md`, `book-reader.md`. Prefetch/AI: `chapter-prefetch.md`, `ai-reading.md`.

## Stores (Accepted Native)

| Boundary | Store | Root / file | API |
|---|---|---|---|
| Local Book Repository | File system — `Codable` + `FileManager` | `Application Support/novels/books/<book.json.id slug>/` with `book.json` + `chapters/chapter-N.html` | `Foundation.FileManager` + `FileManager.unzipItem` (strict archive-root validation) |
| ProcessedChapter cache (single) | SQLite via system `libsqlite3` (no Swift package) | `Application Support/novels/cache/processed_chapters.sqlite` | `SQLite3` behind internal protocol; rendering is native `SwiftUI.Text` (no WebKit) |
| Settings / Session / Typography | `UserDefaults` wrapped by `@Observable` | Current keys only; `AI_CUSTOM_HEADERS` stored as normal JSON string (no Keychain) | `Foundation.UserDefaults` + `Observation.@Observable` |
| Runtime-only | In-memory | `PrefetchStatus` `{ isRunning, currentBookId, totalChapters, processedChapters, message, errors[]}` | — |

React Native findings are historical reference only — no RN package and no RN data/settings/cache migration.

## 1. Local Book Repository

- **Identity:** folder name is the string slug `book.json.id` (see `docs/decisions/book-identity.md`). Remote numeric `ExportedBook.id` / `bookId` are metadata only and never used as folder or cache key.
- **Contents:** per book folder with `book.json` at root and `chapters/chapter-N.html` (1-based, `N=1..count`). See `book-package.md`.
- **Operations:** scan `books/` → `Codable` decode `book.json` → list; read `chapters/chapter-N.html` and parse to text spans for `SwiftUI.Text`; delete whole slug folder on Library delete (BR-10). Invalid folders (missing `book.json`) skipped.
- **Lifecycle:** `exportUrl` → `URLSession` download to temp → `FileManager.unzipItem` → validate exact root layout → delete ZIP on success; on failure no entry. See `catalog-api.md`, `book-package.md`.
- **Reference:** https://developer.apple.com/documentation/foundation/filemanager

## 2. ProcessedChapter Cache (Single AI Cache)

SQLite table `processed_chapters` in `processed_chapters.sqlite` under `Application Support/novels/cache/`.

```sql
CREATE TABLE IF NOT EXISTS processed_chapters (
  book_id       TEXT    NOT NULL, -- slug == book.json.id
  chapter_number INTEGER NOT NULL,
  mode          TEXT    NOT NULL, -- 'translate' | 'summary'
  content       TEXT    NOT NULL, -- text (parsed HTML → SwiftUI.Text spans, not raw HTML)
  content_hash  TEXT    NOT NULL,
  created_at    TEXT    NOT NULL,
  updated_at    TEXT    NOT NULL,
  PRIMARY KEY (book_id, chapter_number, mode)
) WITHOUT ROWID;
-- Enforced via PRIMARY KEY; equivalently:
-- UNIQUE(book_id, chapter_number, mode)
CREATE INDEX IF NOT EXISTS idx_processed_chapters_book ON processed_chapters(book_id);
```

- **Key:** `UNIQUE(book_id, chapter_number, mode)` where `book_id` is the slug, `mode` is `AIAction.key`. Upsert via `INSERT OR REPLACE` (or `ON CONFLICT DO UPDATE`). `mode = 'none'` never written.
- **Queries:** `SELECT content FROM processed_chapters WHERE book_id=? AND chapter_number=? AND mode=?`; batch-check for prefetch range `WHERE book_id=? AND mode=? AND chapter_number IN (...)`; `SELECT count(*) WHERE book_id=?` for Cache Manager count.
- **Clear:** `DELETE FROM processed_chapters` (all) or `DELETE WHERE book_id=?` on book delete leaves rows unreachable; no UserDefaults use for cache.
- **De-duplication:** actor-gated single flight per `(book_id, chapter_number, mode)`; prefetch batch skips cached. See `ai-service.md` BR-07.
- **Scope:** persistent across sessions; cleared via Cache Manager. Keep cache separate from files and settings.

## 3. Persistent Settings Store (plus Session & Typography)

- **Store:** `UserDefaults` via `@Observable` wrapper (see `local-persistence.md`). No Keychain, no `SwiftData`/`Core Data`.
- **Keys (current only):** `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `AI_CUSTOM_HEADERS`, `AI_EXTRA_BODY`, `AI_PROVIDER`, `AI_PROCESS_ACTIONS`, `AI_MIN_CHUNK_SIZE`, `PREFETCH_COUNT`, plus `font`, `fontSize`, `lineHeight`, `letterSpacing` and `ReadingSession { bookId: slug, onScreen, offset }`. See `settings-schema.md`.
- **Sanitize:** on launch offline — missing/invalid → defaults; unknown/legacy keys → ignored (no migration); `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON → treated as empty, stored verbatim otherwise. See `business-rules.md` BR-12.

## Dependencies

```
Library ──scan/Codable──► Local Book Repository (Application Support/books/<slug>)
Reader  ──SwiftUI.Text (HTML→spans)──► Local Book Repository ──► Typography (UserDefaults @Observable)
Reader/AI ──SQLite check/save──► ProcessedChapter Cache ──► AI Service (on miss, URLSession)
Prefetch ──SQLite batch-check/save──► ProcessedChapter Cache
Startup ──UserDefaults restore/sanitize──► Settings/Session/Typography
```

## Links

- Decision: `../decisions/local-persistence.md` · Identity: `../decisions/book-identity.md`
- Package shape: `book-package.md` · Catalog/AI: `catalog-api.md`, `ai-service.md` · Rules: `../product/business-rules.md` BR-01, BR-02, BR-07..12
