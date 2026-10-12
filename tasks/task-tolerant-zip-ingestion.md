# Tolerant ZIP Ingestion Hotfix

- Status: done
- Owner: Tung Doan
- Required to start: [feat-003](task-catalog-zip-import.md)
- Required to integrate/release: none
- Previous ID: feat-010

## Scope and non-goals

Fix "Gói sách không hợp lệ" errors for valid downloaded ZIP packages containing common archive artifacts (single wrapper folder, macOS metadata entries `__MACOSX/` and `.DS_Store`, and streaming data-descriptor flag `0x08`), superseding strict archive-root rejection from earlier import tasks:
- `FileManagerZIP.unzipItem` adds support for data-descriptor flag `0x08` via trailing descriptor parsing; filters out hygiene entries (`__MACOSX/`, `.DS_Store`, `._*`) during extraction; enforces STORE(0)/DEFLATE(8), CRC32 integrity, 100MB uncompressed size cap, and zip-slip path traversal guards.
- Package resolver detects a single outer wrapper folder containing `book.json` and `chapters/` and flattens it to the canonical root.
- `ZipValidator.isValidRoot` tolerantly ignores hygiene files when enumerating files and chapters.
- `Book` decoding fallback derives slug `id` from `name` if `id` is omitted in legacy packages.
- Update contracts and ADRs: `docs/contracts/book-package.md`, `docs/decisions/book-package-shape.md` (Amendment 2026-08-26), and `ARCHITECTURE.md` §1/§4.

Non-goals: No catalog API changes, no UI modifications, no relaxing security rules (zip-slip traversal, decompression bombs >100MB, CRC mismatches, and unsupported compression methods are still rejected), and no ZIP64 or multi-folder nested archives.

## Acceptance

- [x] ZIP DEFLATE with flag `0x08` (Finder/macOS/Python zipfile) extracts successfully and passes CRC/size
- [x] ZIP that contains `__MACOSX/._*` and `.DS_Store` at root/chapters is ignored, does not create `__MACOSX/` in destination, valid content still imports
- [x] ZIP wrapped in a single outer-folder `wrapper/book.json` + `wrapper/chapters/` is flattened and imports successfully (even with `__MACOSX`)
- [x] Real sample `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` (outer-folder + __MACOSX + flag 0x08, 743 chapters) imports via `ImportViewModel` and shows 743 chapters in Library
- [x] Validator still ignores hygiene but still rejects: missing `book.json`, missing chapter, real extra file beyond hygiene, `count != references.length`
- [x] Security: zip-slip (`../evil`), bomb >100MB, CRC mismatch, method !=0/8 still report `invalidPackage`, no folder created
- [x] `book.json` missing `id` still decodes with derived slug id from `name` and saves successfully
- [x] `./init.sh` PASS (format 0, lint 0, build PASS, test PASS with new cases)

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/book-package.md](../docs/contracts/book-package.md)
- [docs/decisions/book-package-shape.md](../docs/decisions/book-package-shape.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/product/functional-specs/book-import.md](../docs/product/functional-specs/book-import.md)
- [apps/novels/Persistence/](../apps/novels/Persistence/)
- [apps/novels/Features/Import/](../apps/novels/Features/Import/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `swiftformat --lint` 0/63; `swiftlint --strict` 0 violations; `xcodebuild test` passed 127 tests (including ImportViewModel 20/20 covering wrapper flattening, macOS metadata handling, streaming flag `0x08`, and 743-chapter sample package import). Security checks confirmed that zip-slip, bomb, CRC mismatch, and missing chapters remain rejected. Canonical specification updated in `docs/contracts/book-package.md`.
- Blockers: None.
- Next: HISTORICAL: Merge tolerant zip ingestion changes into main branch.
