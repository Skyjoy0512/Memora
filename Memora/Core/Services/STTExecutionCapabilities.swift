import Foundation

// 共有可能な STT 実行capabilityの契約。UIKitの実装はホスト側に置く。
struct STTBackgroundTaskToken: Sendable {
    let rawValue: Int
}

protocol STTBackgroundTaskManaging: Sendable {
    @MainActor
    func beginBackgroundTask(
        named name: String,
        expirationHandler: @escaping @Sendable () -> Void
    ) -> STTBackgroundTaskToken?

    @MainActor
    func endBackgroundTask(_ token: STTBackgroundTaskToken)
}

protocol STTIdleTimerManaging: Sendable {
    @MainActor
    func setIdleTimerDisabled(_ isDisabled: Bool)
}

protocol STTMemoryWarningObserving: Sendable {
    func observeMemoryWarnings(_ handler: @escaping @Sendable () -> Void)
}

struct STTExecutionHostCapabilities: Sendable {
    let backgroundTasks: any STTBackgroundTaskManaging
    let idleTimer: any STTIdleTimerManaging
    let memoryWarnings: any STTMemoryWarningObserving
}

protocol STTCheckpointHooksProviding: Sendable {
    func makeHooks(audioFileID: UUID) -> STTCheckpointHooks
}
