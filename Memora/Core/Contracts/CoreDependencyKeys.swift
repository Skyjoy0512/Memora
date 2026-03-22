//
//  CoreDependencyKeys.swift
//  Memora
//
//  Core 契約: TCA DependencyKey 定義
//  Feature 側が依存する DI の入口
//

import ComposableArchitecture

// MARK: - Repository DependencyKeys

/// AudioFileRepository の DependencyKey
extension DependencyValues {
    public var audioFileRepository: AudioFileRepositoryProtocol {
        get { self[AudioFileRepositoryKey.self] }
        set { self[AudioFileRepositoryKey.self] = $0 }
    }
}

private enum AudioFileRepositoryKey: DependencyKey {
    static let liveValue: AudioFileRepositoryProtocol? = nil
    // Core/Persistence/AudioFileRepository.swift の実装をセットする
}

/// TranscriptRepository の DependencyKey
extension DependencyValues {
    public var transcriptRepository: TranscriptRepositoryProtocol {
        get { self[TranscriptRepositoryKey.self] }
        set { self[TranscriptRepositoryKey.self] = $0 }
    }
}

private enum TranscriptRepositoryKey: DependencyKey {
    static let liveValue: TranscriptRepositoryProtocol? = nil
    // Core/Persistence/TranscriptRepository.swift の実装をセットする
}

/// ProjectRepository の DependencyKey
extension DependencyValues {
    public var projectRepository: ProjectRepositoryProtocol {
        get { self[ProjectRepositoryKey.self] }
        set { self[ProjectRepositoryKey.self] = $0 }
    }
}

private enum ProjectRepositoryKey: DependencyKey {
    static let liveValue: ProjectRepositoryProtocol? = nil
    // Core/Persistence/ProjectRepository.swift の実装をセットする
}

/// TodoItemRepository の DependencyKey
extension DependencyValues {
    public var todoItemRepository: TodoItemRepositoryProtocol {
        get { self[TodoItemRepositoryKey.self] }
        set { self[TodoItemRepositoryKey.self] = $0 }
    }
}

private enum TodoItemRepositoryKey: DependencyKey {
    static let liveValue: TodoItemRepositoryProtocol? = nil
    // Core/Persistence/TodoItemRepository.swift の実装をセットする
}

/// MeetingNoteRepository の DependencyKey
extension DependencyValues {
    public var meetingNoteRepository: MeetingNoteRepositoryProtocol {
        get { self[MeetingNoteRepositoryKey.self] }
        set { self[MeetingNoteRepositoryKey.self] = $0 }
    }
}

private enum MeetingNoteRepositoryKey: DependencyKey {
    static let liveValue: MeetingNoteRepositoryProtocol? = nil
    // Core/Persistence/MeetingNoteRepository.swift の実装をセットする
}

/// ProcessingJobRepository の DependencyKey
extension DependencyValues {
    public var processingJobRepository: ProcessingJobRepositoryProtocol {
        get { self[ProcessingJobRepositoryKey.self] }
        set { self[ProcessingJobRepositoryKey.self] = $0 }
    }
}

private enum ProcessingJobRepositoryKey: DependencyKey {
    static let liveValue: ProcessingJobRepositoryProtocol? = nil
    // Core/Persistence/ProcessingJobRepository.swift の実装をセットする
}

// MARK: - Service DependencyKeys

/// PipelineCoordinator の DependencyKey
extension DependencyValues {
    public var pipelineCoordinator: PipelineCoordinatorProtocol {
        get { self[PipelineCoordinatorKey.self] }
        set { self[PipelineCoordinatorKey.self] = $0 }
    }
}

private enum PipelineCoordinatorKey: DependencyKey {
    static let liveValue: PipelineCoordinatorProtocol? = nil
    // Core/Services/PipelineCoordinator.swift の実装をセットする
}

/// LLMRouter の DependencyKey
extension DependencyValues {
    public var llmRouter: LLMRouterProtocol {
        get { self[LLMRouterKey.self] }
        set { self[LLMRouterKey.self] = $0 }
    }
}

private enum LLMRouterKey: DependencyKey {
    static let liveValue: LLMRouterProtocol? = nil
    // Core/Services/LLMRouter.swift の実装をセットする
}

/// STTService の DependencyKey（stt-agent が実装を提供）
extension DependencyValues {
    public var sttService: STTServiceProtocol {
        get { self[STTServiceKey.self] }
        set { self[STTServiceKey.self] = $0 }
    }
}

private enum STTServiceKey: DependencyKey {
    static let liveValue: STTServiceProtocol? = nil
    // stt-agent が提供する実装をセットする
}

/// STTReadiness の DependencyKey（stt-agent が実装を提供）
extension DependencyValues {
    public var sttReadiness: STTReadinessProtocol {
        get { self[STTReadinessKey.self] }
        set { self[STTReadinessKey.self] = $0 }
    }
}

private enum STTReadinessKey: DependencyKey {
    static let liveValue: STTReadinessProtocol? = nil
    // stt-agent が提供する実装をセットする
}

/// STTStatus の DependencyKey（Feature 側向けの整形されたステータス）
extension DependencyValues {
    public var sttStatus: STTStatusSurface {
        get { self[STTStatusKey.self] }
        set { self[STTStatusKey.self] = $0 }
    }
}

private enum STTStatusKey: DependencyKey {
    static let liveValue: STTStatusSurface = STTStatusSurfaceLive()
}

// MARK: - ModelContext DependencyKey

/// SwiftData ModelContext の DependencyKey
extension DependencyValues {
    public var modelContext: ModelContext? {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = $0 }
    }
}

private enum ModelContextKey: DependencyKey {
    static let liveValue: ModelContext? = nil
    // App エントリポイントでセットする
}

// MARK: - Preview Implementations

extension DependencyValues {
    /// Preview 用のダミー実装をセット
    public static func withPreviewValues() -> DependencyValues {
        var values = DependencyValues()

        values.audioFileRepository = PreviewAudioFileRepository()
        values.transcriptRepository = PreviewTranscriptRepository()
        values.projectRepository = PreviewProjectRepository()
        values.todoItemRepository = PreviewTodoItemRepository()
        values.meetingNoteRepository = PreviewMeetingNoteRepository()
        values.processingJobRepository = PreviewProcessingJobRepository()
        values.pipelineCoordinator = PreviewPipelineCoordinator()
        values.llmRouter = PreviewLLMRouter()
        values.sttService = PreviewSTTService()
        values.sttReadiness = PreviewSTTReadiness()
        values.sttStatus = PreviewSTTStatus()

        return values
    }
}

// MARK: - Preview Placeholders

private final class PreviewAudioFileRepository: AudioFileRepositoryProtocol {
    func fetchAll() async throws -> [AudioFile] { [] }
    func fetch(id: UUID) async throws -> AudioFile? { nil }
    func save(_ file: AudioFile) async throws {}
    func delete(_ file: AudioFile) async throws {}
    func fetchByProject(_ projectId: UUID) async throws -> [AudioFile] { [] }
}

private final class PreviewTranscriptRepository: TranscriptRepositoryProtocol {
    func fetch(audioFileId: UUID) async throws -> Transcript? { nil }
    func save(_ transcript: Transcript) async throws {}
    func delete(_ transcript: Transcript) async throws {}
}

private final class PreviewProjectRepository: ProjectRepositoryProtocol {
    func fetchAll() async throws -> [Project] { [] }
    func fetch(id: UUID) async throws -> Project? { nil }
    func save(_ project: Project) async throws {}
    func delete(_ project: Project) async throws {}
}

private final class PreviewTodoItemRepository: TodoItemRepositoryProtocol {
    func fetchAll() async throws -> [TodoItem] { [] }
    func fetch(projectId: UUID?) async throws -> [TodoItem] { [] }
    func save(_ todo: TodoItem) async throws {}
    func delete(_ todo: TodoItem) async throws {}
    func toggle(_ todo: TodoItem) async throws {}
}

private final class PreviewMeetingNoteRepository: MeetingNoteRepositoryProtocol {
    func fetch(audioFileId: UUID) async throws -> MeetingNote? { nil }
    func save(_ note: MeetingNote) async throws {}
    func delete(_ note: MeetingNote) async throws {}
    func fetchByProject(_ projectId: UUID) async throws -> [MeetingNote] { [] }
}

private final class PreviewProcessingJobRepository: ProcessingJobRepositoryProtocol {
    func fetch(audioFileId: UUID) async throws -> ProcessingJob? { nil }
    func save(_ job: ProcessingJob) async throws {}
    func delete(_ job: ProcessingJob) async throws {}
    func fetchAllActive() async throws -> [ProcessingJob] { [] }
}

private final class PreviewPipelineCoordinator: PipelineCoordinatorProtocol {
    func execute(fileId: UUID, template: MeetingNoteTemplate, model: String) -> AsyncStream<PipelineEvent> {
        AsyncStream { continuation in
            continuation.yield(.completed)
            continuation.finish()
        }
    }
    func cancelJob(fileId: UUID) async throws {}
}

private final class PreviewLLMRouter: LLMRouterProtocol {
    func summarize(transcript: String, template: MeetingNoteTemplate, model: String) async throws -> SummarizationResult {
        SummarizationResult(summary: "Preview summary", decisions: [], actionItems: [])
    }
    func extractTodos(transcript: String, existingTodos: [TodoItem]) async throws -> [TodoExtractionResult] { [] }
    func chat(scope: ChatScope, model: String, messages: [ChatMessage]) async throws -> String { "Preview response" }
}

private final class PreviewSTTService: STTServiceProtocol {
    func startTranscription(audioURL: URL, language: String?) async throws -> (STTTaskHandleProtocol, AsyncStream<STTEvent>) {
        (PreviewSTTTaskHandle(), AsyncStream { _ in })
    }
    func getActiveTasks() -> [STTTaskHandleProtocol] { [] }
    func cancelAllTasks() async {}
}

private final class PreviewSTTTaskHandle: STTTaskHandleProtocol {
    var id: String { "preview-task" }
    var taskId: String { "preview-task" }
    var audioURL: URL { URL(fileURLWithPath: "") }
    var language: String? { nil }
    var isRunning: Bool { false }
    func cancel() async {}
}

private final class PreviewSTTReadiness: STTReadinessProtocol {
    var isReady: Bool { get async { true } }
    var supportedLanguages: [String] { get async { ["ja", "en"] } }
    var requiresDownload: Bool { get async { false } }
    func prepare() async throws {}
}

private final class PreviewSTTStatus: STTStatusSurface {
    var isReady: Bool { true }
    var supportedLanguages: [String] { ["ja", "en"] }
    var requiresDownload: Bool { false }
    func prepare() async throws {}
}

// MARK: - 実装のセットアップ

/// Core 側の実装を Dependency に登録するためのセットアップ関数
public final class CoreDependencySetup {
    /// Repository 実装を登録
    public static func registerRepositories(
        audioFileRepository: AudioFileRepositoryProtocol,
        transcriptRepository: TranscriptRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        todoItemRepository: TodoItemRepositoryProtocol,
        meetingNoteRepository: MeetingNoteRepositoryProtocol,
        processingJobRepository: ProcessingJobRepositoryProtocol
    ) {
        @Dependency(\.audioFileRepository) var $audioFileRepo
        @Dependency(\.transcriptRepository) var $transcriptRepo
        @Dependency(\.projectRepository) var $projectRepo
        @Dependency(\.todoItemRepository) var $todoRepo
        @Dependency(\.meetingNoteRepository) var $meetingNoteRepo
        @Dependency(\.processingJobRepository) var $jobRepo

        $audioFileRepo = audioFileRepository
        $transcriptRepo = transcriptRepository
        $projectRepo = projectRepository
        $todoRepo = todoItemRepository
        $meetingNoteRepo = meetingNoteRepository
        $jobRepo = processingJobRepository
    }

    /// Service 実装を登録
    public static func registerServices(
        pipelineCoordinator: PipelineCoordinatorProtocol,
        llmRouter: LLMRouterProtocol
    ) {
        @Dependency(\.pipelineCoordinator) var $pipeline
        @Dependency(\.llmRouter) var $llm

        $pipeline = pipelineCoordinator
        $llm = llmRouter
    }

    /// STT 実装を登録（stt-agent が呼び出す）
    public static func registerSTT(
        sttService: STTServiceProtocol,
        sttReadiness: STTReadinessProtocol
    ) {
        @Dependency(\.sttService) var $service
        @Dependency(\.sttReadiness) var $readiness

        $service = sttService
        $readiness = sttReadiness
    }
}

// MARK: - App エントリポイントでの使用例

/*
 MemoraApp.swift でのセットアップ例:

 let audioFileRepo = AudioFileRepository(context: modelContainer.mainContext)
 let transcriptRepo = TranscriptRepository(context: modelContainer.mainContext)
 // ... 他の Repository

 let pipelineCoord = PipelineCoordinator(
     audioFileRepository: audioFileRepo,
     transcriptRepository: transcriptRepo,
     // ... 他の依存
 )

 // Reducer ストアに登録
 RootView()
     .store(
         store: store(
             state: \RootState.self,
             reducer: rootReducer
         ) { dependencies in
             CoreDependencySetup.registerRepositories(
                 audioFileRepository: audioFileRepo,
                 transcriptRepository: transcriptRepo,
                 // ...
             )
             CoreDependencySetup.registerServices(
                 pipelineCoordinator: pipelineCoord,
                 llmRouter: llmRouter
             )
         }
     )
*/
