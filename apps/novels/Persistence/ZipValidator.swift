import Foundation

/// Shared by ZipValidator + ImportViewModel: strip a leading UTF-8 BOM so
/// JSONDecoder accepts book.json saved by Windows editors. Names/content
/// untouched — only the 3-byte signature is dropped when present.
func stripUTF8BOM(_ data: Data) -> Data {
    if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
        return Data(data.dropFirst(3))
    }
    return data
}

enum ZipValidator {
    // MARK: - Hygiene helper (shared with FileManagerZIP resolver)

    /// Hygiene entries are OS/Finder artifacts: __MACOSX/, .DS_Store, ._ resource forks,
    /// plus device/Windows strays (.Spotlight-V100, .Trashes, .LSOverride, Thumbs.db).
    /// Matching is per-path-component and case-insensitive (device ZIPs carry
    /// lowercase __macosx, capitalised Thumbs.db, …).
    /// Over-match note: legitimate files starting with "._" will be ignored (rare in book packages; acceptable per
    /// book-package.md tolerant ingest).
    static func isHygieneEntry(_ name: String) -> Bool {
        // Legacy prefix/contains checks (kept for back-compat).
        if name == "__MACOSX" || name.hasPrefix("__MACOSX/") || name.contains("/__MACOSX/") {
            return true
        }
        if name == ".DS_Store" || name.hasSuffix("/.DS_Store") {
            return true
        }
        if name.hasPrefix("._") || name.contains("/._") {
            return true
        }
        // Component-wise case-insensitive sweep covers lowercase variants and
        // additional strays at any depth, with or without trailing slashes.
        let hygiene: Set = ["__macosx", ".ds_store", ".spotlight-v100", ".trashes", ".lsoverride", "thumbs.db"]
        for component in name.split(separator: "/") {
            let lower = component.lowercased()
            if hygiene.contains(lower) {
                return true
            }
            if lower.hasPrefix("._") {
                return true
            }
        }
        return false
    }

    static func isValidRoot(at url: URL) -> Bool {
        isValidRoot(at: url, fileManager: .default)
    }

    // MARK: - Diagnosis (instrumentation only — never changes accept/reject)

    // Non-throwing, read-only explanation of WHY a root fails validation.
    // Names only (never file content). Check tokens plus a `verdict=` computed
    // by the real `isValidRoot`, so the verdict can never drift from the rules.
    // Example: `top=[book.json,chapters,cover.jpg] count=3 refs=3 extra=[cover.jpg] verdict=reject`.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func diagnose(at url: URL, fileManager: FileManager = .default) -> String {
        guard let topContents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return "top=unreadable verdict=reject"
        }
        var tokens = ["top=[\(summarizeNames(topContents.map { $0.lastPathComponent }))]"]
        var extras: [String] = []
        var chaptersEntry: URL?
        for entry in topContents {
            let name = entry.lastPathComponent
            if isHygieneEntry(name) {
                continue
            }
            var isDir: ObjCBool = false
            _ = fileManager.fileExists(atPath: entry.path, isDirectory: &isDir)
            if name == "book.json", !isDir.boolValue {
                continue
            } else if name == "chapters", isDir.boolValue {
                chaptersEntry = entry
            } else {
                extras.append(isDir.boolValue ? name + "/" : name)
            }
        }
        if !extras.isEmpty {
            tokens.append("extra=[\(summarizeNames(extras))]")
        }
        let bookURL = url.appendingPathComponent("book.json", isDirectory: false)
        var bookIsFile = false
        if fileManager.fileExists(atPath: bookURL.path) {
            var isDir: ObjCBool = false
            _ = fileManager.fileExists(atPath: bookURL.path, isDirectory: &isDir)
            bookIsFile = !isDir.boolValue
        }
        guard bookIsFile else {
            tokens.append("bookJson=missing")
            tokens.append("verdict=reject")
            return tokens.joined(separator: " ")
        }
        guard let raw = try? Data(contentsOf: bookURL) else {
            tokens.append("bookJson=unreadable")
            tokens.append("verdict=reject")
            return tokens.joined(separator: " ")
        }
        let book: Book
        do {
            book = try JSONDecoder().decode(Book.self, from: stripUTF8BOM(raw))
        } catch {
            tokens.append("bookJson=decodeFail:\(decodeKind(error))")
            tokens.append("verdict=reject")
            return tokens.joined(separator: " ")
        }
        tokens.append("count=\(book.count) refs=\(book.references.count)")
        if book.count != book.references.count {
            tokens.append("countMismatch")
            tokens.append("verdict=reject")
            return tokens.joined(separator: " ")
        }
        // swiftlint:disable:next empty_count - book.count is domain Int, not collection.count
        if book.count == 0 {
            if let chapters = chaptersEntry {
                let files = nonHygieneNames(in: chapters, fileManager: fileManager)
                tokens.append("chapters=files=\(files.count)")
                if !files.isEmpty {
                    tokens.append("extraChapters=[\(summarizeNames(files))]")
                }
            } else {
                tokens.append("chapters=absent")
            }
            tokens.append("verdict=\(isValidRoot(at: url, fileManager: fileManager) ? "ok" : "reject")")
            return tokens.joined(separator: " ")
        }
        guard let chapters = chaptersEntry else {
            tokens.append("chapters=missing")
            tokens.append("verdict=reject")
            return tokens.joined(separator: " ")
        }
        let chapterURLs = (try? fileManager.contentsOfDirectory(
            at: chapters,
            includingPropertiesForKeys: [],
            options: []
        )) ?? []
        let files = chapterURLs.map { $0.lastPathComponent }.filter { !isHygieneEntry($0) }.sorted()
        tokens.append("chapters=files=\(files.count)")
        var missing: [String] = []
        for number in 1 ... book.count {
            let chapterURL = chapters.appendingPathComponent("chapter-\(number).html", isDirectory: false)
            if !fileManager.fileExists(atPath: chapterURL.path) {
                missing.append("chapter-\(number).html")
            }
        }
        if !missing.isEmpty {
            tokens.append("missing=[\(summarizeNames(missing))]")
        }
        let misnamed = files.filter { !isChapterName($0) }
        if !misnamed.isEmpty {
            tokens.append("misnamed=[\(summarizeNames(misnamed))]")
        }
        tokens.append("verdict=\(isValidRoot(at: url, fileManager: fileManager) ? "ok" : "reject")")
        return tokens.joined(separator: " ")
    }

    /// Names only, sorted, capped at 8, each truncated to 24 chars.
    static func summarizeNames(_ names: [String]) -> String {
        names.sorted().prefix(8).map { name in
            name.count <= 24 ? name : String(name.prefix(24)) + "…"
        }.joined(separator: ",")
    }

    /// Non-hygiene child names of a directory; empty on any filesystem error.
    static func nonHygieneNames(in dir: URL, fileManager: FileManager) -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [],
            options: []
        ) else {
            return []
        }
        return contents.map { $0.lastPathComponent }.filter { !isHygieneEntry($0) }.sorted()
    }

    /// Compact DecodingError kind for logs: key/type info only, never values.
    static func decodeKind(_ error: Error) -> String {
        if let decoding = error as? DecodingError {
            if case let .keyNotFound(key, _) = decoding {
                return "keyNotFound:\(String(key.stringValue.prefix(24)))"
            } else if case let .typeMismatch(type, _) = decoding {
                return "typeMismatch:\(String(String(describing: type).prefix(24)))"
            } else if case .valueNotFound = decoding {
                return "valueNotFound"
            } else if case .dataCorrupted = decoding {
                return "dataCorrupted"
            } else {
                return "unknown"
            }
        }
        return "unknown"
    }

    /// Case-sensitive chapter-N.html shape check, mirroring isValidRoot.
    static func isChapterName(_ name: String) -> Bool {
        guard name.hasPrefix("chapter-"), name.hasSuffix(".html") else {
            return false
        }
        let middle = name.dropFirst("chapter-".count).dropLast(".html".count)
        return !middle.isEmpty && middle.allSatisfy { $0.isASCII && $0.isNumber }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func isValidRoot(at url: URL, fileManager: FileManager = .default) -> Bool {
        let bookURL = url.appendingPathComponent("book.json", isDirectory: false)
        guard fileManager.fileExists(atPath: bookURL.path) else { return false }
        guard let raw = try? Data(contentsOf: bookURL) else { return false }
        guard let book = try? JSONDecoder().decode(Book.self, from: stripUTF8BOM(raw)) else { return false }
        guard book.count == book.references.count else { return false }
        // Strict exact-root: reject any extra entries at root beyond book.json and chapters/
        // Specifically reject __MACOSX even when present alongside valid files per book-package.md
        let topContents: [URL]
        do {
            topContents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            return false
        }
        var hasBookJSON = false
        var hasChaptersDir = false
        for entry in topContents {
            let name = entry.lastPathComponent
            if isHygieneEntry(name) {
                continue
            }
            var isDir: ObjCBool = false
            // Use fileExists to determine directory status reliably
            _ = fileManager.fileExists(atPath: entry.path, isDirectory: &isDir)
            if name == "book.json", !isDir.boolValue {
                hasBookJSON = true
            } else if name == "chapters", isDir.boolValue {
                hasChaptersDir = true
            } else {
                // Any extra non-hygiene entry at root (e.g., extra.txt, outer folder) invalidates
                return false
            }
        }
        if !hasBookJSON {
            return false
        }
        // For count == 0, chapters may be empty or missing but if present must be valid and no extra check already done
        // swiftlint:disable:next empty_count - book.count is domain Int, not collection.count
        if book.count == 0 {
            // If chapters dir exists, ensure it doesn't contain unexpected files (hygiene ignored)
            if hasChaptersDir {
                let chaptersURL = url.appendingPathComponent("chapters", isDirectory: true)
                if let chapterContents = try? fileManager.contentsOfDirectory(
                    at: chaptersURL,
                    includingPropertiesForKeys: [],
                    options: []
                ) {
                    let filtered = chapterContents.filter { !isHygieneEntry($0.lastPathComponent) }
                    if !filtered.isEmpty {
                        return false
                    }
                }
            }
            return true
        }
        // count > 0 requires chapters dir
        if !hasChaptersDir {
            return false
        }
        let chaptersURL = url.appendingPathComponent("chapters", isDirectory: true)
        // Check chapters contains exactly count files and no extras
        let chapterContents: [URL]
        do {
            chapterContents = try fileManager.contentsOfDirectory(
                at: chaptersURL,
                includingPropertiesForKeys: [],
                options: []
            )
        } catch {
            return false
        }
        let filteredChapters = chapterContents.filter { !isHygieneEntry($0.lastPathComponent) }
        if filteredChapters.count != book.count {
            return false
        }
        // Ensure each expected chapter file exists and no extra naming
        for number in 1 ... book.count {
            let chapterURL = chaptersURL.appendingPathComponent("chapter-\(number).html", isDirectory: false)
            guard fileManager.fileExists(atPath: chapterURL.path) else { return false }
        }
        // Validate no extra filenames beyond chapter-N.html (hygiene already filtered)
        for entry in filteredChapters {
            let name = entry.lastPathComponent
            guard name.hasPrefix("chapter-"), name.hasSuffix(".html") else { return false }
            let middle = name.dropFirst("chapter-".count).dropLast(".html".count)
            if middle.isEmpty || !middle.allSatisfy({ $0.isASCII && $0.isNumber }) {
                return false
            }
            if let num = Int(middle), !(1 ... book.count).contains(num) {
                return false
            }
        }
        return true
    }
}
