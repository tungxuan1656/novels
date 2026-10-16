import BackgroundTasks
import Foundation
import UIKit

/// A finite, best-effort extension for AI requests that were already in flight
/// when the app moved to the background. This is not a background daemon.
@MainActor
final class BackgroundAIExecution {
    static let shared = BackgroundAIExecution()

    private var activeOperations = 0
    private var isBackground = false
    private var assertion: UIBackgroundTaskIdentifier = .invalid

    func operationStarted() {
        activeOperations += 1
        beginIfNeeded()
    }

    func operationFinished() {
        activeOperations = max(0, activeOperations - 1)
        if activeOperations == 0 {
            endAssertion()
        }
    }

    func sceneChanged(isBackground: Bool) {
        self.isBackground = isBackground
        if isBackground {
            beginIfNeeded()
        } else {
            endAssertion()
        }
    }

    private func beginIfNeeded() {
        guard isBackground, activeOperations > 0, assertion == .invalid else { return }
        assertion = UIApplication.shared.beginBackgroundTask(withName: "Novels AI request") { [weak self] in
            Task { @MainActor in
                self?.endAssertion()
            }
        }
    }

    private func endAssertion() {
        guard assertion != .invalid else { return }
        let identifier = assertion
        assertion = .invalid
        UIApplication.shared.endBackgroundTask(identifier)
    }
}

/// iOS 26 continued-processing is reserved for an explicit button press.
/// The existing PrefetchManager remains the only worker and AI cache owner.
@MainActor
final class ContinuedPrefetchCoordinator {
    static let shared = ContinuedPrefetchCoordinator()
    static let identifier = "com.tungxuan.novels.ai-prefetch.*"

    private struct Batch {
        let identifier: String
        let manager: PrefetchManager
        let worker: PrefetchManager.ContinuedBatch
    }

    private var batch: Batch?
    private var completion: ((Bool) -> Void)?
    private let submitRequest: (BGContinuedProcessingTaskRequest) throws -> Void

    init(submitRequest: @escaping (BGContinuedProcessingTaskRequest) throws -> Void = {
        try BGTaskScheduler.shared.submit($0)
    }) {
        self.submitRequest = submitRequest
    }

    func register() {
        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { task in
            Task { @MainActor in
                ContinuedPrefetchCoordinator.shared.launch(task)
            }
        }
    }

    /// Must be called from a user's foreground action; never from auto-prefetch.
    func submit(manager: PrefetchManager, chapters: Int) async throws {
        guard batch == nil else { throw ContinuedPrefetchError.alreadyRunning }
        guard let worker = await manager.protectCurrentBatch() else {
            throw ContinuedPrefetchError.notRunning
        }
        guard batch == nil else {
            await manager.releaseProtection(generation: worker.generation)
            throw ContinuedPrefetchError.alreadyRunning
        }
        let identifier = "com.tungxuan.novels.ai-prefetch.\(UUID().uuidString)"
        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "Xử lý trước chương truyện",
            subtitle: "Đang chuẩn bị \(chapters) chương"
        )
        // A delayed request must not surprise the user or attach to a newer batch.
        request.strategy = .fail
        batch = Batch(identifier: identifier, manager: manager, worker: worker)
        do {
            try submitRequest(request)
        } catch {
            batch = nil
            await manager.releaseProtection(generation: worker.generation)
            throw error
        }
    }

    private func report(_ status: PrefetchStatus, task: BGContinuedProcessingTask) {
        let processed = status.processedChapters
        let total = status.totalChapters
        task.progress.totalUnitCount = Int64(max(total, 1))
        task.progress.completedUnitCount = Int64(min(max(0, processed), max(total, 1)))
        task.updateTitle(
            "Xử lý trước chương truyện",
            subtitle: "Đã xong \(processed)/\(total) chương"
        )
    }

    private func launch(_ task: BGTask) {
        guard let task = task as? BGContinuedProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }
        guard batch?.identifier == task.identifier else {
            // A request delivered after relaunch cannot reuse an in-memory worker.
            task.setTaskCompleted(success: false)
            return
        }
        task.progress.totalUnitCount = 1
        task.progress.completedUnitCount = 0
        let identifier = task.identifier
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.expire(identifier: identifier)
            }
        }
        launch(
            identifier: identifier, report: { self.report($0, task: task) },
            completion: { task.setTaskCompleted(success: $0) }
        )
    }

    func launch(identifier: String, report: @escaping (PrefetchStatus) -> Void, completion: @escaping (Bool) -> Void) {
        guard let batch, batch.identifier == identifier else {
            completion(false)
            return
        }
        self.completion = completion
        Task { @MainActor in
            var success = false
            for await status in batch.worker.updates {
                guard self.batch?.identifier == identifier else { return }
                report(status)
                success = !status.isRunning && status.errors.isEmpty
                    && status.message.hasPrefix("Đã hoàn tất")
            }
            self.complete(identifier: identifier, success: success)
        }
    }

    func expire(identifier: String) {
        guard let batch, batch.identifier == identifier else { return }
        // A shared AI request can outlive this worker; never await it on expiration.
        complete(identifier: identifier, success: false)
        Task {
            await batch.manager.cancel(reason: "systemExpiration", generation: batch.worker.generation)
        }
    }

    private func complete(identifier: String, success: Bool) {
        guard batch?.identifier == identifier else { return }
        let completion = completion
        self.completion = nil
        batch = nil
        completion?(success)
    }
}

enum ContinuedPrefetchError: LocalizedError {
    case alreadyRunning
    case notRunning

    var errorDescription: String? {
        self == .alreadyRunning
            ? "Đang có một lượt xử lý nền khác"
            : "Không có lượt tải trước đang chạy"
    }
}
