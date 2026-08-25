# Contract — Book Package (ZIP)

> Canonical producer shape for import. Consumers: `../../docs/product/functional-specs/book-import.md`, `../../docs/product/functional-specs/book-library.md`. Domain: `../../docs/product/domain-model.md` Invariants. Catalog: `catalog-api.md`.

## Producer Requirement

A valid package **must** emit at archive root:

```
book.json
chapters/chapter-N.html   # N = 1 .. count, 1-based
```

- `book.json` at the ZIP root (not nested in a subfolder).
- `chapters/chapter-N.html` for every `N` in `1..count`, where `count` is the chapter count declared in `book.json` / `BookMeta.chapterCount`. 1-based, no `chapter-0.html`. [Observed — `domain-model.md` Invariants]
- Valid ZIP contains exactly that layout. App accepts only the exact archive-root layout and rejects any other shape (including outer-folder or `__MACOSX` wrappers). Producer fixes the ZIP; app does not adapt to wrappers.

### book.json

`id` is the string slug that is the local identity (see `../decisions/book-identity.md`). Shape mirrors `Book` + `Reference` list. Minimal required fields:

```json
{
  "id": "van-gioi-chi-rut-thuong-he-thong",
  "name": "Vạn Giới Chi Rút Thưởng Hệ Thống",
  "count": 743,
  "author": "Tinh Không Long Lân",
  "references": [" Chương 1: ... ", " Chương 2: ... "]
}
```

- `id` (string slug) determines the local folder `Application Support/novels/books/<id>/`, the Reader route `bookId`, and SQLite `bookId`. Remote numeric catalog ids do not affect it.
- `count` is a number and must equal `references.length`; each HTML file must exist. Invalid folders are skipped in Library (`book-library.md` Cases).
- Concrete field names are as emitted by the producer; consumers read `book.json` via `Codable` and build `Book`/`Reference` per `domain-model.md`. Treat unknown extra fields as preserved/ignored.

## Import Flow (wire-adjacent)

1. Ensure repository and temp folders exist.
2. Download ZIP from `ExportedBook.exportUrl` to temp.
3. Extract to Local Book Repository expecting the exact root layout; if `book.json` or `chapters/` is not at archive root, the package is invalid and creates no book.
4. Delete ZIP on full success; on any failure show error, create no entry, allow retry. Re-import overwrites same folder. [Observed — BR-02, `flows.md` §2, `book-import.md`]

## Reference Sample — Non-Canonical

- **File:** `../../docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` — **tracked, not a fixture**.
- **Why non-canonical:** ZIP wraps payload in an outer folder `van-gioi-chi-rut-thuong-he-thong/` and includes `__MACOSX/` resource forks; it does **not** have `book.json` at archive root and is therefore rejected by the exact-root rule above.
- Do not treat this ZIP as a valid test fixture and do not change import behavior or the ZIP to accommodate wrappers. Keep it as a reference; do not delete it in docs tasks.

## Cases

| Case | Result |
|---|---|
| Missing `book.json` at root | Fail import, no entry |
| Missing `chapters/chapter-N.html` | Fail import, no entry |
| Network lost during download | Fail, no partial book |
| ZIP delete fails after success | Book remains listed |
| Same book re-imported | Folder replaced |

## Rules

- Require `book.json + chapters/chapter-N.html` at archive root, 1-based, `count == references.length`.
- Reject outer-folder and `__MACOSX` wrappers.
- Treat unknown `book.json` fields as ignored.

## Avoid

- Do not flatten wrappers or strip outer folders.
- Do not duplicate shape in other docs; link here.

## Examples

- Canonical: `book.json` and `chapters/chapter-1.html` .. `chapter-743.html` at ZIP root.

## Verification

- Run `../../init.sh` (format → lint → build).

## Open

- Producer-side generation details beyond root layout are out of scope for the app.
