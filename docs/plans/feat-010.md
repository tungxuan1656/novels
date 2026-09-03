# Tolerant ZIP Ingestion Hotfix Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix ZIP extraction that reports "Gói sách không hợp lệ" for valid files that match the sample shape (outer-folder + `__MACOSX` + flag data-descriptor `0x08`), while keeping safety checks (zip-slip, bomb, CRC, method).

**Architecture:** Tolerant ingest with 3 layers: (1) `FileManagerZIP.unzipItem` supports data-descriptor (flag 0x08) and filters hygiene entries (`__MACOSX`, `.DS_Store`, `._*`) instead of throwing; (2) resolver detects a single outer-folder that contains `book.json`/`chapters` and flattens it to the canonical root; (3) `ZipValidator` tolerantly ignores hygiene entries when counting. Keep whitelist STORE(0)/DEFLATE(8), CRC32, 100MB cap, and path traversal check.

**Tech Stack:** Swift 5 / SwiftUI / Xcode novels (iOS 26.5), Foundation FileManager + Data + Compression, libz `inflateInit2(-15)` raw deflate, SQLite3 cache, URLSession, XCTest + `FileManager.zipItem` test helper, and Python `zipfile` for fixture flag 0x08.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI — single reader offline-first (ARCHITECTURE.md §1)
- Single SwiftUI module `apps/novels` (scheme `novels`, Swift 5.0, DEVELOPMENT_TEAM M5U4E4H84J) — no SwiftPM/Node
- Local Book Repository `Application Support/novels/books/<slug>/` via `FileManager` + `Codable` (docs/contracts/local-data.md)
- `book.json` canonical `book.json` + `chapters/chapter-N.html` N=1..count 1-based, `count == references.length` (docs/contracts/book-package.md:7-16)
- File handling `FileManager.unzipItem` + `ZipValidator.isValidRoot` (ARCHITECTURE.md §1,14)
- Security: zip-slip reject `..`, `/`, `C:`, resolved path prefix check, 100MB total cap, CRC32, only STORE(0)/DEFLATE(8), no Keychain/BGTask/WebKit
- Toolchain SwiftLint 0.65.1 + SwiftFormat 0.62.1, verification `init.sh` (format → lint → build → test)
- Do not delete `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` (tracked reference, outer-folder + __MACOSX)

---

## File Structure

- **Modify:** `apps/novels/Persistence/FileManagerZIP.swift` — core unzip loop: data-descriptor, hygiene filter, wrapper collect
- **Modify:** `apps/novels/Persistence/ZipValidator.swift` — tolerant hygiene ignore, canonical root helper
- **Create (optional small helper):** `apps/novels/Persistence/ZipRootResolver.swift` — `resolveCanonicalRoot(at:)` shared giữa FileManagerZIP & Validator (nếu giữ riêng thì inline vào FileManagerZIP)
- **Modify:** `apps/novels/Domain/Book.swift` — add `BookTolerant` decode fallback when `id` is missing
- **Modify:** `apps/novels/Persistence/BookRepository.swift` — use tolerant validator and slug derive fallback
- **Modify:** `apps/novels/Features/Import/ImportViewModel.swift` — gọi resolver sau unzip trước validator/save
- **Modify:** `docs/contracts/book-package.md`, `docs/decisions/book-package-shape.md`, `ARCHITECTURE.md` — cập nhật tolerant contract/ADR
- **Modify Tests:** `apps/novelsTests/ImportViewModelTests.swift`, `apps/novelsTests/BookRepositoryTests.swift`, `apps/novelsTests/FileManagerZIPTests.swift` (nếu tồn tại) — thêm cases tolerant
- **Create:** `apps/novelsTests/Fixtures/TolerantFixtures.swift` (helper tạo ZIP flag 0x08 + wrapper bằng Python zipfile hoặc Swift)

---

### Task 1: FileManagerZIP — Support data-descriptor (flag 0x08) + hygiene filter

**Files:**
- Modify: `apps/novels/Persistence/FileManagerZIP.swift:430-540`
- Test: `apps/novelsTests/ImportViewModelTests.swift` + `BookRepositoryTests.swift`

**Interfaces:**
- Consumes: `Data` ZIP bytes, `crcTable`, `inflateRawDeflate`, `decompressDeflate`
- Produces: `func unzipItem(at: URL, to: URL) throws` tolerant (không throw with flag 0x08 hay __MACOSX), `func isHygieneEntry(_ name: String) -> Bool`

- [ ] **Step 1: Write failing test for flag 0x08 and __MACOSX**

```swift
// apps/novelsTests/ImportViewModelTests.swift — thêm helper
func makeDeflateWithDescriptorZip(at url: URL, files: [String: Data]) throws {
    // Dùng Python: python3 -c "import zipfile; z=zipfile.ZipFile(...); ..." with allowZip64=False
    // Hoặc Swift: thủ công set flag 0x08 and compSize=0, append descriptor 0x08074B50 + crc + comp + uncomp
}
func testUnzipAcceptsDataDescriptorFlag() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let zipURL = tmp.appendingPathComponent("flag08.zip")
    // Tạo ZIP with book.json + chapters/chapter-1.html dùng DEFLATE + flag 0x08
    try makeDeflateWithDescriptorZip(at: zipURL, files: ["book.json": #"{"id":"t","name":"T","count":1,"author":"A","references":["C1"]}"#.data(using:.utf8)!, "chapters/chapter-1.html": Data("<p>hi</p>".utf8)])
    let out = tmp.appendingPathComponent("out")
    XCTAssertNoThrow(try FileManager.default.unzipItem(at: zipURL, to: out))
    XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("book.json").path))
}
func testUnzipIgnoresMacOSXAlongsideValid() throws {
    // Gộp valid ZIP + __MACOSX/._book.json 163B — must unzip thành công and không tạo __MACOSX/
}
```

- [ ] **Step 2: Run test to confirm FAIL**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/ImportViewModelTests/testUnzipAcceptsDataDescriptorFlag`
Expected: FAIL with `CocoaError.fileReadCorruptFile` tại `flag & 0x08 !=0`

- [ ] **Step 3: Implement hygiene filter + data-descriptor**

```swift
// FileManagerZIP.swift — thêm helper
private func isHygieneEntry(_ name: String) -> Bool {
    if name.hasPrefix("__MACOSX/") || name.contains("/__MACOSX/") { return true }
    if name == ".DS_Store" || name.hasSuffix("/.DS_Store") { return true }
    if name.hasPrefix("._") || name.contains("/._") { return true }
    // com.apple.provenance fork
    if name.contains("/._") { return true }
    return false
}

// Trong unzipItem loop, thay:
// if flag & 0x08 !=0 { throw }
// Bằng:
let isDescriptor = (flag & 0x08) != 0
let headerCompSize = compSize
let headerUncompSize = uncompSize
let headerCrc = crcHeader
// Nếu isDescriptor and header sizes ==0 → will đọc descriptor sau data
// Hygiene skip trước whitelist:
if isHygieneEntry(fileName) {
    // Nếu descriptor, vẫn need skip đúng số byte fileData + descriptor
    if isDescriptor {
        // Tìm descriptor: tìm 0x08074B50 hoặc đọc 12/16 bytes sau data
        // Dùng scanning: từ dataStart, tìm next local header sig 0x04034B50 / central 0x02014B50 / EOCD 0x06054B50
        // Tính compSize thực = nextHeaderPos - dataStart - descriptorLen
        // Đọc descriptor 12 bytes (crc, comp, uncomp) hoặc 16 nếu có signature
    } else {
        pos = dataEnd
    }
    continue // không ghi, không throw
}
if !isAllowedFileName(fileName) {
    // Nếu is hygiene already skip, không to đây. Nếu is outer-folder file như "wrapper/book.json" → tạm allows ghi vào wrapper subpath
    // Thay whitelist strict bằng: nếu fileName chứa "/" and segment đầu != "chapters" and != "book.json" → allows ghi tạm to resolver xử lý, chỉ reject zip-slip
    if hasPathTraversal(fileName) { throw CocoaError(.fileReadCorruptFile) }
    // Cho phép ghi tạm outer-folder: không throw, will flatten sau
    // Nhưng vẫn reject nếu method !=0/8 hoặc vượt cap
}
// Với isDescriptor: decompress need đọc descriptor to lấy crc/comp/uncomp thực
// Nếu headerCrc==0 && isDescriptor → sau khi decompress, đọc descriptor bytes 12/16 từ data, parse crcReal/compReal/uncompReal, dùng to verify thay vì header
```

Chi tiết descriptor parsing:

```swift
private func readDescriptor(at pos: Int, data: Data) -> (crc: UInt32, comp: UInt32, uncomp: UInt32, len: Int)? {
    // Signature optional 0x08074B50
    if pos + 16 <= data.count {
        let sig = UInt32(data[pos]) | UInt32(data[pos+1])<<8 | UInt32(data[pos+2])<<16 | UInt32(data[pos+3])<<24
        if sig == 0x0807_4B50 {
            let crc = UInt32(data[pos+4])|UInt32(data[pos+5])<<8|UInt32(data[pos+6])<<16|UInt32(data[pos+7])<<24
            let comp = UInt32(data[pos+8])|UInt32(data[pos+9])<<8|UInt32(data[pos+10])<<16|UInt32(data[pos+11])<<24
            let uncomp = UInt32(data[pos+12])|UInt32(data[pos+13])<<8|UInt32(data[pos+14])<<16|UInt32(data[pos+15])<<24
            return (crc, comp, uncomp, 16)
        }
    }
    if pos + 12 <= data.count {
        let crc = UInt32(data[pos])|UInt32(data[pos+1])<<8|UInt32(data[pos+2])<<16|UInt32(data[pos+3])<<24
        let comp = UInt32(data[pos+4])|UInt32(data[pos+5])<<8|UInt32(data[pos+6])<<16|UInt32(data[pos+7])<<24
        let uncomp = UInt32(data[pos+8])|UInt32(data[pos+9])<<8|UInt32(data[pos+10])<<16|UInt32(data[pos+11])<<24
        return (crc, comp, uncomp, 12)
    }
    return nil
}
```

- [ ] **Step 4: Run test again to confirm PASS**

Run: `xcodebuild test ... -only-testing:novelsTests/ImportViewModelTests/testUnzipAcceptsDataDescriptorFlag` → PASS
Run: `testUnzipIgnoresMacOSXAlongsideValid` → PASS, `out/__MACOSX` không tồn tại

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Persistence/FileManagerZIP.swift apps/novelsTests/ImportViewModelTests.swift
git commit -m "fix(zip): support data-descriptor flag 0x08 and ignore __MACOSX/.DS_Store hygiene"
```

---

### Task 2: Canonical root resolver + wrapper flatten

**Files:**
- Modify: `apps/novels/Persistence/FileManagerZIP.swift` (thêm `resolveCanonicalRoot`)
- Modify: `apps/novels/Persistence/ZipValidator.swift`
- Modify: `apps/novels/Features/Import/ImportViewModel.swift:116`

**Interfaces:**
- Consumes: `FileManager`, `ZipValidator.isValidRoot`, `unzipItem` output
- Produces: `func resolveCanonicalRoot(at url: URL, fileManager: FileManager) -> URL`

- [ ] **Step 1: Write failing test for wrapper**

```swift
func testUnzipFlattensSingleOuterFolder() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    // Tạo folder wrapper/book.json + wrapper/chapters/chapter-1.html rồi zip with shouldKeepParent=true
    let src = tmp.appendingPathComponent("src"); try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
    let wrapper = src.appendingPathComponent("my-book"); try FileManager.default.createDirectory(at: wrapper, withIntermediateDirectories: true)
    try #"{"id":"my-book","name":"My","count":1,"author":"A","references":["C1"]}"#.write(to: wrapper.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
    let ch = wrapper.appendingPathComponent("chapters"); try FileManager.default.createDirectory(at: ch, withIntermediateDirectories: true)
    try "<p>hi</p>".write(to: ch.appendingPathComponent("chapter-1.html"), atomically: true, encoding: .utf8)
    let zip = tmp.appendingPathComponent("wrapper.zip")
    try FileManager.default.zipItem(at: wrapper, to: zip, shouldKeepParent: true) // tạo outer-folder
    let out = tmp.appendingPathComponent("out"); try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try FileManager.default.unzipItem(at: zip, to: out)
    let canonical = FileManager.default.resolveCanonicalRoot(at: out) // hoặc ZipValidator.findCanonicalRoot
    XCTAssertTrue(ZipValidator.isValidRoot(at: canonical))
    XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.appendingPathComponent("book.json").path))
}
func testImportWrapperSampleSucceeds() async throws {
    // Use docs/samples/van-gioi-chi-rut-thuong-he-thong.zip real file — after fix it imports successfully
    // Hoặc synthetic mirror sample with shouldKeepParent + __MACOSX injection
}
```

- [ ] **Step 2: Run to confirm FAIL**

Run: `xcodebuild test ... -only-testing:novelsTests/ImportViewModelTests/testUnzipFlattensSingleOuterFolder` → FAIL `isValidRoot` false

- [ ] **Step 3: Implement resolver**

```swift
// FileManagerZIP.swift hoặc ZipRootResolver.swift
extension FileManager {
    func resolveCanonicalRoot(at url: URL) -> URL {
        if ZipValidator.isValidRoot(at: url, fileManager: self) { return url }
        guard let top = try? contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return url }
        // Lọc hygiene
        let filtered = top.filter { !isHygieneEntry($0.lastPathComponent) && $0.lastPathComponent != ".DS_Store" }
        // Chỉ khi đúng 1 subfolder duy nhất
        guard filtered.count == 1, let single = filtered.first else { return url }
        var isDir: ObjCBool = false
        _ = fileExists(atPath: single.path, isDirectory: &isDir)
        guard isDir.boolValue else { return url }
        // Kiểm tra single có chứa book.json + chapters hợp lệ (dùng tolerant validator)
        if ZipValidator.isValidRoot(at: single, fileManager: self) { return single }
        return url
    }
}
// ImportViewModel.swift
let canonical = FileManager.default.resolveCanonicalRoot(at: tmpUnzip)
guard ZipValidator.isValidRoot(at: canonical) else { throw ImportError.invalidPackage }
let book = try JSONDecoder().decode(Book.self, from: Data(contentsOf: canonical.appendingPathComponent("book.json")))
try FileBookRepository(root: repoRoot).save(validatedRoot: canonical, slug: book.id)
```

Keep safety: flatten only when there is exactly 1 folder, do not flatten when there are 2+ top-level entries, do not flatten when canonical is already valid.

- [ ] **Step 4: Run again to confirm PASS**

Run: `testUnzipFlattensSingleOuterFolder` PASS, `testImportWrapperSampleSucceeds` PASS

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Persistence/FileManagerZIP.swift apps/novels/Persistence/ZipValidator.swift apps/novels/Features/Import/ImportViewModel.swift apps/novelsTests/ImportViewModelTests.swift
git commit -m "fix(zip): flatten single outer-folder wrapper to canonical root"
```

---

### Task 3: ZipValidator tolerant hygiene

**Files:**
- Modify: `apps/novels/Persistence/ZipValidator.swift:9-99`
- Test: `apps/novelsTests/BookRepositoryTests.swift`

**Interfaces:**
- Consumes: `FileManager.contentsOfDirectory`, `Book` decode
- Produces: `static func isValidRoot(at url: URL, fileManager: FileManager) -> Bool` tolerant

- [ ] **Step 1: Write failing test**

```swift
func testValidatorToleratesDSStoreAndMacOSX() {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    // Tạo valid root rồi thêm .DS_Store + __MACOSX/._book.json
    try! validBookJSON.write(to: tmp.appendingPathComponent("book.json"), atomically: true, encoding: .utf8)
    let ch = tmp.appendingPathComponent("chapters"); try! FileManager.default.createDirectory(at: ch, withIntermediateDirectories: true)
    try! "<p>".write(to: ch.appendingPathComponent("chapter-1.html"), atomically: true, encoding: .utf8)
    FileManager.default.createFile(atPath: tmp.appendingPathComponent(".DS_Store").path, contents: Data())
    let mac = tmp.appendingPathComponent("__MACOSX"); try! FileManager.default.createDirectory(at: mac, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: mac.appendingPathComponent("._book.json").path, contents: Data(repeating: 0, count: 163))
    XCTAssertTrue(ZipValidator.isValidRoot(at: tmp)) // hiện FAIL
}
func testValidatorStillRejectsMissingChapter() { XCTAssertFalse(...) }
```

- [ ] **Step 2: Chạy FAIL**

Run: `xcodebuild test ... -only-testing:novelsTests/BookRepositoryTests/testValidatorToleratesDSStoreAndMacOSX` → FAIL

- [ ] **Step 3: Implement tolerant handling**

```swift
// ZipValidator.swift — in isValidRoot, lọc hygiene trước khi validate
let hygieneNames: Set<String> = [".DS_Store", "__MACOSX", "._.DS_Store"]
func isHygiene(_ name: String) -> Bool {
    if name == ".DS_Store" || name == "__MACOSX" { return true }
    if name.hasPrefix("._") { return true }
    return false
}
// Khi enumerate topContents: nếu isHygiene(name) → continue (bỏ qua)
// Tương tự chapters: chỉ đếm file matching chapter-N.html, bỏ qua .DS_Store/._* in chapters/
```

Giữ reject for outer-folder thực (không must hygiene) khi không qua resolver — nhưng resolver already flatten nên validator tolerant chỉ need ignore hygiene.

- [ ] **Step 4: PASS**

Run: `testValidatorToleratesDSStoreAndMacOSX` PASS, existing `testValidatorRejectsWrapper` vẫn FAIL khi không qua resolver (đảm bảo strict gốc vẫn giữ khi không flatten), nhưng qua resolver thì PASS

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Persistence/ZipValidator.swift apps/novelsTests/BookRepositoryTests.swift
git commit -m "fix(zip): validator ignores .DS_Store/__MACOSX hygiene"
```

---

### Task 4: Book id fallback (sample thiếu id)

**Files:**
- Modify: `apps/novels/Domain/Book.swift`
- Modify: `apps/novels/Persistence/BookRepository.swift:71`
- Modify: `apps/novels/Persistence/ZipValidator.swift` (decode)

**Interfaces:**
- Consumes: `Data` book.json
- Produces: `Book` with id luôn có (derive nếu thiếu)

- [ ] **Step 1: Write failing test**

```swift
func testBookDecodeFallsBackWhenIdMissing() throws {
    let json = #"{"name":"Vạn Giới","count":1,"author":"A","references":["C1"]}"#.data(using:.utf8)!
    // Hiện decode Book fail vì thiếu id
    XCTAssertNoThrow(try JSONDecoder().decode(Book.self, from: json))
}
```

- [ ] **Step 2: Chạy FAIL**

Run: `xcodebuild test ...` → FAIL decode

- [ ] **Step 3: Implement fallback**

```swift
// Book.swift
struct Book: Codable, Equatable {
    let id: String
    let name: String
    let author: String?
    let count: Int
    let references: [Reference]
    enum CodingKeys: String, CodingKey { case id, name, author, count, references }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try c.decodeIfPresent(String.self, forKey: .id), !id.isEmpty {
            self.id = id
        } else {
            // Derive từ name slugify
            let name = try c.decode(String.self, forKey: .name)
            self.id = Book.slugify(name)
            // name will decode lại dưới
        }
        self.name = try c.decode(String.self, forKey: .name)
        self.author = try c.decodeIfPresent(String.self, forKey: .author)
        self.count = try c.decode(Int.self, forKey: .count)
        self.references = try c.decode([Reference].self, forKey: .references)
    }
    static func slugify(_ s: String) -> String {
        // lowercased, folding diacritic, replace non-alnum with -
        let folded = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        var res = ""
        var needDash = false
        for ch in folded {
            if ch.isLetter || ch.isNumber { res.append(ch); needDash = false }
            else if !needDash { res.append("-"); needDash = true }
        }
        return res.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
```

Cập nhật `ZipValidator` and `BookRepository` dùng `Book` tolerant decode.

- [ ] **Step 4: PASS**

Run test PASS, sample `van-gioi-.../book.json` decode is with id derived `van-gioi-chi-rut-thuong-he-thong`

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Domain/Book.swift apps/novels/Persistence/BookRepository.swift apps/novels/Persistence/ZipValidator.swift
git commit -m "fix(book): derive slug when book.json id missing"
```

---

### Task 5: Cập nhật contracts/docs (source-of-truth)

**Files:**
- Modify: `docs/contracts/book-package.md:5-68`
- Modify: `docs/decisions/book-package-shape.md`
- Modify: `ARCHITECTURE.md:14`
- Modify: `docs/contracts/local-data.md` (mô tả unzip tolerant)

- [ ] **Step 1: Review current docs**

Mở `docs/contracts/book-package.md` xác nhận section "Producer Requirement" ghi strict reject wrapper.

- [ ] **Step 2: Update book-package.md**

Thay:
```
Valid ZIP contains exactly that layout. App accepts only the exact archive-root...
Reject outer-folder and __MACOSX wrappers.
Do not flatten wrappers...
```
Thành:
```
Canonical layout remains book.json + chapters/chapter-N.html at archive root.
Tolerant ingest (2026-08-26): App accepts both canonical and single outer-folder wrapper (payload nested one level) and ignores hygiene entries __MACOSX/, .DS_Store, ._* resource forks, flattening wrapper to canonical root when detected. Hygiene is skipped during unzip and validation; invalid content still fails.
ZIPs using data-descriptor (flag 0x08) for DEFLATE are supported via trailing descriptor parsing.
Security invariants (zip-slip, 100MB cap, CRC, STORE/DEFLATE only) remain enforced.
```

Giữ Reference Sample note nhưng đổi từ "rejected" → "now tolerated via flatten (kept as reference)".

- [ ] **Step 3: Update ADR**

Thêm vào `docs/decisions/book-package-shape.md`:

```markdown
## Amendment 2026-08-26 — Tolerant ingest

- Producer ZIPs thực tế is Finder ZIP with flag 0x08 + outer-folder + __MACOSX (như sample). Strict reject gây false invalid.
- Decision: App tolerant single outer-folder + hygiene ignore + data-descriptor support, vẫn giữ strict for 2+ top-level / missing chapter / CRC fail.
- Consequences: Sample `van-gioi-...zip` giờ import is qua flatten; docs/plans/feat-010 implements.
```

- [ ] **Step 4: Update ARCHITECTURE.md:14**

`FileManager.unzipItem extracts ZIP with tolerant hygiene + wrapper flatten + data-descriptor support, strict security invariants preserved.`

- [ ] **Step 5: Commit docs**

```bash
git add docs/contracts/book-package.md docs/decisions/book-package-shape.md ARCHITECTURE.md docs/contracts/local-data.md
git commit -m "docs(zip): update contract to tolerant ingest with wrapper flatten and data-descriptor"
```

---

### Task 6: Bài kiểm thử tổng hợp + verification

**Files:**
- Modify: `apps/novelsTests/ImportViewModelTests.swift`, `BookRepositoryTests.swift`
- Create: `apps/novelsTests/Fixtures/TolerantFixtures.swift`
- Verify: `init.sh`

- [ ] **Step 1: Add fixtures helper**

```swift
// TolerantFixtures.swift
enum TolerantFixtures {
    static func makeWrapperWithMacOSXAndFlag08(at zipURL: URL, id: String, count: Int) throws {
        // Dùng Python zipfile to tạo DEFLATE + flag 0x08 thực tế
        let py = """
        import zipfile, pathlib
        zp = pathlib.Path('\(zipURL.path)')
        with zipfile.ZipFile(zp, 'w', zipfile.ZIP_DEFLATED) as z:
            z.writestr('\(id)/book.json', b'{"id":"\(id)","name":"Test","count":\(count),"author":"A","references":\(Array(repeating:"C", count: count))}')
            for i in range(1, \(count)+1):
                z.writestr(f'\(id)/chapters/chapter-{i}.html', b'<p>hi</p>')
            z.writestr('__MACOSX/._book.json', b'x'*163)
            z.writestr('__MACOSX/\(id)/._chapter-1.html', b'x'*163)
            z.writestr('.DS_Store', b'x')
        """
        // Thực thi via Process
    }
}
```

- [ ] **Step 2: Add coverage tests**

- `testImportSyntheticWrapperFlag08MacOSXSucceeds`
- `testImportRealSampleSucceeds` (dùng `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` thật, verify library count 743)
- `testImportStillRejectsZipSlip` (entry `../evil.html` → invalidPackage)
- `testImportStillRejectsBomb` (single file >100MB → invalidPackage)
- `testImportStillRejectsCRCMismatch` (sửa 1 byte sau nén → invalidPackage)
- `testImportStillRejectsMissingChapter` (count 2 nhưng chỉ 1 file)

- [ ] **Step 3: Run full verification**

Run: `./init.sh`
Expected: PASS format 0, lint 0, build PASS, test PASS (tăng từ ~60 lên ~70 tests)

Chạy thêm: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' | tail -20`

- [ ] **Step 4: Self-review plan**

Check: spec coverage đủ 3 root causes, không placeholder, type consistency `resolveCanonicalRoot(at: URL) -> URL`, `isHygieneEntry`, `Book.init(from:)` slugify.

- [ ] **Step 5: Commit tests**

```bash
git add apps/novelsTests/ apps/novelsTests/Fixtures/
git commit -m "test(zip): add tolerant wrapper/flag08/hygiene fixtures and security invariant tests"
```

---

## Verification

- `./init.sh` PASS (format, lint, build, test)
- `xcodebuild test` PASS with tất cả cases tolerant + security invariant

## Rollback

- Revert FileManagerZIP flag handling về throw nếu tolerant gây false positive (nhưng hygiene and wrapper có thể giữ)
- Hoặc đặt feature flag `isTolerantZIP` to toggle strict/tolerant

## Open

- No DB migration, no catalog API change, no UI change
