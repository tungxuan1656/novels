import Foundation

nonisolated struct PrefetchStatus: Equatable, Sendable {
    var isRunning: Bool = false
    var currentBookId: String?
    var totalChapters: Int = 0
    var processedChapters: Int = 0
    var message: String = ""
    var errors: [String] = []
    init(
        isRunning: Bool = false,
        currentBookId: String? = nil,
        totalChapters: Int = 0,
        processedChapters: Int = 0,
        message: String = "",
        errors: [String] = []
    ) {
        self.isRunning = isRunning; self.currentBookId = currentBookId; self.totalChapters = totalChapters; self
            .processedChapters = processedChapters; self.message = message; self.errors = errors
    }

    static var idle: PrefetchStatus {
        PrefetchStatus()
    }
}
