//
//  CoreDTOs.swift
//  Memora
//
//  Core 契約: DTO 定義
//  Core と Feature 間のデータ転送に使用する構造体
//

import Foundation

// MARK: - Pipeline Event DTO

/// パイプライン処理の進捗イベント
public enum PipelineEvent: Sendable {
    case stepStarted(PipelineStep)
    case stepCompleted(PipelineStep)
    case chunkProgress(current: Int, total: Int)
    case completed
    case failed(step: PipelineStep, error: CoreError)
}

/// パイプライン処理のステップ
public enum PipelineStep: String, Equatable, Hashable, Sendable, CaseIterable {
    case none = "none"
    case loadingAudio = "loading_audio"
    case chunking = "chunking"
    case transcribing = "transcribing"
    case mergingTranscripts = "merging_transcripts"
    case extractingMetadata = "extracting_metadata"
    case generatingSummary = "generating_summary"
    case extractingTodos = "extracting_todos"
    case finalizing = "finalizing"
}

// MARK: - Summarization DTO

/// サマリー生成結果
public struct SummarizationResult: Sendable, Equatable {
    public let summary: String
    public let decisions: [String]
    public let actionItems: [String]

    public init(summary: String, decisions: [String], actionItems: [String]) {
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
    }
}

// MARK: - Todo Extraction DTO

/// ToDo 抽出結果
public struct TodoExtractionResult: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let notes: String?
    public let assignee: String?
    public let speaker: String?
    public let priority: TodoPriority
    public let dueDate: Date?
    public let relativeDueDate: RelativeDueDate?

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        assignee: String? = nil,
        speaker: String? = nil,
        priority: TodoPriority = .medium,
        dueDate: Date? = nil,
        relativeDueDate: RelativeDueDate? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.assignee = assignee
        self.speaker = speaker
        self.priority = priority
        self.dueDate = dueDate
        self.relativeDueDate = relativeDueDate
    }
}

/// ToDo 優先度
public enum TodoPriority: String, Equatable, Hashable, Sendable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

/// 相対期限
public enum RelativeDueDate: String, Equatable, Hashable, Sendable, CaseIterable {
    case tomorrow = "tomorrow"
    case nextWeek = "next_week"
    case nextMonth = "next_month"
    case asap = "asap"
}

// MARK: - Chat DTO

/// チャットスコープ
public enum ChatScope: Equatable, Hashable, Sendable {
    case file(fileId: UUID)
    case project(projectId: UUID)
    case global
}

/// チャットメッセージ
public struct ChatMessage: Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let role: ChatRole
    public let content: String

    public init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// チャットロール
public enum ChatRole: String, Equatable, Hashable, Sendable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - STT Event DTO

/// STT 処理イベント
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

// MARK: - Transcription DTO

/// 文字起こし結果
public struct TranscriptionResult: Sendable {
    public let fullText: String
    public let language: String
    public let segments: [TranscriptionSegment]

    public init(fullText: String, language: String = "ja", segments: [TranscriptionSegment] = []) {
        self.fullText = fullText
        self.language = language
        self.segments = segments
    }
}

/// 文字起こしセグメント
public struct TranscriptionSegment: Sendable, Identifiable, Equatable {
    public let id: String
    public let speakerLabel: String
    public let startSec: Double
    public let endSec: Double
    public let text: String

    public init(id: String, speakerLabel: String, startSec: Double, endSec: Double, text: String) {
        self.id = id
        self.speakerLabel = speakerLabel
        self.startSec = startSec
        self.endSec = endSec
        self.text = text
    }
}

// MARK: - Meeting Note Template DTO

/// 議事録テンプレート種別
public enum MeetingNoteTemplate: String, Equatable, Hashable, Sendable, CaseIterable {
    case standard = "standard"
    case engineering = "engineering"
    case sales = "sales"
    case oneOnOne = "one_on_one"
    case brainstorming = "brainstorming"
    case decision = "decision"
}
