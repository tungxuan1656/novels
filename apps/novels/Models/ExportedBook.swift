import Foundation

struct CatalogResponse: Codable {
    let success: Bool
    let data: [ExportedBook]
    let message: String?
}

struct ExportedBook: Codable, Equatable {
    let id: Int
    let bookId: Int
    let exportUrl: String
    let fileSize: Int
    let exportFormat: String
    let exportedAt: String
    let updatedAt: String
    let book: BookMeta
}

struct BookMeta: Codable, Equatable {
    let id: Int
    let name: String
    let slug: String
    let author: String?
    let chapterCount: Int?
    let status: String?
    let synopsis: String?
    let lastUpdated: String?
}
