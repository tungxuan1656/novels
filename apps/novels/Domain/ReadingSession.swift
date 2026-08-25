import Foundation

struct ReadingSession: Codable, Equatable {
    var bookId: String
    var onScreen: Bool
    var offset: Double
    var chapterNumber: Int
}
