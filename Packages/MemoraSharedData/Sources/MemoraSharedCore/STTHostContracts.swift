import Foundation

public enum STTLogLevel: Sendable { case debug, info, warning, error }

public protocol STTLogging: Sendable {
    func log(_ category: String, _ message: String, level: STTLogLevel)
}

public protocol STTConsoleLogging: Sendable {
    func logDetailed(_ message: @autoclosure () -> String)
}

public protocol STTSettingsProviding: Sendable {
    var isSpeechAnalyzerEnabled: Bool { get }
    var isSpeakerDiarizationEnabled: Bool { get }
    var contextualVocabulary: [String] { get }
}

public struct STTReadOnlyHostDependencies: Sendable {
    public let logger: any STTLogging
    public let consoleLogger: any STTConsoleLogging
    public let settings: any STTSettingsProviding
    public init(logger: any STTLogging, consoleLogger: any STTConsoleLogging, settings: any STTSettingsProviding) {
        self.logger = logger; self.consoleLogger = consoleLogger; self.settings = settings
    }
}

public struct STTBackgroundTaskToken: Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue } }
public protocol STTBackgroundTaskManaging: Sendable { @MainActor func beginBackgroundTask(named name: String, expirationHandler: @escaping @Sendable () -> Void) -> STTBackgroundTaskToken?; @MainActor func endBackgroundTask(_ token: STTBackgroundTaskToken) }
public protocol STTIdleTimerManaging: Sendable { @MainActor func setIdleTimerDisabled(_ isDisabled: Bool) }
public protocol STTMemoryWarningObserving: Sendable { func observeMemoryWarnings(_ handler: @escaping @Sendable () -> Void) }
public struct STTExecutionHostCapabilities: Sendable {
    public let backgroundTasks: any STTBackgroundTaskManaging; public let idleTimer: any STTIdleTimerManaging; public let memoryWarnings: any STTMemoryWarningObserving
    public init(backgroundTasks: any STTBackgroundTaskManaging, idleTimer: any STTIdleTimerManaging, memoryWarnings: any STTMemoryWarningObserving) { self.backgroundTasks = backgroundTasks; self.idleTimer = idleTimer; self.memoryWarnings = memoryWarnings }
}
public protocol STTCheckpointHooksProviding: Sendable { func makeHooks(audioFileID: UUID) -> STTCheckpointHooks }
