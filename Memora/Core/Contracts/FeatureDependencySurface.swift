//
//  FeatureDependencySurface.swift
//  Memora
//
//  Core 契約: Feature 側の依存入口定義
//  各エージェントが依存してよい Core 契約を明示
//

import ComposableArchitecture

// MARK: - Feature 契約境界

/// files-agent が依存してよい Core 契約
public enum FilesAgentDependencies {
    /// AudioFile へのアクセス
    public static var audioFileRepository: AudioFileRepositoryProtocol {
        @Dependency(\.audioFileRepository) var repository
        return repository
    }

    /// パイプラインコーディネーター
    public static var pipelineCoordinator: PipelineCoordinatorProtocol {
        @Dependency(\.pipelineCoordinator) var coordinator
        return coordinator
    }

    /// STT ステータス（準備状態表示用）
    public static var sttStatus: STTStatusSurface {
        @Dependency(\.sttStatus) var status
        return status
    }
}

/// detail-agent が依存してよい Core 契約
public enum DetailAgentDependencies {
    /// AudioFile へのアクセス
    public static var audioFileRepository: AudioFileRepositoryProtocol {
        @Dependency(\.audioFileRepository) var repository
        return repository
    }

    /// Transcript へのアクセス
    public static var transcriptRepository: TranscriptRepositoryProtocol {
        @Dependency(\.transcriptRepository) var repository
        return repository
    }

    /// MeetingNote へのアクセス
    public static var meetingNoteRepository: MeetingNoteRepositoryProtocol {
        @Dependency(\.meetingNoteRepository) var repository
        return repository
    }

    /// パイプラインコーディネーター
    public static var pipelineCoordinator: PipelineCoordinatorProtocol {
        @Dependency(\.pipelineCoordinator) var coordinator
        return coordinator
    }

    /// LLM ルーター（チャット機能）
    public static var llmRouter: LLMRouterProtocol {
        @Dependency(\.llmRouter) var router
        return router
    }
}

/// workspace-agent が依存してよい Core 契約
public enum WorkspaceAgentDependencies {
    // MARK: - Projects

    /// Project へのアクセス
    public static var projectRepository: ProjectRepositoryProtocol {
        @Dependency(\.projectRepository) var repository
        return repository
    }

    /// Project 内の AudioFile へのアクセス
    public static var audioFileRepository: AudioFileRepositoryProtocol {
        @Dependency(\.audioFileRepository) var repository
        return repository
    }

    // MARK: - Todo

    /// TodoItem へのアクセス
    public static var todoItemRepository: TodoItemRepositoryProtocol {
        @Dependency(\.todoItemRepository) var repository
        return repository
    }

    /// MeetingNote へのアクセス（ToDo 抽出結果確認用）
    public static var meetingNoteRepository: MeetingNoteRepositoryProtocol {
        @Dependency(\.meetingNoteRepository) var repository
        return repository
    }

    // MARK: - AskAI

    /// LLM ルーター（チャット機能）
    public static var llmRouter: LLMRouterProtocol {
        @Dependency(\.llmRouter) var router
        return router
    }

    // MARK: - Settings

    /// LLM ルーター（設定確認・更新用）
    public static var llmRouter: LLMRouterProtocol {
        @Dependency(\.llmRouter) var router
        return router
    }

    /// STT ステータス（設定表示用）
    public static var sttStatus: STTStatusSurface {
        @Dependency(\.sttStatus) var status
        return status
    }
}

// MARK: - 依存許可マトリクス

/// 各エージェントが依存してよい Core 契約の一覧表
public struct DependencyPermissionMatrix {
    /// files-agent の依存許可リスト
    public static let filesAgent: Set<String> = [
        "AudioFileRepository",
        "PipelineCoordinator",
        "STTStatus"
    ]

    /// detail-agent の依存許可リスト
    public static let detailAgent: Set<String> = [
        "AudioFileRepository",
        "TranscriptRepository",
        "MeetingNoteRepository",
        "PipelineCoordinator",
        "LLMRouter"
    ]

    /// workspace-agent の依存許可リスト
    public static let workspaceAgent: Set<String> = [
        "ProjectRepository",
        "AudioFileRepository",
        "TodoItemRepository",
        "MeetingNoteRepository",
        "LLMRouter",
        "STTStatus"
    ]

    /// 全エージェントで依存禁止
    public static let forbidden: Set<String> = [
        // STT 内部実装は stt-agent のみが使用
        "STTService",
        // ModelContext は Repository 内部でのみ使用
        "ModelContext"
    ]
}

// MARK: - STT 契約境界

/// Core 側が stt-agent に要求する契約
public enum STTCoreDependencies {
    /// STT サービス
    public static var sttService: STTServiceProtocol {
        @Dependency(\.sttService) var service
        return service
    }

    /// STT 準備状態
    public static var sttReadiness: STTReadinessProtocol {
        @Dependency(\.sttReadiness) var readiness
        return readiness
    }
}

/// stt-agent が Core に対して提供すべき実装
public protocol STTAgentProvided {
    var sttService: STTServiceProtocol { get }
    var sttReadiness: STTReadinessProtocol { get }
}

/// Core 側が stt-agent に対して使用する入口
public struct STTCollaborationSurface {
    /// 文字起こしタスク開始
    public static func startTranscription(
        audioURL: URL,
        language: String?
    ) async throws -> (STTTaskHandleProtocol, AsyncStream<STTEvent>) {
        try await STTCoreDependencies.sttService.startTranscription(
            audioURL: audioURL,
            language: language
        )
    }

    /// アクティブタスク一覧
    public static func getActiveTasks() -> [STTTaskHandleProtocol] {
        STTCoreDependencies.sttService.getActiveTasks()
    }

    /// 全タスクキャンセル
    public static func cancelAllTasks() async {
        await STTCoreDependencies.sttService.cancelAllTasks()
    }

    /// STT 準備状態
    public static var isReady: Bool {
        get async { await STTCoreDependencies.sttReadiness.isReady }
    }

    /// 対応言語一覧
    public static var supportedLanguages: [String] {
        get async { await STTCoreDependencies.sttReadiness.supportedLanguages }
    }

    /// ダウンロードが必要か
    public static var requiresDownload: Bool {
        get async { await STTCoreDependencies.sttReadiness.requiresDownload }
    }

    /// STT 準備
    public static func prepare() async throws {
        try await STTCoreDependencies.sttReadiness.prepare()
    }
}

// MARK: - STT Event DTO

/// STT から通知されるイベント
public enum STTEvent: Sendable {
    case transcriptionStarted(taskId: String)
    case transcriptionProgress(taskId: String, progress: Double)
    case transcriptionPartialResult(taskId: String, text: String)
    case transcriptionCompleted(taskId: String, result: TranscriptionResult)
    case transcriptionFailed(taskId: String, error: CoreError)
    case transcriptionCancelled(taskId: String)
    case audioChunkStarted(chunkIndex: Int)
    case audioChunkProgress(chunkIndex: Int, progress: Double)
    case audioChunkCompleted(chunkIndex: Int, result: TranscriptionResult)
}

// MARK: - STT Status Surface

/// Feature 側が使用する STT ステータス（STTReadiness のラッパー）
public protocol STTStatusSurface: Sendable {
    /// STT が使用可能か
    var isReady: Bool { get }

    /// 対応している言語コード一覧（例: ["ja", "en"]）
    var supportedLanguages: [String] { get }

    /// モデルのダウンロードが必要か
    var requiresDownload: Bool { get }

    /// STT を準備する（必要に応じてモデルをダウンロード）
    func prepare() async throws
}

/// STTStatusSurface の Live 実装（STTReadiness をラップ）
public final class STTStatusSurfaceLive: STTStatusSurface {
    @Dependency(\.sttReadiness) var sttReadiness

    public var isReady: Bool {
        get async { await sttReadiness.isReady }
    }

    public var supportedLanguages: [String] {
        get async { await sttReadiness.supportedLanguages }
    }

    public var requiresDownload: Bool {
        get async { await sttReadiness.requiresDownload }
    }

    public func prepare() async throws {
        try await sttReadiness.prepare()
    }
}
