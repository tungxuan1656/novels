import Foundation

enum AppPaths {
    static func booksRoot(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("novels/books", isDirectory: true)
    }

    static func cacheRoot(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("novels/cache", isDirectory: true)
    }

    static func booksRoot(baseURL: URL) -> URL {
        baseURL.appendingPathComponent("novels/books", isDirectory: true)
    }

    static func cacheRoot(baseURL: URL) -> URL {
        baseURL.appendingPathComponent("novels/cache", isDirectory: true)
    }

    static func booksRoot(base: URL) -> URL {
        booksRoot(baseURL: base)
    }

    static func cacheRoot(base: URL) -> URL {
        cacheRoot(baseURL: base)
    }
}
