import Foundation

enum ZipValidator {
    // MARK: - Hygiene helper (shared with FileManagerZIP resolver)

    /// Hygiene entries are macOS Finder artifacts: __MACOSX/, .DS_Store, ._ resource forks.
    /// Over-match note: legitimate files starting with "._" will be ignored (rare in book packages; acceptable per book-package.md tolerant ingest).
    static func isHygieneEntry(_ name: String) -> Bool {
        if name == "__MACOSX" || name.hasPrefix("__MACOSX/") || name.contains("/__MACOSX/") {
            return true
        }
        if name == ".DS_Store" || name.hasSuffix("/.DS_Store") {
            return true
        }
        if name.hasPrefix("._") || name.contains("/._") {
            return true
        }
        return false
    }

    static func isValidRoot(at url: URL) -> Bool {
        isValidRoot(at: url, fileManager: .default)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func isValidRoot(at url: URL, fileManager: FileManager = .default) -> Bool {
        let bookURL = url.appendingPathComponent("book.json", isDirectory: false)
        guard fileManager.fileExists(atPath: bookURL.path) else { return false }
        guard let data = try? Data(contentsOf: bookURL) else { return false }
        guard let book = try? JSONDecoder().decode(Book.self, from: data) else { return false }
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
            if middle.isEmpty || !middle.allSatisfy({ $0.isNumber }) {
                return false
            }
            if let num = Int(middle), !(1 ... book.count).contains(num) {
                return false
            }
        }
        return true
    }
}
