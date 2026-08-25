import Foundation

struct Book: Codable, Equatable {
    let id: String
    let name: String
    let author: String?
    let count: Int
    let references: [Reference]
}
