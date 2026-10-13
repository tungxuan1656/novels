import Foundation

nonisolated struct ProcessedBookSummary: Equatable, Sendable {
    let bookId: String
    let versionCount: Int
    let chapterCount: Int
}

nonisolated struct ProcessedChapterMetadata: Equatable, Hashable, Identifiable, Sendable {
    let chapterNumber: Int
    let mode: AIMode
    let updatedAt: Date

    var id: String {
        "\(chapterNumber)-\(mode.rawValue)"
    }
}
