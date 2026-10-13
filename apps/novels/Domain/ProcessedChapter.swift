import Foundation

nonisolated struct ProcessedChapter: Equatable, Sendable {
    let bookId: String
    let chapterNumber: Int
    let mode: AIMode
    let content: String
    let contentHash: String
    let createdAt: Date
    let updatedAt: Date
}
