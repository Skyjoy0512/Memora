//
//  CoreProtocols.swift
//  Memora
//
//  Core 契約: Protocol 定義
//  Core 側が提供する interface
//

import Foundation
import SwiftData

// MARK: - Repository Protocols

/// AudioFile へのアクセスを提供する Protocol
public protocol AudioFileRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [AudioFile]
    func fetch(id: UUID) async throws -> AudioFile?
    func save(_ file: AudioFile) async throws
    func delete(_ file: AudioFile) async throws
    func fetchByProject(_ projectId: UUID) async throws -> [AudioFile]
}

/// Transcript へのアクセスを提供する Protocol
public protocol TranscriptRepositoryProtocol: Sendable {
    func fetch(audioFileId: UUID) async throws -> Transcript?
    func save(_ transcript: Transcript) async throws
    func delete(_ transcript: Transcript) async throws
}

/// Project へのアクセスを提供する Protocol
public protocol ProjectRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Project]
    func fetch(id: UUID) async throws -> Project?
    func save(_ project: Project) async throws
    func delete(_ project: Project) async throws
}

/// TodoItem へのアクセスを提供する Protocol
public protocol TodoItemRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [TodoItem]
    func fetch(projectId: UUID?) async throws -> [TodoItem]
    func save(_ todo: TodoItem) async throws
    func delete(_ todo: TodoItem) async throws
    func toggle(_ todo: TodoItem) async throws
}

/// MeetingNote へのアクセスを提供する Protocol
public protocol MeetingNoteRepositoryProtocol: Sendable {
    func fetch(audioFileId: UUID) async throws -> MeetingNote?
    func save(_ note: MeetingNote) async throws
    func delete(_ note: MeetingNote) async throws
    func fetchByProject(_ projectId: UUID) async throws -> [MeetingNote]
}

/// ProcessingJob へのアクセスを提供する Protocol
public protocol ProcessingJobRepositoryProtocol: Sendable {
    func fetch(audioFileId: UUID) async throws -> ProcessingJob?
    func save(_ job: ProcessingJob) async throws
    func delete(_ job: ProcessingJob) async throws
    func fetchAllActive() async throws -> [ProcessingJob]
}

// MARK: - Service Protocols

/// パイプラインコーディネーター Protocol
/// UI が STT の詳細を知らずに処理を実行するための唯一の入口
public protocol PipelineCoordinatorProtocol: Sendable {
    /// パイプライン処理を実行
    /// - Parameters:
    ///   - fileId: 処理対象の音声ファイル ID
    ///   - template: 議事録テンプレート
    ///   - model: 使用する LLM モデル
    /// - Returns: 進捗イベントを通知する AsyncStream
    func execute(
        fileId: UUID,
        template: MeetingNoteTemplate,
        model: String
    ) -> AsyncStream<PipelineEvent>

    /// パイプライン処理をキャンセル
    /// - Parameter fileId: 処理対象の音声ファイル ID
    func cancelJob(fileId: UUID) async throws
}

/// LLM ルーター Protocol
/// LLM API 呼び出しを抽象化
public protocol LLMRouterProtocol: Sendable {
    /// サマリーを生成
    /// - Parameters:
    ///   - transcript: 文字起こしテキスト
    ///   - template: 議事録テンプレート
    ///   - model: 使用する LLM モデル
    /// - Returns: サマリー結果
    func summarize(
        transcript: String,
        template: MeetingNoteTemplate,
        model: String
    ) async throws -> SummarizationResult

    /// ToDo を抽出
    /// - Parameters:
    ///   - transcript: 文字起こしテキスト
    ///   - existingTodos: 既存の ToDo リスト
    /// - Returns: 抽出された ToDo リスト
    func extractTodos(
        transcript: String,
        existingTodos: [TodoItem]
    ) async throws -> [TodoExtractionResult]

    /// チャット
    /// - Parameters:
    ///   - scope: チャットスコープ
    ///   - model: 使用する LLM モデル
    ///   - messages: チャットメッセージ履歴
    /// - Returns: AI の応答
    func chat(
        scope: ChatScope,
        model: String,
        messages: [ChatMessage]
    ) async throws -> String
}

// MARK: - STT Boundary Protocol

/// STT 側から提供される Protocol（stt-agent 責務）
/// Core はこの Protocol を通じて STT 機能を使用する
public protocol STTServiceProtocol: Sendable {
    /// 文字起こしタスクを開始
    /// - Parameters:
    ///   - audioURL: 音声ファイル URL
    ///   - language: 言語コード（nil で自動検出）
    /// - Returns: タスクハンドルと進捗イベント
    func startTranscription(
        audioURL: URL,
        language: String?
    ) async throws -> (STTTaskHandleProtocol, AsyncStream<STTEvent>)

    /// アクティブなタスクの一覧を取得
    func getActiveTasks() -> [STTTaskHandleProtocol]

    /// 全てのタスクをキャンセル
    func cancelAllTasks() async
}

/// STT タスクハンドル Protocol（stt-agent 責務）
public protocol STTTaskHandleProtocol: Identifiable, Sendable {
    var id: String { get }
    var taskId: String { get }
    var audioURL: URL { get }
    var language: String? { get }
    var isRunning: Bool { get }

    func cancel() async
}

/// STT 準備状態 Protocol（stt-agent 責務）
public protocol STTReadinessProtocol: Sendable {
    var isReady: Bool { get async }
    var supportedLanguages: [String] { get async }
    var requiresDownload: Bool { get async }

    func prepare() async throws
}
