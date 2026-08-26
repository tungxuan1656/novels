import Foundation

struct Book: Codable, Equatable {
    let id: String
    let name: String
    let author: String?
    let count: Int
    let references: [Reference]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case author
        case count
        case references
    }

    init(id: String, name: String, author: String?, count: Int, references: [Reference]) {
        self.id = id
        self.name = name
        self.author = author
        self.count = count
        self.references = references
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedName = try container.decode(String.self, forKey: .name)
        if let id = try container.decodeIfPresent(String.self, forKey: .id), !id.isEmpty {
            self.id = id
        } else {
            id = Book.slugify(decodedName)
        }
        name = decodedName
        author = try container.decodeIfPresent(String.self, forKey: .author)
        count = try container.decode(Int.self, forKey: .count)
        references = try container.decode([Reference].self, forKey: .references)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encode(count, forKey: .count)
        try container.encode(references, forKey: .references)
    }

    static func slugify(_ string: String) -> String {
        let folded = string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        var result = ""
        var needDash = false
        for char in folded {
            if char.isLetter || char.isNumber {
                result.append(char)
                needDash = false
            } else if !needDash {
                result.append("-")
                needDash = true
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
