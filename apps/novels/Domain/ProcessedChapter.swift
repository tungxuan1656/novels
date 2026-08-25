import Foundation

struct ProcessedChapter: Equatable {
    let bookId: String
    let chapterNumber: Int
    let mode: AIMode
    let content: String
    let contentHash: String
    let createdAt: Date
    let updatedAt: Date
}
