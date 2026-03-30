//
//  FeatureDependencySurface.swift
//  Memora
//
//  Core 契約: Feature 側の依存入口定義
//  TODO: TCA 追加後に依存注入を実装
//

import Foundation

// 依存マトリクス
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

// MARK: - STT 契約境界

/// STT 側から提供される Protocol
public protocol STTServiceProtocol: Sendable {
    /// 文字起こしタスク開始
    func startTranscription(
        audioURL: URL,
        language: String?
    ) async throws -> (any STTTaskHandleProtocol, AsyncStream<STTEvent>)

    /// アクティブタスク一覧
    func getActiveTasks() -> [any STTTaskHandleProtocol]

    /// 全てのタスクをキャンセル
    func cancelAllTasks() async
}

/// STT タスクハンドル Protocol
public protocol STTTaskHandleProtocol: Identifiable {
    var id: String { get }
    var taskId: String { get }
    var audioURL: URL { get }
    var language: String? { get }
    var isRunning: Bool { get }

    func cancel() async
}

/// STT 準備状態 Protocol
public protocol STTReadinessProtocol: Sendable {
    var isReady: Bool { get async }
    var supportedLanguages: [String] { get async }
    var requiresDownload: Bool { get async }

    func prepare() async throws
}
