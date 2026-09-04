import Foundation

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
            // Resource budget for slow large-package downloads (100MB unzip cap); stalls trip the 30s request timer.
            config.timeoutIntervalForResource = 600
            self.session = URLSession(configuration: config)
        }
    }

    func download(from url: URL) async throws -> URL {
        let result = try await session.download(from: url)
        return try Self.validatedDownloadURL(fileURL: result.0, response: result.1)
    }

    static func validatedDownloadURL(fileURL: URL, response: URLResponse) throws -> URL {
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return fileURL
    }
}
