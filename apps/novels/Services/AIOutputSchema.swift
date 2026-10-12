import Foundation

nonisolated struct AIOutputSchema: Sendable {
    let name: String
    let json: String

    func object() throws -> [String: Any] {
        guard !name.isEmpty, name.count <= 64,
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "object"
        else {
            throw AIClientError.invalidConfiguration("Output schema needs a valid name and an object JSON Schema.")
        }
        return object
    }
}
