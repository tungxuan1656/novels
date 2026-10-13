# Contract — Local Data (Native Physical Stores)

> Canonical local boundaries and their accepted physical stores. Decisions: `../decisions/local-persistence.md`, `../decisions/book-identity.md`. Domain: `../../docs/product/domain-model.md`. Library/Reader: `../../docs/product/functional-specs/book-library.md`, `book-reader.md`. Prefetch/AI: `chapter-prefetch.md`, `ai-reading.md`.

## Stores (Accepted Native)

| Boundary | Store | Root / file | API |
|---|---|---|---|
| Local Book Repository | File system — `Codable` + `FileManager` | `Application Support/novels/books/<resolved Book.id slug>/` with `book.json` + `chapters/chapter-N.html` | `Foundation.FileManager` + `FileManager.unzipItem` (tolerant hygiene + wrapper flatten + data-descriptor, strict security invariants preserved) |
| ProcessedChapter cache (single) | SQLite via system `libsqlite3` (no Swift package) | `Application Support/novels/cache/processed_chapters.sqlite` | `SQLite3` behind internal protocol; rendering is native `SwiftUI.Text` (no WebKit) |
| Settings / Session / Typography | `UserDefaults` wrapped by `@Observable` | Current keys only; `AI_API_KEY` and custom JSON stored as normal settings (no Keychain) | `Foundation.UserDefaults` + `Observation.@Observable` |
| Runtime-only | In-memory | `PrefetchStatus` `{ isRunning, currentBookId, totalChapters, processedChapters, message, errors[]}` | — |

React Native findings are historical reference only — no RN package and no RN data/settings/cache migration.

## 1. Local Book Repository

- **Identity:** new imports use resolved `Book.id` as the folder slug. See [package decoding](book-package.md) for `book.json.id` tolerance and [identity decision](../decisions/book-identity.md). Remote numeric catalog ids remain metadata, never folder or cache keys.
- **Existing-folder lookup:** prefer the exact slug folder; otherwise scan validated folders for a case-insensitive decoded ID match, with folder-name fallback. This compatibility lookup does not rename folders.
- **Contents:** per book folder with `book.json` at root and `chapters/chapter-N.html` (1-based, `N=1..count`). See `book-package.md`.
- **Operations:** scan `books/` → `Codable` decode `book.json` → list; read `chapters/chapter-N.html` and parse to one optional title + one plain body string; delete whole slug folder on Library delete (BR-10). Invalid folders (missing `book.json`) skipped.
- **Lifecycle:** `exportUrl` → `URLSession` download to temp → `FileManager.unzipItem` (tolerant hygiene + wrapper flatten + data-descriptor, strict security invariants preserved) → validate (flattened) root layout → delete ZIP on success; on failure no entry. See `catalog-api.md`, `book-package.md`.
- **Observed replacement/recovery:** `FileBookRepository.save` stages validated content, then uses `FileManager.replaceItem` for an existing destination. If replacement fails while the destination remains, it reports failure and removes staging. If the destination disappeared, it falls back to `copyItem`; new imports also copy if moving staging fails. Copy recovery is not atomic: interruption can leave a partial destination. Strict crash-atomic recovery is not implemented.
- **Reference:** https://developer.apple.com/documentation/foundation/filemanager

## 2. ProcessedChapter Cache (Single AI Cache)

SQLite table `processed_chapters` in `processed_chapters.sqlite` under `Application Support/novels/cache/`. Schema uses `WITHOUT ROWID` with `PRAGMA user_version=2` (see `ProcessedChapterCache.swift:75-82`). Fresh installs create the database at `user_version=2`. Databases at `user_version=1` run a one-time `DELETE FROM processed_chapters` then bump to `user_version=2`.

```sql
CREATE TABLE IF NOT EXISTS processed_chapters (
  book_id TEXT NOT NULL,
  chapter_number INTEGER NOT NULL,
  mode TEXT NOT NULL,
  content TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (book_id, chapter_number, mode)
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS idx_processed_chapters_book ON processed_chapters(book_id);
```

- **Key:** `PRIMARY KEY(book_id, chapter_number, mode)` (`WITHOUT ROWID`; equivalently `UNIQUE(book_id, chapter_number, mode)`) where `book_id` is the slug (`ProcessedChapter.bookId` / resolved `Book.id` in Swift), `mode` is `AIMode.rawValue`. Upsert via `INSERT OR REPLACE` (or `ON CONFLICT DO UPDATE`). `mode = 'none'` never written.
- **Content by mode:** `rewrite` stores legacy plain Vietnamese text; `bilingual` stores app-owned JSON `{"version":1,"paragraphs":[{"id":"p001","vi":"...","en":"..."}]}`. Decode only by mode and reject unknown version, empty languages or duplicate IDs. No schema bump, migration or rewrite invalidation; both modes coexist. `content_hash` remains SHA256 of final serialized content.
- **Columns `created_at`/`updated_at`:** `TEXT NOT NULL` storing ISO8601 with fractional seconds (`.withInternetDateTime` + `.withFractionalSeconds`; fallback without fractional seconds on read).
- **Queries:** `SELECT content FROM processed_chapters WHERE book_id=? AND chapter_number=? AND mode=?`; batch-check for prefetch range `WHERE book_id=? AND mode=? AND chapter_number IN (...)`; `SELECT count(*) WHERE book_id=?` for Cache Manager count.
- **Clear:** `DELETE FROM processed_chapters` (all) or `DELETE WHERE book_id=?` on book delete leaves rows unreachable; no UserDefaults use for cache.
- **De-duplication:** `actor`-gated single flight per `(bookId,chapterNumber,mode)`; prefetch batch skips cached. See `ai-service.md` BR-07.
- **Scope:** persistent across sessions; cleared via Cache Manager. Keep cache separate from files and settings.

## 3. Persistent Settings Store (plus Session & Typography)

- **Store:** `UserDefaults` via `@Observable` wrapper (see `../decisions/local-persistence.md`). No `Keychain`, no `SwiftData`/`Core Data`.
- **Keys (current only):** `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `AI_CUSTOM_HEADERS`, `AI_EXTRA_BODY`, `AI_PROVIDER`, `AI_API_KEY`, `AI_THINKING_EFFORT`, `AI_PROMPT`, `AI_BILINGUAL_PROMPT`, `AI_MIN_CHUNK_SIZE`, `PREFETCH_COUNT`, plus `font`, `fontSize`, `lineHeight` and `ReadingSession { bookId: slug, onScreen, offset }`. See `settings-schema.md`.
- **Sanitize:** on launch offline — missing/invalid → defaults; unknown/legacy keys → ignored (no migration); `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON → treated as empty, stored verbatim otherwise. See `../../docs/product/business-rules.md` BR-12.

## Dependencies

```
Library ──scan/Codable──► Local Book Repository (Application Support/books/<slug>)
Reader  ──SwiftUI.Text (HTML→title+body string)──► Local Book Repository ──► Typography (UserDefaults @Observable)
Reader/AI ──SQLite check/save──► ProcessedChapter Cache ──► AI Service (on miss, URLSession)
Prefetch ──SQLite batch-check/save──► ProcessedChapter Cache
Startup ──UserDefaults restore/sanitize──► Settings/Session/Typography
```

## Rules

- Use resolved `Book.id` for new import folders and the `book_id` column (`ProcessedChapter.bookId` in Swift); do not coerce numeric catalog ids.
- Keep single cache `PRIMARY KEY(book_id, chapter_number, mode)` (`WITHOUT ROWID`; equivalently `UNIQUE(book_id, chapter_number, mode)`) with `content_hash, created_at, updated_at` (`contentHash` etc. in Swift).
- Store only under `Application Support/novels/`; no Documents sync.

## Avoid

- Do not create a second AI cache; use `processed_chapters` only.
- Do not use `Keychain`, `SwiftData`, or `Core Data` for these boundaries.
- Do not write cache to `UserDefaults`.

## Examples

- Canonical: `Application Support/novels/books/<slug>/book.json` and `Application Support/novels/cache/processed_chapters.sqlite`.

## Verification

- Run `../../init.sh` (format → lint → build → focused unit tests). Test scope: [verification decision](../decisions/verification.md); no UI tests.

## Links

- Decision: `../decisions/local-persistence.md` · Identity: `../decisions/book-identity.md`
- Package shape: `book-package.md` · Catalog/AI: `catalog-api.md`, `ai-service.md` · Rules: `../../docs/product/business-rules.md` BR-01, BR-02, BR-07..12
