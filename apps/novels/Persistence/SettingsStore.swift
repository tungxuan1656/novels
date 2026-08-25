// swiftformat:disable all
import Foundation
import Observation

@MainActor
@Observable final class SettingsStore {
    private enum Defaults {
        static let booksAPIURL = "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books"
        static let openaiAPIURL = "http://localhost:8317/v1/chat/completions"
        static let openaiModel = "gpt-4o"
        static let aiProvider = "openai"
        static let aiCustomHeadersJSON = ""
        static let aiExtraBodyJSON = ""
        static let prefetchCount = 3
        static let aiMinChunkSize = 1300
    }

    private let userDefaults: UserDefaults

    var booksAPIURL: String
    var openaiAPIURL: String
    var openaiModel: String
    var aiCustomHeadersJSON: String
    var aiExtraBodyJSON: String
    var aiProvider: String
    var aiProcessActionsJSON: String
    var aiMinChunkSize: Int
    var prefetchCount: Int
    var typography: TypographySetting
    var session: ReadingSession?

    static let shared = SettingsStore()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        booksAPIURL = Defaults.booksAPIURL
        openaiAPIURL = Defaults.openaiAPIURL
        openaiModel = Defaults.openaiModel
        aiCustomHeadersJSON = Defaults.aiCustomHeadersJSON
        aiExtraBodyJSON = Defaults.aiExtraBodyJSON
        aiProvider = Defaults.aiProvider
        aiProcessActionsJSON = SettingsDefaults.defaultActionsJSON
        aiMinChunkSize = Defaults.aiMinChunkSize
        prefetchCount = Defaults.prefetchCount
        typography = .default
        session = nil
        load()
        sanitize()
    }

    // swiftlint:disable:next cyclomatic_complexity
    func load() {
        if let value = userDefaults.string(forKey: DefaultsKeys.booksAPIURL) {
            booksAPIURL = value
        } else if userDefaults.object(forKey: DefaultsKeys.booksAPIURL) != nil {
            booksAPIURL = Defaults.booksAPIURL
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.openaiAPIURL) {
            openaiAPIURL = value
        } else if userDefaults.object(forKey: DefaultsKeys.openaiAPIURL) != nil {
            openaiAPIURL = Defaults.openaiAPIURL
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.openaiModel) {
            openaiModel = value
        } else if userDefaults.object(forKey: DefaultsKeys.openaiModel) != nil {
            openaiModel = Defaults.openaiModel
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.aiCustomHeadersJSON) {
            aiCustomHeadersJSON = value
        } else if userDefaults.object(forKey: DefaultsKeys.aiCustomHeadersJSON) != nil {
            aiCustomHeadersJSON = Defaults.aiCustomHeadersJSON
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.aiExtraBodyJSON) {
            aiExtraBodyJSON = value
        } else if userDefaults.object(forKey: DefaultsKeys.aiExtraBodyJSON) != nil {
            aiExtraBodyJSON = Defaults.aiExtraBodyJSON
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.aiProvider) {
            aiProvider = value
        } else if userDefaults.object(forKey: DefaultsKeys.aiProvider) != nil {
            aiProvider = Defaults.aiProvider
        }
        if userDefaults.object(forKey: DefaultsKeys.aiProcessActionsJSON) != nil, let value = userDefaults.string(forKey: DefaultsKeys.aiProcessActionsJSON) { // swiftlint:disable:this line_length
            aiProcessActionsJSON = value
        }
        if let value = intValue(forKey: DefaultsKeys.prefetchCount) {
            prefetchCount = value
        }
        if let value = intValue(forKey: DefaultsKeys.aiMinChunkSize) {
            aiMinChunkSize = value
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.font) {
            typography.font = value
        }
        if let value = doubleValue(forKey: DefaultsKeys.fontSize) {
            typography.fontSize = value
        }
        if let value = doubleValue(forKey: DefaultsKeys.lineHeight) {
            typography.lineHeight = value
        }
        if let value = doubleValue(forKey: DefaultsKeys.letterSpacing) {
            typography.letterSpacing = value
        }
        if let data = userDefaults.data(forKey: DefaultsKeys.readingSession) {
            session = try? JSONDecoder().decode(ReadingSession.self, from: data)
        } else if let str = userDefaults.string(forKey: DefaultsKeys.readingSession), let data = str.data(using: .utf8) { // swiftlint:disable:this line_length
            session = try? JSONDecoder().decode(ReadingSession.self, from: data)
        } else {
            session = nil
        }
    }

    func sanitize() {
        if booksAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            booksAPIURL = Defaults.booksAPIURL
        }
        if openaiAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            openaiAPIURL = Defaults.openaiAPIURL
        }
        if openaiModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            openaiModel = Defaults.openaiModel
        }
        if !(1 ... 10).contains(prefetchCount) {
            prefetchCount = Defaults.prefetchCount
        }
        if !(500 ... 5000).contains(aiMinChunkSize) {
            aiMinChunkSize = Defaults.aiMinChunkSize
        }
        if aiProvider.lowercased() != "openai" {
            aiProvider = Defaults.aiProvider
        } else {
            aiProvider = "openai"
        }
        let allowedKeys: Set = ["translate", "summary"]
        if let data = aiProcessActionsJSON.data(using: .utf8), let actions = try? JSONDecoder().decode([AIAction].self, from: data), !actions.isEmpty, actions.allSatisfy({ allowedKeys.contains($0.key) }) { // swiftlint:disable:this line_length
            // valid
        } else {
            aiProcessActionsJSON = SettingsDefaults.defaultActionsJSON
        }
        if typography.font.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            typography.font = TypographySetting.default.font
        }
        if !(12 ... 24).contains(typography.fontSize) {
            typography.fontSize = TypographySetting.default.fontSize
        }
        if !(1.2 ... 2.0).contains(typography.lineHeight) {
            typography.lineHeight = TypographySetting.default.lineHeight
        }
        if !(0 ... 1.0).contains(typography.letterSpacing) {
            typography.letterSpacing = TypographySetting.default.letterSpacing
        }
    }

    func save() {
        sanitize()
        userDefaults.set(booksAPIURL, forKey: DefaultsKeys.booksAPIURL)
        userDefaults.set(openaiAPIURL, forKey: DefaultsKeys.openaiAPIURL)
        userDefaults.set(openaiModel, forKey: DefaultsKeys.openaiModel)
        userDefaults.set(aiCustomHeadersJSON, forKey: DefaultsKeys.aiCustomHeadersJSON)
        userDefaults.set(aiExtraBodyJSON, forKey: DefaultsKeys.aiExtraBodyJSON)
        userDefaults.set(aiProvider, forKey: DefaultsKeys.aiProvider)
        userDefaults.set(aiProcessActionsJSON, forKey: DefaultsKeys.aiProcessActionsJSON)
        userDefaults.set(aiMinChunkSize, forKey: DefaultsKeys.aiMinChunkSize)
        userDefaults.set(prefetchCount, forKey: DefaultsKeys.prefetchCount)
        userDefaults.set(typography.font, forKey: DefaultsKeys.font)
        userDefaults.set(typography.fontSize, forKey: DefaultsKeys.fontSize)
        userDefaults.set(typography.lineHeight, forKey: DefaultsKeys.lineHeight)
        userDefaults.set(typography.letterSpacing, forKey: DefaultsKeys.letterSpacing)
        if let session {
            if let data = try? JSONEncoder().encode(session) {
                userDefaults.set(data, forKey: DefaultsKeys.readingSession)
            }
        } else {
            userDefaults.removeObject(forKey: DefaultsKeys.readingSession)
        }
    }

    func effectiveHeaders() -> [String: String] {
        let trimmed = aiCustomHeadersJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in dict {
            if let str = value as? String {
                result[key] = str
            }
        }
        return result
    }

    func effectiveExtraBody() -> [String: Any] {
        let trimmed = aiExtraBodyJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func intValue(forKey key: String) -> Int? {
        guard let obj = userDefaults.object(forKey: key) else {
            return nil
        }
        if let intVal = obj as? Int {
            return intVal
        }
        if let str = obj as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if let intVal = Int(trimmed) {
                return intVal
            }
            if let doubleVal = Double(trimmed) {
                return Int(doubleVal)
            }
            return nil
        }
        if let doubleVal = obj as? Double {
            return Int(doubleVal)
        }
        if let num = obj as? NSNumber {
            return num.intValue
        }
        return nil
    }

    private func doubleValue(forKey key: String) -> Double? {
        guard let obj = userDefaults.object(forKey: key) else {
            return nil
        }
        if let doubleVal = obj as? Double {
            return doubleVal
        }
        if let intVal = obj as? Int {
            return Double(intVal)
        }
        if let str = obj as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if let doubleVal = Double(trimmed) {
                return doubleVal
            }
            return nil
        }
        if let num = obj as? NSNumber {
            return num.doubleValue
        }
        return nil
    }
}
