import Foundation
import SwiftData

public enum SourceType: String, CaseIterable, Sendable {
    case recording = "recording"
    case `import` = "import"
    case plaud = "plaud"
    case omi = "omi"
    case plaudEmbedded = "plaud_embedded"
    case plaudCloud = "plaud_cloud"
    case genericDevice = "generic_device"
    case google = "google"
    case onlineMeeting = "online_meeting"
    case botMeeting = "bot_meeting"
}

@Model
public final class AudioFile {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var audioURL: String
    /// 完了済み録音セグメントのパス。空配列は V3 以前の単一ファイル録音を表す。
    public var segmentPaths: [String] = []
    public var isTranscribed: Bool = false
    public var projectID: UUID?
    // 要約関連フィールド
    public var isSummarized: Bool = false
    public var summary: String?
    public var keyPoints: String?
    public var actionItems: String?
    // ライフログ関連フィールド
    public var isLifeLog: Bool = false
    public var lifeLogTags: [String] = []
    public var calendarEventId: String?
    // ソース・参照データ
    public var sourceTypeRaw: String = SourceType.recording.rawValue
    public var referenceTranscript: String?
    /// Plaud 等の参照データから抽出した話者数。
    /// FluidAudio のクラスタリングで numSpeakers ヒントとして使用。
    public var referenceSpeakerCount: Int?

    // MARK: - Relationships (cascade delete)

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

    public var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .recording }
        set { sourceTypeRaw = newValue.rawValue }
    }

    public var isPlaudImport: Bool {
        sourceType == .plaud
    }

    public init(title: String, audioURL: String, projectID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.createdAt = Date()
        self.duration = 0
        self.projectID = projectID
    }
}
