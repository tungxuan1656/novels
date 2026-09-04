// swiftformat:disable all
import Foundation

enum DefaultsKeys {
    static let booksAPIURL = "BOOKS_API_URL"
    static let openaiAPIURL = "OPENAI_API_URL"
    static let openaiModel = "OPENAI_MODEL"
    static let aiCustomHeadersJSON = "AI_CUSTOM_HEADERS"
    static let aiExtraBodyJSON = "AI_EXTRA_BODY"
    static let aiProvider = "AI_PROVIDER"
    static let aiPrompt = "AI_PROMPT"
    static let aiMinChunkSize = "AI_MIN_CHUNK_SIZE"
    static let prefetchCount = "PREFETCH_COUNT"
    static let aiMode = "AI_MODE"
    static let font = "font"
    static let fontSize = "fontSize"
    static let lineHeight = "lineHeight"
    static let letterSpacing = "letterSpacing"
    static let readingSession = "ReadingSession"
    static let diagnosticsVerbose = "DIAGNOSTICS_VERBOSE"

    static let allCurrent: [String] = [
        booksAPIURL,
        openaiAPIURL,
        openaiModel,
        aiCustomHeadersJSON,
        aiExtraBodyJSON,
        aiProvider,
        aiPrompt,
        aiMinChunkSize,
        prefetchCount,
        aiMode,
        font,
        fontSize,
        lineHeight,
        letterSpacing,
        readingSession,
        diagnosticsVerbose
    ]
}
