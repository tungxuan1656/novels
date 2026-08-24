# ADR — Book Package Shape at Archive Root

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Valid package requires `book.json` and `chapters/chapter-N.html` 1-based, but producer contract was not anchored. The local sample `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` has an outer folder plus `__MACOSX` and is not at root, causing ambiguity for fixtures.

## Decision

- **Producer must emit at archive root:** `book.json` and `chapters/chapter-N.html` for `N=1..count` (1-based). Do not nest inside an outer folder.
- **Sample note:** `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` is **local-only, untracked, reference/non-canonical** — it wraps payload in `van-gioi-chi-rut-thuong-he-thong/` + `__MACOSX`. Document it as such in `docs/contracts/book-package.md`; do not treat it as a valid fixture and do not change it in this task.

## Consequence

- Import accepts only the exact archive-root layout (`book.json` + `chapters/` at root) and rejects the current sample shape; the producer must fix the ZIP. Tests must use root-layout fixtures when they land. The app does not flatten, strip, or ignore outer wrappers/`__MACOSX`.
- Keep the sample ZIP staged/deleted untouched in docs-only tasks.

## Links

- `docs/contracts/book-package.md` · `docs/contracts/local-data.md` · `docs/product/domain-model.md` Invariants · `docs/product/functional-specs/book-import.md`
