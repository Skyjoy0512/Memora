import Foundation

public struct DependencyPermissionMatrix {
    public static let filesAgent: Set<String> = [
        "AudioFileRepository",
        "PipelineCoordinator",
        "STTStatus"
    ]
    public static let detailAgent: Set<String> = [
        "AudioFileRepository",
        "TranscriptRepository",
        "MeetingNoteRepository",
        "PipelineCoordinator",
        "LLMRouter"
    ]
    public static let workspaceAgent: Set<String> = [
        "ProjectRepository",
        "AudioFileRepository",
        "TodoItemRepository",
        "MeetingNoteRepository",
        "LLMRouter",
        "STTStatus"
    ]
    public static let forbidden: Set<String> = [
        "STTService",
        "ModelContext"
    ]
}

public protocol STTServiceProtocol: Sendable {
    func startTranscription(
        audioURL: URL,
        language: String?
    ) async throws -> (any STTTaskHandleProtocol, AsyncStream<STTEvent>)

    func getActiveTasks() -> [any STTTaskHandleProtocol]
    func cancelAllTasks() async
}

public protocol STTTaskHandleProtocol: Identifiable {
    var id: String { get }
    var taskId: String { get }
    var audioURL: URL { get }
    var language: String? { get }
    var isRunning: Bool { get }

    func cancel() async
}

public protocol STTReadinessProtocol: Sendable {
    var isReady: Bool { get async }
    var supportedLanguages: [String] { get async }
    var requiresDownload: Bool { get async }

    func prepare() async throws
}
