// swiftformat:disable all
import Foundation

enum DefaultsKeys {
    static let booksAPIURL = "BOOKS_API_URL"
    static let openaiAPIURL = "OPENAI_API_URL"
    static let openaiModel = "OPENAI_MODEL"
    static let aiCustomHeadersJSON = "AI_CUSTOM_HEADERS"
    static let aiExtraBodyJSON = "AI_EXTRA_BODY"
    static let aiProvider = "AI_PROVIDER"
    static let aiAPIKey = "AI_API_KEY"
    static let aiThinkingEffort = "AI_THINKING_EFFORT"
    static let aiPrompt = "AI_PROMPT"
    static let aiBilingualPrompt = "AI_BILINGUAL_PROMPT"
    static let aiMinChunkSize = "AI_MIN_CHUNK_SIZE"
    static let prefetchCount = "PREFETCH_COUNT"
    static let aiMode = "AI_MODE"
    static let bilingualEnglishPrimary = "bilingualEnglishPrimary"
    static let font = "font"
    static let fontSize = "fontSize"
    static let lineHeight = "lineHeight"
    static let readingTheme = "readingTheme"
    static let readingSession = "ReadingSession"
    static let diagnosticsVerbose = "DIAGNOSTICS_VERBOSE"
    static let audioSource = "AUDIO_SOURCE"
    static let audioAPIKey = "AUDIO_API_KEY"
    static let audioModel = "AUDIO_MODEL"

    static let allCurrent: [String] = [
        booksAPIURL,
        openaiAPIURL,
        openaiModel,
        aiCustomHeadersJSON,
        aiExtraBodyJSON,
        aiProvider,
        aiAPIKey,
        aiThinkingEffort,
        aiPrompt,
        aiBilingualPrompt,
        aiMinChunkSize,
        prefetchCount,
        aiMode,
        bilingualEnglishPrimary,
        font,
        fontSize,
        lineHeight,
        readingTheme,
        readingSession,
        diagnosticsVerbose,
        audioSource,
        audioAPIKey,
        audioModel
    ]
}
