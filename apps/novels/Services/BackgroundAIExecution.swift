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
    }

    private var batch: Batch?
    private var systemTask: BGContinuedProcessingTask?
    private var wasExpired = false

    func register() {
        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { task in
            Task { @MainActor in
                ContinuedPrefetchCoordinator.shared.launch(task)
            }
        }
    }

    func isProtecting(_ manager: PrefetchManager) -> Bool {
        batch?.manager === manager
    }

    /// Must be called from a user's foreground action; never from auto-prefetch.
    func submit(manager: PrefetchManager, chapters: Int) throws {
        guard batch == nil else { throw ContinuedPrefetchError.alreadyRunning }
        let identifier = "com.tungxuan.novels.ai-prefetch.\(UUID().uuidString)"
        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "Xử lý trước chương truyện",
            subtitle: "Đang chuẩn bị \(chapters) chương"
        )
        // A delayed request must not surprise the user or attach to a newer batch.
        request.strategy = .fail
        batch = Batch(identifier: identifier, manager: manager)
        wasExpired = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            batch = nil
            throw error
        }
    }

    func report(manager: PrefetchManager, processed: Int, total: Int) {
        guard batch?.manager === manager, let task = systemTask else { return }
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
        guard let batch, batch.identifier == task.identifier else {
            // A request delivered after relaunch cannot reuse an in-memory worker.
            task.setTaskCompleted(success: false)
            return
        }
        systemTask = task
        task.progress.totalUnitCount = 1
        task.progress.completedUnitCount = 0
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.expire(identifier: task.identifier)
            }
        }
        Task { @MainActor in
            let status = await batch.manager.waitForCompletion()
            guard self.batch?.identifier == batch.identifier else { return }
            let success = !wasExpired && status.errors.isEmpty
                && status.message.hasPrefix("Đã hoàn tất")
            task.setTaskCompleted(success: success)
            systemTask = nil
            self.batch = nil
        }
    }

    private func expire(identifier: String) {
        guard let batch, batch.identifier == identifier else { return }
        wasExpired = true
        Task { await batch.manager.cancel(reason: "systemExpiration") }
        // The waiter in launch() completes the system task exactly once.
    }
}

enum ContinuedPrefetchError: LocalizedError {
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "Đang có một lượt xử lý nền khác"
        }
    }
}
