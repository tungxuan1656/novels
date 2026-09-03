# feat-010 — Tolerant ZIP Ingestion Hotfix

## Goal

Fix error "Gói sách không hợp lệ" for valid downloaded ZIPs that match sample shape (outer-folder + `__MACOSX`/`.DS_Store` + data-descriptor flag `0x08`), while keeping zip-slip/CRC/bomb/method security checks.

## Scope

- `FileManagerZIP.unzipItem` supports data-descriptor (flag 0x08) via trailing descriptor parsing, filters hygiene entries `__MACOSX/`, `.DS_Store`, `._*` instead of throwing, keeps whitelist STORE(0)/DEFLATE(8), CRC32, 100MB cap, and zip-slip prefix check
- Resolver `resolveCanonicalRoot` detects a single outer-folder that contains `book.json`+`chapters/` and flattens it to the canonical root
- `ZipValidator.isValidRoot` tolerantly ignores hygiene entries when enumerating top level and chapters
- `Book` decode fallback derives `id` slug from `name` when `id` is missing (legacy sample)
- `ImportViewModel.importBook` calls the resolver after unzip and before validator/save
- Update contracts/docs: `docs/contracts/book-package.md`, `docs/decisions/book-package-shape.md` (Amendment 2026-08-26), `ARCHITECTURE.md:14`, `docs/contracts/local-data.md`

## Non-goals

- No catalog API change, no Library/AddBook/Reader UI change, no SQLite cache or Settings schema change
- No security relaxation: still reject `..`, `/`, `C:`, bomb >100MB, CRC mismatch, method other than 0/8, missing chapter, `count != references.length`
- No ZIP64/encryption support, no handling for multi outer-folder (single wrapper only)

## Acceptance

- [x] ZIP DEFLATE with flag `0x08` (Finder/macOS/Python zipfile) extracts successfully and passes CRC/size
- [x] ZIP that contains `__MACOSX/._*` and `.DS_Store` at root/chapters is ignored, does not create `__MACOSX/` in destination, valid content still imports
- [x] ZIP wrapped in a single outer-folder `wrapper/book.json` + `wrapper/chapters/` is flattened and imports successfully (even with `__MACOSX`)
- [x] Real sample `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` (outer-folder + __MACOSX + flag 0x08, 743 chapters) imports via `ImportViewModel` and shows 743 chapters in Library
- [x] Validator still ignores hygiene but still rejects: missing `book.json`, missing chapter, real extra file beyond hygiene, `count != references.length`
- [x] Security: zip-slip (`../evil`), bomb >100MB, CRC mismatch, method !=0/8 still report `invalidPackage`, no folder created
- [x] `book.json` missing `id` still decodes with derived slug id from `name` and saves successfully
- [x] `./init.sh` PASS (format 0, lint 0, build PASS, test PASS with new cases)

## Relevant docs

- `docs/contracts/book-package.md` (canonical + tolerant amendment)
- `docs/decisions/book-package-shape.md` (ADR + Amendment 2026-08-26)
- `docs/contracts/local-data.md` (FileManager unzip tolerant)
- `ARCHITECTURE.md` §1, §4 Flows Import
- `docs/product/functional-specs/book-import.md`, `docs/product/domain-model.md` Invariants

## Plan

Substantial: >=4 files, needs phases — external plan `docs/plans/feat-010.md` (6 tasks, each task TDD: test fail → implement → pass → commit).

- Link: `docs/plans/feat-010.md` (accepted design 2026-08-26 — tolerant wrapper+hygiene+flag08)

## Verify

- `./init.sh`
- `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: done
- Evidence: branch feat/010-tolerant-zip 10 commits c711c31..2749857 — 315c0a5 chore(plan), a2ef1b9 flag08+hygiene, 003b682 lint clean, a4cd8aa wrapper flatten, 9ef31f7 dedupe hygiene, 917d6c3 validator hygiene, 98ed7b4 Book id fallback, 8d7e806 fallback tests, d1c372d docs tolerant, 2749857 tolerant tests+fixtures; SDD ledger .agent-work/sdd/feat-010/progress.md 6 tasks + final review clean; Task reviews ora-1..ora-10 all Approved (fix rounds 1/5 where needed); swiftformat 0/63, swiftlint --strict 0, xcodebuild test 127 PASS (ImportViewModel 20/20 incl. synthetic wrapper+__MACOSX+flag08, real sample 743 chapters, zip-slip/bomb/CRC/missing-chapter still reject), docs/samples/van-gioi-chi-rut-thuong-he-thong.zip 1.9M preserved; ARCHITECTURE.md:14, book-package.md 16-19, local-data.md, book-package-shape.md Amendment 2026-08-26 updated
- Blockers: none
- Next: Merge feat/010-tolerant-zip → main (or PR) — `git checkout main && git merge --no-ff feat/010-tolerant-zip && git push` — sample now importable tolerant via flatten
