import Foundation
import Observation

protocol CatalogFetching: Sendable {
    func fetchCatalog() async throws -> [ExportedBook]
}

extension CatalogService: CatalogFetching {}

protocol Downloader: Sendable {
    func download(from url: URL) async throws -> URL
}

struct URLSessionDownloader: Downloader {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(from url: URL) async throws -> URL {
        let result = try await session.download(from: url)
        return result.0
    }
}

@MainActor
@Observable
final class ImportViewModel {
    enum CatalogState: Equatable {
        case idle
        case loading
        case loaded([ExportedBook])
        case empty
        case error(String)
    }

    enum ImportState: Equatable {
        case idle
        case downloading
        case extracting
    }

    enum SortOption: Hashable {
        case nameAZ
        case updatedNewest
    }

    var catalogState: CatalogState = .idle
    var importState: ImportState = .idle
    var sortOption: SortOption = .nameAZ
    private var loadedBooks: [ExportedBook] = []

    var sortedBooks: [ExportedBook] {
        if sortOption == .nameAZ {
            return loadedBooks.sorted {
                $0.book.name.localizedCaseInsensitiveCompare($1.book.name) == .orderedAscending
            }
        } else {
            return loadedBooks.sorted {
                let lhs = $0.book.lastUpdated ?? $0.updatedAt
                let rhs = $1.book.lastUpdated ?? $1.updatedAt
                return lhs > rhs
            }
        }
    }

    private let catalogService: any CatalogFetching
    private let repository: FileBookRepository
    private let downloader: any Downloader
    var onImportSuccess: ((String) -> Void)?

    init(
        catalogService: any CatalogFetching,
        repository: FileBookRepository,
        downloader: any Downloader
    ) {
        self.catalogService = catalogService
        self.repository = repository
        self.downloader = downloader
    }

    func loadCatalog() async {
        catalogState = .loading
        do {
            let books = try await catalogService.fetchCatalog()
            loadedBooks = books
            catalogState = books.isEmpty ? .empty : .loaded(books)
        } catch let error as CatalogError {
            if case let .serverMessage(message) = error {
                catalogState = .error(message)
            } else {
                catalogState = .error("Không có kết nối")
            }
        } catch {
            if let catalogError = error as? CatalogError, case let .serverMessage(message) = catalogError {
                catalogState = .error(message)
            } else {
                catalogState = .error("Không có kết nối")
            }
        }
    }

    func importBook(_ exported: ExportedBook) async throws {
        guard importState == .idle else { return }
        try Task.checkCancellation()
        importState = .downloading
        guard let url = URL(string: exported.exportUrl) else {
            importState = .idle
            throw ImportError.downloadFailed
        }
        let zipURL: URL
        do {
            zipURL = try await downloader.download(from: url)
        } catch is CancellationError {
            importState = .idle
            throw CancellationError()
        } catch {
            importState = .idle
            throw ImportError.downloadFailed
        }
        importState = .extracting
        try Task.checkCancellation()
        let tmpUnzip = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        // Ensure cleanup of tmp unzip always
        defer {
            try? FileManager.default.removeItem(at: tmpUnzip)
        }
        do {
            try FileManager.default.createDirectory(at: tmpUnzip, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: zipURL, to: tmpUnzip)
            guard ZipValidator.isValidRoot(at: tmpUnzip) else {
                throw ImportError.invalidPackage
            }
            try Task.checkCancellation()
            let bookData = try Data(contentsOf: tmpUnzip.appendingPathComponent("book.json"))
            let book = try JSONDecoder().decode(Book.self, from: bookData)
            try repository.save(validatedRoot: tmpUnzip, slug: book.id)
            // Delete ZIP only on success
            try? FileManager.default.removeItem(at: zipURL)
            importState = .idle
            onImportSuccess?(book.id)
        } catch let error as ImportError {
            importState = .idle
            throw error
        } catch is CancellationError {
            importState = .idle
            throw CancellationError()
        } catch {
            importState = .idle
            if let importErr = error as? ImportError {
                throw importErr
            }
            throw ImportError.invalidPackage
        }
    }
}
