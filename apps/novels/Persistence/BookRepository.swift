import Foundation

enum BookRepositoryError: Error, Equatable {
    case bookNotFound(slug: String)
    case invalidChapterNumber(number: Int, count: Int)
    case missingChapterFile(slug: String, number: Int)
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
        let folderURL = root.appendingPathComponent(slug, isDirectory: true)
        guard fileManager.fileExists(atPath: folderURL.path) else { return nil }
        return validatedBook(at: folderURL)
    }

    func chapterHTML(slug: String, number: Int) throws -> String {
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
        assert(
            ZipValidator.isValidRoot(at: validatedRoot, fileManager: fileManager),
            "validatedRoot must be exact archive root with book.json + chapters/chapter-N.html"
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent(slug, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: validatedRoot, to: destination)
    }

    func deleteBook(slug: String) throws {
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
