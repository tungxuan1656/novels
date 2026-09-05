// swiftformat:disable all
import Foundation
import Observation

@MainActor
// swiftlint:disable:next type_body_length
@Observable final class SettingsStore {
    private enum Defaults {
        static let booksAPIURL = "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books"
        static let openaiAPIURL = "http://localhost:8317/v1/chat/completions"
        static let openaiModel = "gpt-4o"
        static let aiProvider = "openai"
        static let aiCustomHeadersJSON = ""
        static let aiExtraBodyJSON = ""
        static let prefetchCount = 3
        static let aiMode = AIMode.none
        static let aiMinChunkSize = 1300
        static let diagnosticsVerbose = false
        static let readingTheme = ReadingTheme.vangGiay
    }

    private let userDefaults: UserDefaults

    var booksAPIURL: String
    var openaiAPIURL: String
    var openaiModel: String
    var aiCustomHeadersJSON: String
    var aiExtraBodyJSON: String
    var aiProvider: String
    var aiPrompt: String
    var aiMinChunkSize: Int
    var prefetchCount: Int
    var aiMode: AIMode
    var diagnosticsVerbose: Bool
    var readingTheme: ReadingTheme
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
        aiPrompt = SettingsDefaults.defaultPrompt
        aiMinChunkSize = Defaults.aiMinChunkSize
        prefetchCount = Defaults.prefetchCount
        aiMode = Defaults.aiMode
        diagnosticsVerbose = Defaults.diagnosticsVerbose
        readingTheme = Defaults.readingTheme
        typography = .default
        session = nil
        load()
        sanitize()
    }

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
        if let value = userDefaults.string(forKey: DefaultsKeys.aiPrompt) {
            aiPrompt = value
        }
        if let value = intValue(forKey: DefaultsKeys.prefetchCount) {
            prefetchCount = value
        }
        if let value = intValue(forKey: DefaultsKeys.aiMinChunkSize) {
            aiMinChunkSize = value
        }
        loadAiMode()
        loadReadingTheme()
        loadDiagnosticsTypographySession()
    }

    private func loadDiagnosticsTypographySession() {
        if userDefaults.object(forKey: DefaultsKeys.diagnosticsVerbose) != nil {
            diagnosticsVerbose = userDefaults.bool(forKey: DefaultsKeys.diagnosticsVerbose)
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.font) {
            typography.font = ReaderFontMapper.normalizedFontName(value)
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
        } else {
            session = nil
        }
    }

    /// Shared helper: returns clamped prefetch count without mutating stored value.
    /// Stored `prefetchCount` stays as-is (e.g., 1001) until `save()` → `sanitize()` coerces it,
    /// while `effectivePrefetchCount()` returns the fallback (Defaults.prefetchCount = 3) read-only.
    private func clampedPrefetchCount(_ value: Int) -> Int {
        (0 ... 1000).contains(value) ? value : Defaults.prefetchCount
    }

    /// Restores app-wide AI mode; unknown rawValues coerce to .none (BR-12).
    private func loadAiMode() {
        if let raw = userDefaults.string(forKey: DefaultsKeys.aiMode) {
            aiMode = AIMode(rawValue: raw) ?? Defaults.aiMode
        } else if userDefaults.object(forKey: DefaultsKeys.aiMode) != nil {
            aiMode = Defaults.aiMode
        }
    }

    /// Restores reading theme; unknown rawValues coerce to .vangGiay (BR-12).
    private func loadReadingTheme() {
        if let raw = userDefaults.string(forKey: DefaultsKeys.readingTheme) {
            readingTheme = ReadingTheme(rawValue: raw) ?? Defaults.readingTheme
        } else if userDefaults.object(forKey: DefaultsKeys.readingTheme) != nil {
            readingTheme = Defaults.readingTheme
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
        prefetchCount = clampedPrefetchCount(prefetchCount)
        // BR-12: aiMode is a closed enum — load() already coerces unknown rawValues to .none.
        // BR-12: Bool is self-validating — missing key already defaults to false on load.
        if !(500 ... 10000).contains(aiMinChunkSize) {
            aiMinChunkSize = Defaults.aiMinChunkSize
        }
        if aiProvider.lowercased() != "openai" {
            aiProvider = Defaults.aiProvider
        } else {
            aiProvider = "openai"
        }
        if aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            aiPrompt = SettingsDefaults.defaultPrompt
        }
        typography.font = ReaderFontMapper.normalizedFontName(typography.font)
        if !(12 ... 40).contains(typography.fontSize) {
            typography.fontSize = TypographySetting.default.fontSize
        }
        if !(1.0 ... 50).contains(typography.lineHeight) {
            typography.lineHeight = TypographySetting.default.lineHeight
        }
        if !(0 ... 3.0).contains(typography.letterSpacing) {
            typography.letterSpacing = TypographySetting.default.letterSpacing
        }
        if let session, !SlugValidator.isValid(session.bookId) {
            self.session = nil
        }
    }

    func value(forKey key: String) -> String {
        switch key {
        case "BOOKS_API_URL":
            return booksAPIURL
        case "OPENAI_API_URL":
            return openaiAPIURL
        case "OPENAI_MODEL":
            return openaiModel
        case "AI_CUSTOM_HEADERS":
            return aiCustomHeadersJSON
        case "AI_EXTRA_BODY":
            return aiExtraBodyJSON
        case "AI_PROVIDER":
            return aiProvider
        case "AI_PROMPT":
            return aiPrompt
        case "PREFETCH_COUNT":
            return "\(prefetchCount)"
        case "AI_MIN_CHUNK_SIZE":
            return "\(aiMinChunkSize)"
        case "DIAGNOSTICS_VERBOSE":
            return diagnosticsVerbose ? "true" : "false"
        case "font":
            return typography.font
        case "fontSize":
            return String(format: "%g", typography.fontSize)
        case "lineHeight":
            return String(format: "%.1f", typography.lineHeight)
        case "letterSpacing":
            return String(format: "%.1f", typography.letterSpacing)
        default:
            return ""
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func setValue(_ value: String, forKey key: String) {
        switch key {
        case "BOOKS_API_URL":
            booksAPIURL = value
        case "OPENAI_API_URL":
            openaiAPIURL = value
        case "OPENAI_MODEL":
            openaiModel = value
        case "AI_CUSTOM_HEADERS":
            aiCustomHeadersJSON = value
        case "AI_EXTRA_BODY":
            aiExtraBodyJSON = value
        case "AI_PROVIDER":
            aiProvider = value
        case "AI_PROMPT":
            aiPrompt = value
        case "PREFETCH_COUNT":
            if let intValue = SettingDescriptor.parsedPrefetchCount(value) {
                prefetchCount = intValue
            } // keep prior valid value on parse failure
        case "AI_MIN_CHUNK_SIZE":
            if let intValue = Int(value) {
                aiMinChunkSize = intValue
            } // keep prior valid value on parse failure
        case "DIAGNOSTICS_VERBOSE":
            diagnosticsVerbose = ["true", "1", "yes"].contains(value.lowercased())
        case "font":
            typography.font = ReaderFontMapper.normalizedFontName(value)
        case "fontSize":
            if let doubleValue = Double(value) {
                typography.fontSize = doubleValue
            } // keep prior valid value on parse failure
        case "lineHeight":
            if let doubleValue = Double(value) {
                typography.lineHeight = doubleValue
            } // keep prior valid value on parse failure
        case "letterSpacing":
            if let doubleValue = Double(value) {
                typography.letterSpacing = doubleValue
            } // keep prior valid value on parse failure
        default:
            break
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
        userDefaults.set(aiPrompt, forKey: DefaultsKeys.aiPrompt)
        userDefaults.set(aiMinChunkSize, forKey: DefaultsKeys.aiMinChunkSize)
        userDefaults.set(prefetchCount, forKey: DefaultsKeys.prefetchCount)
        userDefaults.set(aiMode.rawValue, forKey: DefaultsKeys.aiMode)
        userDefaults.set(readingTheme.rawValue, forKey: DefaultsKeys.readingTheme)
        userDefaults.set(diagnosticsVerbose, forKey: DefaultsKeys.diagnosticsVerbose)
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

    func effectivePrefetchCount() -> Int {
        // Non-mutating read: returns clamped value without coercing stored prefetchCount (stays 1001 until save()).
        clampedPrefetchCount(prefetchCount)
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
            // Shared trim rule with editor validation and setValue (feat-023 Phase 3).
            return SettingDescriptor.parsedPrefetchCount(str)
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
