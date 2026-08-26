import Foundation

enum BookRepositoryError: Error, Equatable {
    case bookNotFound(slug: String)
    case invalidSlug(slug: String)
    case invalidChapterNumber(number: Int, count: Int)
    case missingChapterFile(slug: String, number: Int)
    case invalidValidatedRoot
}

protocol BookRepository {
    func listBooks() throws -> [Book]
    func book(slug: String) throws -> Book?
    func chapterHTML(slug: String, number: Int) throws -> String
    func save(validatedRoot: URL, slug: String) throws
    func deleteBook(slug: String) throws
}

struct FileBookRepository: BookRepository {
    let root: URL
    let fileManager: FileManager

    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    func listBooks() throws -> [Book] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let contents = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )
        var books: [Book] = []
        for folderURL in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { continue }
            guard let book = validatedBook(at: folderURL) else { continue }
            books.append(book)
        }
        return books.sorted { $0.id < $1.id }
    }

    func book(slug: String) throws -> Book? {
        guard SlugValidator.isValid(slug) else { throw BookRepositoryError.invalidSlug(slug: slug) }
        let folderURL = root.appendingPathComponent(slug, isDirectory: true)
        guard fileManager.fileExists(atPath: folderURL.path) else { return nil }
        return validatedBook(at: folderURL)
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
        guard SlugValidator.isValid(slug) else { throw BookRepositoryError.invalidSlug(slug: slug) }
        guard let book = try book(slug: slug) else {
            throw BookRepositoryError.bookNotFound(slug: slug)
        }
        guard number >= 1, number <= book.count else {
            throw BookRepositoryError.invalidChapterNumber(number: number, count: book.count)
        }
        let chapterURL = root
            .appendingPathComponent(slug, isDirectory: true)
            .appendingPathComponent("chapters/chapter-\(number).html", isDirectory: false)
        guard fileManager.fileExists(atPath: chapterURL.path) else {
            throw BookRepositoryError.missingChapterFile(slug: slug, number: number)
        }
        return try String(contentsOf: chapterURL, encoding: .utf8)
    }

    func save(validatedRoot: URL, slug: String) throws {
        guard SlugValidator.isValid(slug) else { throw BookRepositoryError.invalidSlug(slug: slug) }
        guard ZipValidator.isValidRoot(at: validatedRoot, fileManager: fileManager) else {
            throw BookRepositoryError.invalidValidatedRoot
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent(slug, isDirectory: true)
        let tmp = root.appendingPathComponent(".tmp-\(slug)-\(UUID().uuidString)", isDirectory: true)
        if fileManager.fileExists(atPath: tmp.path) {
            try? fileManager.removeItem(at: tmp)
        }
        do {
            try fileManager.copyItem(at: validatedRoot, to: tmp)
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw error
        }
        // Atomic replacement: use replaceItemAt when destination exists to avoid crash window losing existing book
        if fileManager.fileExists(atPath: destination.path) {
            do {
                _ = try fileManager.replaceItem(
                    at: destination,
                    withItemAt: tmp,
                    backupItemName: nil,
                    options: [],
                    resultingItemURL: nil
                )
                // replaceItemAt consumes tmp; ensure cleanup if still present
                if fileManager.fileExists(atPath: tmp.path) {
                    try? fileManager.removeItem(at: tmp)
                }
            } catch {
                // Fallback: if replace fails, destination is still intact (atomic guarantee).
                // Do NOT have removed destination earlier. Try copy fallback without losing existing book.
                // If destination still exists, we failed to replace - keep original and clean tmp.
                // Only attempt copy if destination unexpectedly missing (e.g., replace removed it before failing).
                if fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.removeItem(at: tmp)
                    throw error
                } else {
                    // Destination missing after failed replace - try to restore from tmp via copy
                    do {
                        try fileManager.copyItem(at: tmp, to: destination)
                        try? fileManager.removeItem(at: tmp)
                    } catch {
                        try? fileManager.removeItem(at: tmp)
                        throw error
                    }
                }
            }
        } else {
            do {
                try fileManager.moveItem(at: tmp, to: destination)
            } catch {
                // Cross-volume fallback: copy then clean tmp (destination did not exist, safe)
                do {
                    try fileManager.copyItem(at: tmp, to: destination)
                    try? fileManager.removeItem(at: tmp)
                } catch {
                    try? fileManager.removeItem(at: tmp)
                    throw error
                }
            }
        }
    }

    func deleteBook(slug: String) throws {
        guard SlugValidator.isValid(slug) else { throw BookRepositoryError.invalidSlug(slug: slug) }
        let destination = root.appendingPathComponent(slug, isDirectory: true)
        guard fileManager.fileExists(atPath: destination.path) else { return }
        try fileManager.removeItem(at: destination)
    }

    // MARK: - Private

    private func validatedBook(at folderURL: URL) -> Book? {
        let bookURL = folderURL.appendingPathComponent("book.json", isDirectory: false)
        guard fileManager.fileExists(atPath: bookURL.path) else { return nil }
        guard let data = try? Data(contentsOf: bookURL) else { return nil }
        guard let book = try? JSONDecoder().decode(Book.self, from: data) else { return nil }
        guard book.count == book.references.count else { return nil }
        // swiftlint:disable:next empty_count - book.count is domain Int, not collection.count
        if book.count == 0 {
            return book
        }
        for number in 1 ... book.count {
            let chapterURL = folderURL.appendingPathComponent(
                "chapters/chapter-\(number).html",
                isDirectory: false
            )
            guard fileManager.fileExists(atPath: chapterURL.path) else { return nil }
        }
        return book
    }
}
