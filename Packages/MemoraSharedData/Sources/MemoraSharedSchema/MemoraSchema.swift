import SwiftData
import Foundation

// MARK: - Versioned Schema

/// Memora のスキーマバージョン定義。
/// スキーマ変更時は新しい VersionedSchema を追加し、
/// MemoraMigrationPlan の stages にマイグレーションを追加すること。
public enum MemoraSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    public static let models: [any PersistentModel.Type] = [
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        KnowledgeChunk.self,
        AskAISession.self,
        AskAIMessage.self,
        MemoryProfile.self,
        MemoryFact.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self,
        CalendarEventLink.self,
        GoogleMeetSettings.self,
        NotionSettings.self,
        CustomSummaryTemplate.self
    ]
}

// MARK: - Schema V2 (PR-C1)

/// V2: TranscriptionCheckpoint を追加。
public enum MemoraSchemaV2: VersionedSchema {
    public static var versionIdentifier = Schema.Version(2, 0, 0)

    public static let models: [any PersistentModel.Type] = [
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        KnowledgeChunk.self,
        AskAISession.self,
        AskAIMessage.self,
        MemoryProfile.self,
        MemoryFact.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self,
        CalendarEventLink.self,
        GoogleMeetSettings.self,
        NotionSettings.self,
        CustomSummaryTemplate.self,
        TranscriptionCheckpoint.self
    ]
}

// MARK: - Schema V3

/// V3: オンライン会議キャプチャ関連モデルを正式にVersionedSchemaへ登録。
/// TranscriptionCheckpoint は再生成可能な中間データのため、V3以降は本体DBから外す。
public enum MemoraSchemaV3: VersionedSchema {
    public static var versionIdentifier = Schema.Version(3, 0, 0)

    public static let models: [any PersistentModel.Type] = [
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        KnowledgeChunk.self,
        AskAISession.self,
        AskAIMessage.self,
        MemoryProfile.self,
        MemoryFact.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self,
        CalendarEventLink.self,
        GoogleMeetSettings.self,
        NotionSettings.self,
        CustomSummaryTemplate.self,
        OnlineMeetingCapture.self,
        BotMeetingConfig.self,
        ScheduledBotMeeting.self
    ]

    /// V3 リリース時の `AudioFile` 関係グラフの固定スナップショット。
    /// `segmentPaths` は V4 で初めて追加されたため、ここには含めない。
    @Model
    public final class AudioFile {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var duration: TimeInterval
        public var audioURL: String
        public var isTranscribed: Bool = false
        public var projectID: UUID?
        public var isSummarized: Bool = false
        public var summary: String?
        public var keyPoints: String?
        public var actionItems: String?
        public var isLifeLog: Bool = false
        public var lifeLogTags: [String] = []
        public var calendarEventId: String?
        public var sourceTypeRaw: String = SourceType.recording.rawValue
        public var referenceTranscript: String?
        public var referenceSpeakerCount: Int?

        @Relationship(deleteRule: .cascade, inverse: \Transcript.audioFile)
        public var transcripts: [Transcript] = []
        @Relationship(deleteRule: .cascade, inverse: \ProcessingJob.audioFile)
        public var processingJobs: [ProcessingJob] = []
        @Relationship(deleteRule: .cascade, inverse: \PhotoAttachment.audioFile)
        public var photoAttachments: [PhotoAttachment] = []
        @Relationship(deleteRule: .cascade, inverse: \KnowledgeChunk.audioFile)
        public var knowledgeChunks: [KnowledgeChunk] = []
        @Relationship(deleteRule: .cascade, inverse: \CalendarEventLink.audioFile)
        public var calendarEventLinks: [CalendarEventLink] = []

        public init(title: String, audioURL: String, projectID: UUID? = nil) {
            self.id = UUID()
            self.title = title
            self.createdAt = Date()
            self.duration = 0
            self.audioURL = audioURL
            self.projectID = projectID
        }
    }

    @Model
    public final class Transcript {
        public var id: UUID
        public var audioFileID: UUID
        public var audioFile: AudioFile?
        public var text: String
        public var createdAt: Date
        public var speakerLabels: [String] = []
        public var segmentStartTimes: [Double] = []
        public var segmentEndTimes: [Double] = []
        public var segmentTexts: [String] = []

        public init(audioFileID: UUID, text: String) {
            self.id = UUID()
            self.audioFileID = audioFileID
            self.audioFile = nil
            self.text = text
            self.createdAt = Date()
        }
    }

    @Model
    public final class ProcessingJob {
        public var id: UUID
        public var audioFileID: UUID
        public var audioFile: AudioFile?
        public var jobType: String
        public var status: String
        public var progress: Double = 0
        public var error: String?
        public var startedAt: Date?
        public var completedAt: Date?
        public var stage: String
        public var retryCount: Int = 0
        public var maxRetries: Int = 1
        public var createdAt: Date

        public init(audioFileID: UUID, jobType: String) {
            self.id = UUID()
            self.audioFileID = audioFileID
            self.audioFile = nil
            self.jobType = jobType
            self.status = "pending"
            self.stage = "none"
            self.createdAt = Date()
        }
    }

    @Model
    public final class PhotoAttachment {
        public var id: UUID
        public var ownerTypeRaw: String
        public var ownerID: UUID
        public var audioFile: AudioFile?
        public var sortOrder: Int
        public var localPath: String
        public var thumbnailPath: String?
        public var caption: String?
        public var ocrText: String?
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: UUID = UUID(), ownerType: PhotoAttachmentOwnerType, ownerID: UUID, sortOrder: Int = 0, localPath: String, thumbnailPath: String? = nil, caption: String? = nil, ocrText: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
            self.id = id
            self.ownerTypeRaw = ownerType.rawValue
            self.ownerID = ownerID
            self.audioFile = nil
            self.sortOrder = sortOrder
            self.localPath = localPath
            self.thumbnailPath = thumbnailPath
            self.caption = caption
            self.ocrText = ocrText
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class KnowledgeChunk {
        public var id: UUID
        public var scopeTypeRaw: String
        public var scopeID: UUID?
        public var sourceTypeRaw: String
        public var sourceID: UUID?
        public var audioFile: AudioFile?
        public var text: String
        public var keywords: [String]
        public var rankHint: Double
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: UUID = UUID(), scopeType: KnowledgeChunkScopeType, scopeID: UUID? = nil, sourceType: KnowledgeChunkSourceType, sourceID: UUID? = nil, text: String, keywords: [String] = [], rankHint: Double = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
            self.id = id
            self.scopeTypeRaw = scopeType.rawValue
            self.scopeID = scopeID
            self.sourceTypeRaw = sourceType.rawValue
            self.sourceID = sourceID
            self.audioFile = nil
            self.text = text
            self.keywords = keywords
            self.rankHint = rankHint
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class CalendarEventLink {
        public var id: UUID
        public var provider: String
        public var externalID: String
        public var audioFile: AudioFile?
        public var title: String
        public var startAt: Date
        public var endAt: Date
        public var meetingURL: String?
        public var conferenceProvider: String?
        public var audioFileID: UUID?
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: UUID = UUID(), provider: String, externalID: String, title: String, startAt: Date, endAt: Date, meetingURL: String? = nil, conferenceProvider: String? = nil, audioFileID: UUID? = nil) {
            self.id = id
            self.provider = provider
            self.externalID = externalID
            self.audioFile = nil
            self.title = title
            self.startAt = startAt
            self.endAt = endAt
            self.meetingURL = meetingURL
            self.conferenceProvider = conferenceProvider
            self.audioFileID = audioFileID
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
}

public enum MemoraSchemaV4: VersionedSchema {
    public static var versionIdentifier = Schema.Version(4, 0, 0)

    public static let models: [any PersistentModel.Type] = [
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        KnowledgeChunk.self,
        AskAISession.self,
        AskAIMessage.self,
        MemoryProfile.self,
        MemoryFact.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self,
        CalendarEventLink.self,
        GoogleMeetSettings.self,
        NotionSettings.self,
        CustomSummaryTemplate.self,
        OnlineMeetingCapture.self,
        BotMeetingConfig.self,
        ScheduledBotMeeting.self
    ]

    /// V4 リリース時の `AudioFile` 関係グラフの固定スナップショット。
    /// `cleanedText` は V5 で初めて追加されるため、Transcript には含めない。
    @Model
    public final class AudioFile {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var duration: TimeInterval
        public var audioURL: String
        public var segmentPaths: [String] = []
        public var isTranscribed: Bool = false
        public var projectID: UUID?
        public var isSummarized: Bool = false
        public var summary: String?
        public var keyPoints: String?
        public var actionItems: String?
        public var isLifeLog: Bool = false
        public var lifeLogTags: [String] = []
        public var calendarEventId: String?
        public var sourceTypeRaw: String = SourceType.recording.rawValue
        public var referenceTranscript: String?
        public var referenceSpeakerCount: Int?

        @Relationship(deleteRule: .cascade, inverse: \Transcript.audioFile)
        public var transcripts: [Transcript] = []
        @Relationship(deleteRule: .cascade, inverse: \ProcessingJob.audioFile)
        public var processingJobs: [ProcessingJob] = []
        @Relationship(deleteRule: .cascade, inverse: \PhotoAttachment.audioFile)
        public var photoAttachments: [PhotoAttachment] = []
        @Relationship(deleteRule: .cascade, inverse: \KnowledgeChunk.audioFile)
        public var knowledgeChunks: [KnowledgeChunk] = []
        @Relationship(deleteRule: .cascade, inverse: \CalendarEventLink.audioFile)
        public var calendarEventLinks: [CalendarEventLink] = []

        public init(title: String, audioURL: String, projectID: UUID? = nil) {
            self.id = UUID()
            self.title = title
            self.createdAt = Date()
            self.duration = 0
            self.audioURL = audioURL
            self.projectID = projectID
        }
    }

    @Model
    public final class Transcript {
        public var id: UUID
        public var audioFileID: UUID
        public var audioFile: AudioFile?
        public var text: String
        public var createdAt: Date
        public var speakerLabels: [String] = []
        public var segmentStartTimes: [Double] = []
        public var segmentEndTimes: [Double] = []
        public var segmentTexts: [String] = []

        public init(audioFileID: UUID, text: String) {
            self.id = UUID()
            self.audioFileID = audioFileID
            self.audioFile = nil
            self.text = text
            self.createdAt = Date()
        }
    }

    @Model
    public final class ProcessingJob {
        public var id: UUID
        public var audioFileID: UUID
        public var audioFile: AudioFile?
        public var jobType: String
        public var status: String
        public var progress: Double = 0
        public var error: String?
        public var startedAt: Date?
        public var completedAt: Date?
        public var stage: String
        public var retryCount: Int = 0
        public var maxRetries: Int = 1
        public var createdAt: Date

        public init(audioFileID: UUID, jobType: String) {
            self.id = UUID()
            self.audioFileID = audioFileID
            self.audioFile = nil
            self.jobType = jobType
            self.status = "pending"
            self.stage = "none"
            self.createdAt = Date()
        }
    }

    @Model
    public final class PhotoAttachment {
        public var id: UUID
        public var ownerTypeRaw: String
        public var ownerID: UUID
        public var audioFile: AudioFile?
        public var sortOrder: Int
        public var localPath: String
        public var thumbnailPath: String?
        public var caption: String?
        public var ocrText: String?
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: UUID = UUID(), ownerType: PhotoAttachmentOwnerType, ownerID: UUID, sortOrder: Int = 0, localPath: String, thumbnailPath: String? = nil, caption: String? = nil, ocrText: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
            self.id = id
            self.ownerTypeRaw = ownerType.rawValue
            self.ownerID = ownerID
            self.audioFile = nil
            self.sortOrder = sortOrder
            self.localPath = localPath
            self.thumbnailPath = thumbnailPath
            self.caption = caption
            self.ocrText = ocrText
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class KnowledgeChunk {
        public var id: UUID
        public var scopeTypeRaw: String
        public var scopeID: UUID?
        public var sourceTypeRaw: String
        public var sourceID: UUID?
        public var audioFile: AudioFile?
        public var text: String
        public var keywords: [String]
        public var rankHint: Double
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: UUID = UUID(), scopeType: KnowledgeChunkScopeType, scopeID: UUID? = nil, sourceType: KnowledgeChunkSourceType, sourceID: UUID? = nil, text: String, keywords: [String] = [], rankHint: Double = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
            self.id = id
            self.scopeTypeRaw = scopeType.rawValue
            self.scopeID = scopeID
            self.sourceTypeRaw = sourceType.rawValue
            self.sourceID = sourceID
            self.audioFile = nil
            self.text = text
            self.keywords = keywords
            self.rankHint = rankHint
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class CalendarEventLink {
        public var id: UUID
        public var provider: String
        public var externalID: String
        public var audioFile: AudioFile?
        public var title: String
        public var startAt: Date
        public var endAt: Date
        public var meetingURL: String?
        public var conferenceProvider: String?
        public var audioFileID: UUID?
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: UUID = UUID(), provider: String, externalID: String, title: String, startAt: Date, endAt: Date, meetingURL: String? = nil, conferenceProvider: String? = nil, audioFileID: UUID? = nil) {
            self.id = id
            self.provider = provider
            self.externalID = externalID
            self.audioFile = nil
            self.title = title
            self.startAt = startAt
            self.endAt = endAt
            self.meetingURL = meetingURL
            self.conferenceProvider = conferenceProvider
            self.audioFileID = audioFileID
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
}

// MARK: - Schema V5

/// V5: 非破壊の整形後文字起こし列を Transcript に追加。
public enum MemoraSchemaV5: VersionedSchema {
    public static var versionIdentifier = Schema.Version(5, 0, 0)
    public static let models: [any PersistentModel.Type] = [
        AudioFile.self, Transcript.self, Project.self, MeetingNote.self, MeetingMemo.self,
        PhotoAttachment.self, KnowledgeChunk.self, AskAISession.self, AskAIMessage.self,
        MemoryProfile.self, MemoryFact.self, TodoItem.self, ProcessingJob.self, WebhookSettings.self,
        PlaudSettings.self, CalendarEventLink.self, GoogleMeetSettings.self, NotionSettings.self,
        CustomSummaryTemplate.self, OnlineMeetingCapture.self, BotMeetingConfig.self, ScheduledBotMeeting.self
    ]
}

public enum MemoraSchemaV6: VersionedSchema {
    public static var versionIdentifier = Schema.Version(6, 0, 0)
    public static let models: [any PersistentModel.Type] = MemoraSchemaV5.models + [CustomVocabulary.self]
}

// MARK: - Migration Plan

/// スキーママイグレーションプラン。
/// V1 → V2 のような段階的マイグレーションを定義する。
/// 現時点では V1 のみなのでマイグレーション段階は空。
///
/// 将来のスキーマ変更例:
/// 1. 新しい VersionedSchema (V2) を定義
/// 2. LightweightMigration または ManualMigration を追加
/// 3. plan の stages に登録
///
/// ```
/// // 例: カラム追加の軽量マイグレーション
/// static let plan = MigrationPlan(stages: [
///     migrateV1toV2
/// ])
///
/// static let migrateV1toV2 = MigrationStage.lightweight(
///     fromVersion: MemoraSchemaV1.self,
///     toVersion: MemoraSchemaV2.self
/// )
/// ```
public enum MemoraMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [MemoraSchemaV1.self, MemoraSchemaV2.self, MemoraSchemaV3.self, MemoraSchemaV4.self, MemoraSchemaV5.self, MemoraSchemaV6.self]
    }

    public static let stages: [MigrationStage] = [
        MigrationStage.lightweight(
            fromVersion: MemoraSchemaV1.self,
            toVersion: MemoraSchemaV2.self
        ),
        MigrationStage.lightweight(
            fromVersion: MemoraSchemaV2.self,
            toVersion: MemoraSchemaV3.self
        ),
        MigrationStage.lightweight(
            fromVersion: MemoraSchemaV3.self,
            toVersion: MemoraSchemaV4.self
        ),
        MigrationStage.lightweight(
            fromVersion: MemoraSchemaV4.self,
            toVersion: MemoraSchemaV5.self
        ),
        MigrationStage.lightweight(
            fromVersion: MemoraSchemaV5.self,
            toVersion: MemoraSchemaV6.self
        )
    ]

    /// マイグレーションプラン未適用のストア（初期導入前）を許容
    public static let minimumSchemaVersion = MemoraSchemaV1.self

    public static var migrationStageOrder: [MigrationStage] { stages }
}
