import BackgroundTasks
import SwiftData

final class PlaudBackgroundSyncScheduler {
    static let identifier = "ai.memora.plaud-cloud-sync"
    static let shared = PlaudBackgroundSyncScheduler()

    private let minimumInterval: TimeInterval = 60 * 60
    private var isRegistered = false

    private init() {}

    func register() {
        guard !isRegistered else { return }
        isRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.identifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handle(processingTask)
        }
    }

    func scheduleNextSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.identifier)
        let request = BGProcessingTaskRequest(identifier: Self.identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date().addingTimeInterval(minimumInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            DebugLogger.shared.addLog("PLAUD", "バックグラウンド同期を予約できません: \(error.localizedDescription)", level: .warning)
        }
    }

    private func handle(_ task: BGProcessingTask) {
        let work = Task { @MainActor in
            do {
                let container = try MemoraApp.createBackgroundSyncModelContainer()
                let context = ModelContext(container)
                guard let settings = try context.fetch(FetchDescriptor<PlaudSettings>()).first,
                      settings.isEnabled,
                      settings.autoSyncEnabled,
                      PlaudMCPOAuthService().account().isConnected else {
                    task.setTaskCompleted(success: true)
                    return
                }

                let result = try await PlaudCloudSyncService(modelContext: context).sync()
                settings.lastSyncAt = Date()
                settings.updatedAt = Date()
                try context.save()
                DebugLogger.shared.addLog(
                    "PLAUD",
                    "バックグラウンド同期完了: 取込 \(result.importedCount)件、失敗 \(result.failedCount)件",
                    level: result.failedCount == 0 ? .info : .warning
                )
                scheduleNextSync()
                task.setTaskCompleted(success: result.failedCount == 0)
            } catch is CancellationError {
                task.setTaskCompleted(success: false)
            } catch {
                DebugLogger.shared.addLog("PLAUD", "バックグラウンド同期失敗: \(error.localizedDescription)", level: .warning)
                scheduleNextSync()
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { work.cancel() }
    }
}
