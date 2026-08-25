import Foundation

enum ZipValidator {
    static func isValidRoot(at url: URL) -> Bool {
        isValidRoot(at: url, fileManager: .default)
    }

    static func isValidRoot(at url: URL, fileManager: FileManager = .default) -> Bool {
        let bookURL = url.appendingPathComponent("book.json", isDirectory: false)
        guard fileManager.fileExists(atPath: bookURL.path) else { return false }
        guard let data = try? Data(contentsOf: bookURL) else { return false }
        guard let book = try? JSONDecoder().decode(Book.self, from: data) else { return false }
        guard book.count == book.references.count else { return false }
        // swiftlint:disable:next empty_count - book.count is domain Int, not collection.count
        if book.count == 0 {
            return true
        }
        for number in 1 ... book.count {
            let chapterURL = url.appendingPathComponent("chapters/chapter-\(number).html", isDirectory: false)
            guard fileManager.fileExists(atPath: chapterURL.path) else { return false }
        }
        return true
    }
}
