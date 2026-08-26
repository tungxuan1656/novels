# feat-010 — Tolerant ZIP Ingestion Hotfix

## Goal

Sửa lỗi "Gói sách không hợp lệ" với ZIP tải về hợp lệ dạng samples (outer-folder + `__MACOSX`/`.DS_Store` + flag data-descriptor `0x08`), giữ an toàn zip-slip/CRC/bomb/method.

## Scope

- `FileManagerZIP.unzipItem` hỗ trợ data-descriptor (flag 0x08) via trailing descriptor parsing, lọc hygiene `__MACOSX/`, `.DS_Store`, `._*` thay vì throw, giữ whitelist STORE(0)/DEFLATE(8), CRC32, 100MB cap, zip-slip prefix check
- Resolver `resolveCanonicalRoot` phát hiện single outer-folder duy nhất chứa `book.json`+`chapters/` và flatten về canonical root
- `ZipValidator.isValidRoot` tolerant ignore hygiene khi enumerate top/chapters
- `Book` decode fallback derive `id` slug từ `name` khi thiếu `id` (sample cũ)
- `ImportViewModel.importBook` gọi resolver sau unzip trước validator/save
- Cập nhật contracts/docs: `docs/contracts/book-package.md`, `docs/decisions/book-package-shape.md` (Amendment 2026-08-26), `ARCHITECTURE.md:14`, `docs/contracts/local-data.md`

## Non-goals

- Không đổi API catalog, không đổi UI Library/AddBook/Reader, không đổi SQLite cache hay Settings schema
- Không nới lỏng bảo mật: vẫn reject `..`, `/`, `C:`, bomb >100MB, CRC mismatch, method khác 0/8, missing chapter, `count != references.length`
- Không hỗ trợ ZIP64/encryption, không xử lý multi outer-folder (chỉ single wrapper)

## Acceptance

- [ ] ZIP DEFLATE với flag `0x08` (Finder/macOS/Python zipfile) giải nén thành công và pass CRC/size
- [ ] ZIP có `__MACOSX/._*` và `.DS_Store` ở root/chapters được bỏ qua, không tạo `__MACOSX/` trong đích, valid content vẫn import
- [ ] ZIP bọc single outer-folder `wrapper/book.json` + `wrapper/chapters/` được flatten và import thành công (cả khi kèm `__MACOSX`)
- [ ] Sample thực `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` (outer-folder + __MACOSX + flag 0x08, 743 chapters) import được qua `ImportViewModel` và hiện đủ 743 chapters trong Library
- [ ] Validator vẫn ignore hygiene nhưng vẫn reject: missing `book.json`, missing chapter, extra file thực sự ngoài hygiene, `count != references.length`
- [ ] Bảo mật: zip-slip (`../evil`), bomb >100MB, CRC mismatch, method !=0/8 vẫn báo `invalidPackage`, không tạo folder
- [ ] `book.json` thiếu `id` vẫn decode với id derived slug từ `name` và save thành công
- [ ] `./init.sh` PASS (format 0, lint 0, build PASS, test PASS với cases mới)

## Relevant docs

- `docs/contracts/book-package.md` (canonical + tolerant amendment)
- `docs/decisions/book-package-shape.md` (ADR + Amendment 2026-08-26)
- `docs/contracts/local-data.md` (FileManager unzip tolerant)
- `ARCHITECTURE.md` §1, §4 Flows Import
- `docs/product/functional-specs/book-import.md`, `docs/product/domain-model.md` Invariants

## Plan

Substantial: >=4 files, cần phases — external plan `docs/plans/feat-010.md` (6 tasks, mỗi task TDD: test fail → implement → pass → commit).

- Link: `docs/plans/feat-010.md` (accepted design 2026-08-26 — tolerant wrapper+hygiene+flag08)

## Verify

- `./init.sh`
- `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: docs/plans/feat-010.md (6 tasks) + explorer evidence ses_fc27a0978ffe7cqfUUyGVzqYQX + ses_fc2793f38ffe3k2lGcE6rIJdRl — sample unzip -l 1492 files, flag 0x08 trên mọi DEFLATE, outer-folder `van-gioi-.../` + 746 __MACOSX
- Blockers: none
- Next: Review `docs/plans/feat-010.md` → activate feat-010 → execute tasks via @fixer lanes
