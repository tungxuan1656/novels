import Foundation

struct ProcessedChapterMetadata: Equatable, Hashable, Identifiable {
    let chapterNumber: Int
    let mode: AIMode
    let updatedAt: Date

    var id: String {
        "\(chapterNumber)-\(mode.rawValue)"
    }
}
