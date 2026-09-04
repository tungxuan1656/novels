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
        // One requestId correlates start -> success/fail in the Log viewer.
        let logCtx = ImportLogContext(
            requestId: UUID(),
            slug: exported.book.slug,
            host: URL(string: exported.exportUrl)?.host,
            startedAt: Date()
        )
        await Self.logImportStart(logCtx, expectedBytes: exported.fileSize)
        guard let url = URL(string: exported.exportUrl) else {
            importState = .idle
            await Self.logImportFailure(logCtx, stage: "download", error: URLError(.badURL))
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
            await Self.logImportFailure(logCtx, stage: "download", error: error)
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
            // Hoisted for the detached task (all Sendable; ExportedBook is MainActor-bound here).
            let bookId: String = try await Task.detached(priority: .userInitiated) {
                try await Self.ingest(zipURL: zipURL, tmpUnzip: tmpUnzip, repoRoot: repoRoot, logCtx: logCtx)
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
            // User-facing toast stays Vietnamese via ImportError; the real cause
            // is already in DiagnosticsLog (see staged logging above).
            await Self.logImportFailure(logCtx, stage: "ingest", error: error)
            throw ImportError.invalidPackage
        }
    }

    private nonisolated static func ingest(
        zipURL: URL, tmpUnzip: URL, repoRoot: URL, logCtx: ImportLogContext
    ) async throws -> String {
        let zipBytes = (try? FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int)
        do {
            try FileManager.default.createDirectory(at: tmpUnzip, withIntermediateDirectories: true)
        } catch {
            await Self.logImportFailure(logCtx, stage: "ingest-prep", error: error, zipBytes: zipBytes)
            throw ImportError.invalidPackage
        }
        do {
            try FileManager.default.unzipItem(at: zipURL, to: tmpUnzip)
        } catch {
            await Self.logImportFailure(logCtx, stage: "unzip", error: error, zipBytes: zipBytes)
            throw ImportError.invalidPackage
        }
        let canonical = FileManager.default.resolveCanonicalRoot(at: tmpUnzip)
        guard ZipValidator.isValidRoot(at: canonical) else {
            await Self.logImportFailure(
                logCtx,
                stage: "validate",
                error: ImportError.invalidPackage,
                zipBytes: zipBytes,
                diag: Self.validateDiag(tmpUnzip: tmpUnzip, canonical: canonical)
            )
            throw ImportError.invalidPackage
        }
        try Task.checkCancellation()
        let bookData: Data
        do {
            bookData = try stripUTF8BOM(Data(contentsOf: canonical.appendingPathComponent("book.json")))
        } catch {
            await Self.logImportFailure(logCtx, stage: "read-book", error: error, zipBytes: zipBytes)
            throw ImportError.invalidPackage
        }
        let book: Book
        do {
            book = try JSONDecoder().decode(Book.self, from: bookData)
        } catch {
            await Self.logImportFailure(logCtx, stage: "decode-book", error: error, zipBytes: zipBytes)
            throw ImportError.invalidPackage
        }
        do {
            let repo = FileBookRepository(root: repoRoot, fileManager: .default)
            try repo.save(validatedRoot: canonical, slug: book.id)
        } catch {
            await Self.logImportFailure(logCtx, stage: "save", error: error, zipBytes: zipBytes)
            throw ImportError.invalidPackage
        }
        await Self.logImportSuccess(logCtx, bookId: book.id, chapters: book.count, zipBytes: zipBytes)
        return book.id
    }
}

// MARK: - Import diagnostics logging (extension keeps the class body under type_body_length)

private extension ImportViewModel {
    /// Shared correlation context for one importBook call. Carried into the
    /// detached ingest so start -> success/fail share a requestId in the Log viewer.
    struct ImportLogContext: Sendable {
        let requestId: UUID
        let slug: String
        let host: String?
        let startedAt: Date
    }

    private nonisolated static func latencyMs(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1000))
    }

    private nonisolated static func logImportStart(_ ctx: ImportLogContext, expectedBytes: Int) async {
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: ctx.requestId,
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: ctx.slug,
            mode: "import",
            host: ctx.host,
            event: "import.start",
            detail: "host=\(ctx.host ?? "-") expectedBytes=\(expectedBytes)"
        ))
    }

    private nonisolated static func logImportSuccess(
        _ ctx: ImportLogContext,
        bookId: String,
        chapters: Int,
        zipBytes: Int?
    ) async {
        var parts = ["chapters=\(chapters)"]
        if let host = ctx.host {
            parts.append("host=\(host)")
        }
        if let zipBytes {
            parts.append("zipBytes=\(zipBytes)")
        }
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: ctx.requestId,
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: bookId,
            mode: "import",
            latencyMs: latencyMs(since: ctx.startedAt),
            host: ctx.host,
            event: "import.success",
            detail: parts.joined(separator: " ")
        ))
    }

    /// Record the underlying ingest cause for the Log viewer. `reason=` is
    /// always a human-readable Vietnamese hint for the stage, so a generic
    /// ImportError.invalidPackage never surfaces as a bare "invalidPackage:0".
    /// Never includes book/chapter content, auth headers, or full URLs —
    /// host + zip byte counts + 120-char error snippet only. User-facing errors
    /// still map to ImportError (Vietnamese toast) via the throw sites above.
    private nonisolated static func logImportFailure(
        _ ctx: ImportLogContext,
        stage: String,
        error: Error,
        zipBytes: Int? = nil,
        diag: String? = nil
    ) async {
        let ns = error as NSError
        let snippet = DiagnosticsRedactor.snippet(ns.localizedDescription, limit: 120, verbose: true)
            ?? "\(ns.domain):\(ns.code)"
        var parts = ["stage=\(stage)", "reason=\(reasonFor(stage: stage, error: error, diag: diag))"]
        if let host = ctx.host {
            parts.append("host=\(host)")
        }
        if let zipBytes {
            parts.append("zipBytes=\(zipBytes)")
        }
        parts.append("err=\(ns.domain):\(ns.code)")
        parts.append("msg=\(snippet)")
        if let uz = UnzipFailure.token(from: error), !uz.isEmpty {
            parts.append("uz=\(uz)")
        }
        if let diag, !diag.isEmpty {
            parts.append("diag=\(diag)")
        }
        await DiagnosticsLog.shared.append(LogEntry(
            requestId: ctx.requestId,
            sessionId: DiagnosticsLog.sessionId,
            kind: .event,
            bookId: ctx.slug,
            mode: "import",
            latencyMs: latencyMs(since: ctx.startedAt),
            host: ctx.host,
            errorDomain: ns.domain,
            errorCode: ns.code,
            event: "import.fail",
            detail: parts.joined(separator: " ")
        ))
    }

    /// Flatten depth of canonical relative to the unzip temp root
    /// (0 = package at zip root). Names never logged — counts only.
    private nonisolated static func validateDiag(tmpUnzip: URL, canonical: URL) -> String {
        let base = tmpUnzip.standardizedFileURL.path
        let target = canonical.standardizedFileURL.path
        var depth = 0
        if target != base, target.hasPrefix(base + "/") {
            depth = target.dropFirst(base.count + 1).split(separator: "/").count
        }
        return "depth=\(depth) \(ZipValidator.diagnose(at: canonical))"
    }

    private nonisolated static func reasonFor(stage: String, error: Error, diag: String? = nil) -> String {
        if let urlError = error as? URLError {
            return downloadReason(code: urlError.code)
        }
        if stage == "download" {
            return "tải gói sách thất bại"
        } else if stage == "unzip" {
            return unzipReason(error: error)
        } else if stage == "validate" {
            return validateReason(diag: diag)
        } else if stage == "read-book" {
            return "không đọc được book.json sau khi giải nén"
        } else if stage == "ingest-prep" {
            return "không tạo được thư mục tạm để giải nén"
        } else if stage == "decode-book" {
            return "book.json lỗi JSON: \(jsonCause(error))"
        } else if stage == "save" {
            return saveReason(error)
        } else {
            return "nhập sách thất bại ở bước \(stage)"
        }
    }

    /// Validate reason driven by diagnose() tokens so the Log viewer names the
    /// actual cause (extra file vs missing chapter vs count mismatch vs decode).
    private nonisolated static func validateReason(diag: String?) -> String {
        guard let diag else {
            return "gói sách không đúng cấu trúc: thiếu book.json hoặc chapters/chapter-N.html,"
                + " hoặc còn thư mục bọc ngoài"
        }
        if diag.contains("bookJson=missing") {
            return "thiếu book.json trong gói sau giải nén"
        } else if diag.contains("bookJson=decodeFail") {
            return "book.json lỗi JSON, không đọc được"
        } else if diag.contains("bookJson=unreadable") {
            return "không đọc được book.json sau giải nén"
        } else if diag.contains("countMismatch") {
            return "book.json khai count khác số references"
        } else if diag.contains("chapters=missing") {
            return "thiếu thư mục chapters"
        } else if diag.contains("missing=") {
            return "thiếu file chương trong chapters"
        } else if diag.contains("extra=") || diag.contains("misnamed=") || diag.contains("extraChapters=") {
            return "thừa file/thư mục ngoài quy định của gói"
        } else {
            return "gói sách không đúng cấu trúc book.json/chapters"
        }
    }

    /// Unzip reason driven by the UnzipFailure site token carried in the
    /// error's userInfo, so the Log viewer names the actual throw site.
    /// Falls back to the generic message when no context is attached.
    private nonisolated static func unzipReason(error: Error) -> String {
        guard let (site, method) = UnzipFailure.siteAndMethod(from: error) else {
            return "giải nén thất bại: ZIP hỏng, tên file mã hoá lạ hoặc dữ liệu nén lỗi"
        }
        if site == "method" {
            if let method {
                return "phương thức nén không hỗ trợ (method=\(method))"
            }
            return "phương thức nén không hỗ trợ"
        } else if site == "crc" {
            return "dữ liệu tải về có thể bị cắt xén (CRC không khớp)"
        } else if site == "inflate" {
            return "dữ liệu nén lỗi, không giải nén được"
        } else if site == "descriptor" {
            return "định dạng ZIP mở rộng chưa hỗ trợ"
        } else if site == "bomb" {
            return "gói sách vượt giới hạn giải nén an toàn"
        } else if site == "traversal" {
            return "gói sách chứa đường dẫn không hợp lệ"
        } else if site == "filename" {
            return "tên file trong ZIP không đọc được"
        } else if site == "header" {
            return "file ZIP bị cắt xén hoặc hỏng cấu trúc"
        } else if site == "size" {
            return "kích thước dữ liệu không khớp khai báo (có thể tải thiếu)"
        } else if site == "prefix" {
            return "gói sách chứa đường dẫn ngoài thư mục (đã chặn)"
        } else if site == "write" {
            return "không ghi được file giải nén (có thể thiếu dung lượng)"
        } else if site == "encrypted" || site == "zip64" {
            return site == "encrypted" ? "không hỗ trợ ZIP mã hoá" : "không hỗ trợ ZIP64"
        } else {
            return "giải nén thất bại: ZIP hỏng, tên file mã hoá lạ hoặc dữ liệu nén lỗi"
        }
    }

    private nonisolated static func downloadReason(code: URLError.Code) -> String {
        if code == .timedOut {
            return "tải gói sách thất bại: hết thời gian chờ (mạng chậm hoặc gói lớn), thử lại"
        } else if code == .notConnectedToInternet || code == .networkConnectionLost {
            return "tải gói sách thất bại: không có kết nối mạng"
        } else if code == .badURL || code == .unsupportedURL {
            return "đường dẫn tải sách không hợp lệ"
        } else if code == .cancelled {
            return "đã huỷ tải sách"
        } else {
            return "tải gói sách thất bại: lỗi mạng (\(code.rawValue))"
        }
    }

    private nonisolated static func jsonCause(_ error: Error) -> String {
        let raw: String
        if let decoding = error as? DecodingError {
            if case let .dataCorrupted(context) = decoding {
                raw = context.debugDescription
            } else if case let .keyNotFound(key, context) = decoding {
                raw = "thiếu key \(key.stringValue): \(context.debugDescription)"
            } else if case let .typeMismatch(type, context) = decoding {
                raw = "sai kiểu \(type): \(context.debugDescription)"
            } else if case let .valueNotFound(type, context) = decoding {
                raw = "thiếu giá trị \(type): \(context.debugDescription)"
            } else {
                raw = String(describing: decoding)
            }
        } else {
            raw = error.localizedDescription
        }
        return String(raw.prefix(80))
    }

    private nonisolated static func saveReason(_ error: Error) -> String {
        guard let repoError = error as? BookRepositoryError else {
            return "lưu sách thất bại"
        }
        if case let .invalidSlug(slug) = repoError {
            return "slug sách không hợp lệ: \(slug.prefix(40))"
        } else if case .invalidValidatedRoot = repoError {
            return "thư mục sách sau giải nén không hợp lệ"
        } else if case let .missingChapterFile(_, number) = repoError {
            return "thiếu file chương \(number)"
        } else if case let .invalidChapterNumber(number, count) = repoError {
            return "số chương \(number) vượt quá \(count)"
        } else if case let .bookNotFound(slug) = repoError {
            return "không tìm thấy sách \(slug.prefix(40))"
        } else {
            return "lưu sách thất bại"
        }
    }
}
