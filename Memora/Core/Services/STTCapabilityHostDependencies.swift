import Foundation
import UIKit

// 挙動を伴うホスト依存の live 実装。契約は STTExecutionCapabilities に置く。

struct UIKitSTTBackgroundTaskManager: STTBackgroundTaskManaging {
    @MainActor
    func beginBackgroundTask(
        named name: String,
        expirationHandler: @escaping @Sendable () -> Void
    ) -> STTBackgroundTaskToken? {
        let identifier = UIApplication.shared.beginBackgroundTask(
            withName: name,
            expirationHandler: expirationHandler
        )
        guard identifier != .invalid else { return nil }
        return STTBackgroundTaskToken(rawValue: identifier.rawValue)
    }

    @MainActor
    func endBackgroundTask(_ token: STTBackgroundTaskToken) {
        UIApplication.shared.endBackgroundTask(
            UIBackgroundTaskIdentifier(rawValue: token.rawValue)
        )
    }
}

struct UIKitSTTIdleTimerManager: STTIdleTimerManaging {
    @MainActor
    func setIdleTimerDisabled(_ isDisabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isDisabled
    }
}

struct UIKitSTTMemoryWarningObserver: STTMemoryWarningObserving {
    func observeMemoryWarnings(_ handler: @escaping @Sendable () -> Void) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }
}

extension STTExecutionHostCapabilities {
    static let live = STTExecutionHostCapabilities(
        backgroundTasks: UIKitSTTBackgroundTaskManager(),
        idleTimer: UIKitSTTIdleTimerManager(),
        memoryWarnings: UIKitSTTMemoryWarningObserver()
    )
}

struct FileBackedSTTCheckpointHooksProvider: STTCheckpointHooksProviding {
    private let directoryURL: @Sendable () -> URL

    init(
        directoryURL: @escaping @Sendable () -> URL = {
            TranscriptionCheckpointStore.defaultDirectoryURL(fileManager: .default)
        }
    ) {
        self.directoryURL = directoryURL
    }

    func makeHooks(audioFileID: UUID) -> STTCheckpointHooks {
        let checkpointStore = TranscriptionCheckpointStore(directoryURL: directoryURL())
        return STTCheckpointHooks(
            load: { fingerprint in
                await checkpointStore.load(
                    audioFileID: audioFileID,
                    fingerprint: fingerprint
                )
            },
            save: { fingerprint, totalChunks, chunkIndex, result in
                await checkpointStore.save(
                    audioFileID: audioFileID,
                    fingerprint: fingerprint,
                    totalChunks: totalChunks,
                    chunkIndex: chunkIndex,
                    result: result
                )
            },
            clear: {
                await checkpointStore.delete(audioFileID: audioFileID)
            }
        )
    }

    static let live = FileBackedSTTCheckpointHooksProvider()
}
