# ADR — Book Package Shape at Archive Root

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Valid package requires `book.json` and `chapters/chapter-N.html` 1-based, but producer contract was not anchored. The local sample `../../docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` has an outer folder plus `__MACOSX` and is not at root. This caused ambiguity for fixtures.

## Decision

- **Producer emits at archive root:** `book.json` and `chapters/chapter-N.html` for `N=1..count` (1-based). Do not nest inside an outer folder.
- **Canonical shape lives in `../contracts/book-package.md`.** This ADR keeps only rationale and sample note.
- **Sample note:** `../../docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` is **tracked, not a fixture** — reference/non-canonical — it wraps payload in `van-gioi-chi-rut-thuong-he-thong/` + `__MACOSX`. Do not treat it as a valid fixture.

## Alternatives

| Option | Reason not chosen |
|---|---|
| Accept outer-folder wrapper | Adds branch for `__MACOSX` and nested root; producer fixes ZIP instead |
| Flatten wrapper on import | Hides producer error; exact-root rule is stricter and testable |
| Allow `chapter-0.html` | Breaks 1-based `N=1..count` invariant |

## Consequences

- Import accepts only the exact archive-root layout (`book.json` + `chapters/` at root) and rejects the current sample shape. The producer must fix the ZIP.
- Tests use root-layout fixtures when they land. The app does not flatten or ignore outer wrappers.
- Keep the sample ZIP untouched in docs-only tasks.

## Amendment 2026-08-26 — Tolerant ingest

- Producer ZIPs thực tế là Finder ZIP với flag 0x08 + outer-folder + `__MACOSX` (như sample). Strict reject gây false invalid.
- Decision: App tolerant single outer-folder + hygiene ignore + data-descriptor support, vẫn giữ strict cho 2+ top-level / missing chapter / CRC fail.
- Consequences: Sample `van-gioi-...zip` giờ import được qua flatten; docs/plans/feat-010 implements.

## Links

- Canonical: `../contracts/book-package.md` · `../contracts/local-data.md` · `../../docs/product/domain-model.md` Invariants · `../../docs/product/functional-specs/book-import.md`
