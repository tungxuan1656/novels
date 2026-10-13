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
        static let aiProvider = "auto"
        static let aiCustomHeadersJSON = ""
        static let aiExtraBodyJSON = ""
        static let prefetchCount = 3
        static let aiMode = AIMode.none
        static let aiMinChunkSize = 1300
        static let diagnosticsVerbose = false
        static let readingTheme = ReadingTheme.sach
        static let aiBilingualPrompt = SettingsDefaults.defaultBilingualPrompt
        static let audioSource = AudioSource.apple
        static let audioAPIKey = ""
        static let audioModel = AudioSource.defaultModel
    }

    private let userDefaults: UserDefaults

    var booksAPIURL: String
    var openaiAPIURL: String
    var openaiModel: String
    var aiCustomHeadersJSON: String
    var aiExtraBodyJSON: String
    var aiProvider: String
    var aiAPIKey: String
    var aiThinkingEffort: String
    var aiPrompt: String
    var aiBilingualPrompt: String
    var aiMinChunkSize: Int
    var prefetchCount: Int
    var aiMode: AIMode
    var diagnosticsVerbose: Bool
    var readingTheme: ReadingTheme
    var typography: TypographySetting
    var session: ReadingSession?
    var audioSource: AudioSource
    var audioAPIKey: String
    var audioModel: String

    static let shared = SettingsStore()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        booksAPIURL = Defaults.booksAPIURL
        openaiAPIURL = Defaults.openaiAPIURL
        openaiModel = Defaults.openaiModel
        aiCustomHeadersJSON = Defaults.aiCustomHeadersJSON
        aiExtraBodyJSON = Defaults.aiExtraBodyJSON
        aiProvider = Defaults.aiProvider
        aiAPIKey = ""
        aiThinkingEffort = ""
        aiPrompt = SettingsDefaults.defaultPrompt
        aiBilingualPrompt = Defaults.aiBilingualPrompt
        aiMinChunkSize = Defaults.aiMinChunkSize
        prefetchCount = Defaults.prefetchCount
        aiMode = Defaults.aiMode
        diagnosticsVerbose = Defaults.diagnosticsVerbose
        readingTheme = Defaults.readingTheme
        typography = .default
        session = nil
        audioSource = Defaults.audioSource
        audioAPIKey = Defaults.audioAPIKey
        audioModel = Defaults.audioModel
        load()
        sanitize()
        removeLegacyKeys()
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
        aiAPIKey = userDefaults.string(forKey: DefaultsKeys.aiAPIKey) ?? ""
        aiThinkingEffort = userDefaults.string(forKey: DefaultsKeys.aiThinkingEffort) ?? ""
        if let value = userDefaults.string(forKey: DefaultsKeys.aiPrompt) {
            aiPrompt = value
        }
        if let value = userDefaults.string(forKey: DefaultsKeys.aiBilingualPrompt) {
            aiBilingualPrompt = value
        }
        if let value = intValue(forKey: DefaultsKeys.prefetchCount) {
            prefetchCount = value
        }
        if let value = intValue(forKey: DefaultsKeys.aiMinChunkSize) {
            aiMinChunkSize = value
        }
        let source = userDefaults.string(forKey: DefaultsKeys.audioSource)?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        audioSource = AudioSource(rawValue: source) ?? Defaults.audioSource
        audioAPIKey = userDefaults.string(forKey: DefaultsKeys.audioAPIKey) ?? Defaults.audioAPIKey
        audioModel = userDefaults.string(forKey: DefaultsKeys.audioModel) ?? Defaults.audioModel
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
        // Legacy letter-spacing default key (if present) is intentionally ignored as unknown.
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

    /// Restores reading theme; unknown rawValues coerce to .sach (BR-12).
    /// Legacy trio rawValues (vangGiay/trang/den) also coerce to .sach.
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
        aiProvider = AIProvider.normalized(aiProvider)?.rawValue ?? Defaults.aiProvider
        aiThinkingEffort = AIThinkingEffort.normalized(aiThinkingEffort)?.rawValue ?? ""
        if aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            aiPrompt = SettingsDefaults.defaultPrompt
        }
        if aiBilingualPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            aiBilingualPrompt = SettingsDefaults.defaultBilingualPrompt
        }
        audioModel = audioModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if audioModel.isEmpty { audioModel = Defaults.audioModel }
        typography.font = ReaderFontMapper.normalizedFontName(typography.font)
        if !(12 ... 40).contains(typography.fontSize) {
            typography.fontSize = TypographySetting.default.fontSize
        }
        if !(1.0 ... 50).contains(typography.lineHeight) {
            typography.lineHeight = TypographySetting.default.lineHeight
        }
        if let session, !SlugValidator.isValid(session.bookId) {
            self.session = nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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
        case "AI_API_KEY":
            return aiAPIKey
        case "AI_THINKING_EFFORT":
            return aiThinkingEffort
        case "AI_PROMPT":
            return aiPrompt
        case "AI_BILINGUAL_PROMPT":
            return aiBilingualPrompt
        case "AUDIO_SOURCE":
            return audioSource.rawValue
        case "AUDIO_API_KEY":
            return audioAPIKey
        case "AUDIO_MODEL":
            return audioModel
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
        case "AI_API_KEY":
            aiAPIKey = value
        case "AI_THINKING_EFFORT":
            aiThinkingEffort = value
        case "AI_PROMPT":
            aiPrompt = value
        case "AI_BILINGUAL_PROMPT":
            aiBilingualPrompt = value
        case "AUDIO_SOURCE":
            audioSource = AudioSource(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                ?? Defaults.audioSource
        case "AUDIO_API_KEY":
            audioAPIKey = value
        case "AUDIO_MODEL":
            audioModel = value
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
        default:
            break
        }
    }

    /// feat-027 legacy cleanup: the "letterSpacing" default key was removed, so
    /// drop the stale value for upgrading users who still carry it.
    private func removeLegacyKeys() {
        userDefaults.removeObject(forKey: "letterSpacing")
    }

    func save() {
        sanitize()
        removeLegacyKeys()
        userDefaults.set(booksAPIURL, forKey: DefaultsKeys.booksAPIURL)
        userDefaults.set(openaiAPIURL, forKey: DefaultsKeys.openaiAPIURL)
        userDefaults.set(openaiModel, forKey: DefaultsKeys.openaiModel)
        userDefaults.set(aiCustomHeadersJSON, forKey: DefaultsKeys.aiCustomHeadersJSON)
        userDefaults.set(aiExtraBodyJSON, forKey: DefaultsKeys.aiExtraBodyJSON)
        userDefaults.set(aiProvider, forKey: DefaultsKeys.aiProvider)
        userDefaults.set(aiAPIKey, forKey: DefaultsKeys.aiAPIKey)
        userDefaults.set(aiThinkingEffort, forKey: DefaultsKeys.aiThinkingEffort)
        userDefaults.set(aiPrompt, forKey: DefaultsKeys.aiPrompt)
        userDefaults.set(aiBilingualPrompt, forKey: DefaultsKeys.aiBilingualPrompt)
        userDefaults.set(audioSource.rawValue, forKey: DefaultsKeys.audioSource)
        userDefaults.set(audioAPIKey, forKey: DefaultsKeys.audioAPIKey)
        userDefaults.set(audioModel, forKey: DefaultsKeys.audioModel)
        userDefaults.set(aiMinChunkSize, forKey: DefaultsKeys.aiMinChunkSize)
        userDefaults.set(prefetchCount, forKey: DefaultsKeys.prefetchCount)
        userDefaults.set(aiMode.rawValue, forKey: DefaultsKeys.aiMode)
        userDefaults.set(readingTheme.rawValue, forKey: DefaultsKeys.readingTheme)
        userDefaults.set(diagnosticsVerbose, forKey: DefaultsKeys.diagnosticsVerbose)
        userDefaults.set(typography.font, forKey: DefaultsKeys.font)
        userDefaults.set(typography.fontSize, forKey: DefaultsKeys.fontSize)
        userDefaults.set(typography.lineHeight, forKey: DefaultsKeys.lineHeight)
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
        guard let dict = Self.jsonObject(from: aiCustomHeadersJSON) else {
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
        Self.jsonObject(from: aiExtraBodyJSON) ?? [:]
    }

    nonisolated static func jsonObject(from raw: String) -> [String: Any]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        return object as? [String: Any]
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
            // Int(Double) traps on finite-but-out-of-range values (e.g. a
            // corrupted 1e100 in UserDefaults); truncate toward zero via
            // Int(exactly:) so overflow is nil and load() keeps the default.
            guard doubleVal.isFinite else { return nil }
            return Int(exactly: doubleVal.rounded(.towardZero))
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
