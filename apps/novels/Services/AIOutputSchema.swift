import CoreFoundation
import Foundation

nonisolated struct AIOutputSchema: Sendable {
    let name: String
    let json: String

    func object(strict: Bool = false) throws -> [String: Any] {
        guard !name.isEmpty, name.count <= 64,
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "object"
        else {
            throw AIClientError.invalidConfiguration("Output schema needs a valid name and an object JSON Schema.")
        }
        if strict {
            try Self.validateStrictObjects(object)
        }
        return object
    }

    private static func validateStrictObjects(_ schema: [String: Any]) throws {
        let isObject = schema["type"] as? String == "object"
            || (schema["type"] as? [String])?.contains("object") == true
            || schema["properties"] != nil
        if isObject {
            guard let additional = schema["additionalProperties"] as? NSNumber,
                  CFGetTypeID(additional) == CFBooleanGetTypeID(), !additional.boolValue,
                  let properties = schema["properties"] as? [String: Any],
                  let required = schema["required"] as? [String],
                  required.count == properties.count, Set(required) == Set(properties.keys)
            else {
                throw AIClientError.invalidConfiguration(
                    "Strict output schema objects need additionalProperties=false and all properties required."
                )
            }
        }
        for key in ["properties", "$defs", "definitions"] {
            for child in (schema[key] as? [String: Any] ?? [:]).values {
                if let child = child as? [String: Any] {
                    try validateStrictObjects(child)
                }
            }
        }
        for key in ["items", "additionalProperties"] {
            if let child = schema[key] as? [String: Any] {
                try validateStrictObjects(child)
            }
        }
        for key in ["anyOf", "oneOf", "allOf", "prefixItems"] {
            for child in schema[key] as? [[String: Any]] ?? [] {
                try validateStrictObjects(child)
            }
        }
    }
}
