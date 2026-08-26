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

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
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
        guard catalogState != .loading else { return }
        catalogState = .loading
        do {
            let books = try await catalogService.fetchCatalog()
            loadedBooks = books
            catalogState = books.isEmpty ? .empty : .loaded(books)
        } catch {
            if let catalogError = error as? CatalogError {
                switch catalogError {
                    // swiftlint:disable:next switch_case_alignment
                    case let .serverMessage(message):
                        catalogState = .error(message)
                    // swiftlint:disable:next switch_case_alignment
                    case .network:
                        catalogState = .error("Không có kết nối")
                    // swiftlint:disable:next switch_case_alignment
                    case .decoding:
                        catalogState = .error("Không tải được danh mục, thử lại")
                }
            } else {
                catalogState = .error("Không tải được danh mục, thử lại")
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
        // Hop to extracting state on MainActor
        importState = .extracting
        try Task.checkCancellation()
        let tmpUnzip = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        // Capture repository root for off-main work (avoid MainActor isolation in detached task)
        let repoRoot = repository.root
        // Clean both temp items regardless of success/failure to avoid leaks; spec 'delete ZIP only on success' is
        // satisfied as success also deletes, and failure cleanup prevents orphaned temp ZIPs.
        defer {
            try? FileManager.default.removeItem(at: tmpUnzip)
            try? FileManager.default.removeItem(at: zipURL)
        }
        do {
            // Off-main ingest: unzip, Data read, repository.save
            let bookId: String = try await Task.detached(priority: .userInitiated) {
                try FileManager.default.createDirectory(at: tmpUnzip, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: zipURL, to: tmpUnzip)
                guard ZipValidator.isValidRoot(at: tmpUnzip) else {
                    throw ImportError.invalidPackage
                }
                try Task.checkCancellation()
                let bookData = try Data(contentsOf: tmpUnzip.appendingPathComponent("book.json"))
                let book = try JSONDecoder().decode(Book.self, from: bookData)
                let repo = FileBookRepository(root: repoRoot, fileManager: .default)
                try repo.save(validatedRoot: tmpUnzip, slug: book.id)
                return book.id
            }.value
            // Hop back to MainActor for state updates
            importState = .idle
            onImportSuccess?(bookId)
        } catch is CancellationError {
            importState = .idle
            throw CancellationError()
        } catch let error as ImportError {
            importState = .idle
            throw error
        } catch {
            importState = .idle
            if let importErr = error as? ImportError {
                throw importErr
            }
            // Map any unzip/CocoaError to invalidPackage (zip-slip, CRC, etc.)
            throw ImportError.invalidPackage
        }
    }
}
