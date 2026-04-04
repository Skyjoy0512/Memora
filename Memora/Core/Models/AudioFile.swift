import Foundation
import SwiftData

enum SourceType: String, CaseIterable {
    case recording = "recording"
    case `import` = "import"
    case plaud = "plaud"
    case google = "google"
}

@Model
final class AudioFile {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var audioURL: String
    var isTranscribed: Bool = false
    var projectID: UUID?
    // 要約関連フィールド
    var isSummarized: Bool = false
    var summary: String?
    var keyPoints: String?
    var actionItems: String?
    // ライフログ関連フィールド
    var isLifeLog: Bool = false
    var lifeLogTags: [String] = []
    var calendarEventId: String?
    // ソース・参照データ
    var sourceTypeRaw: String = SourceType.recording.rawValue
    var referenceTranscript: String?

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .recording }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var isPlaudImport: Bool {
        sourceType == .plaud
    }

    init(title: String, audioURL: String, projectID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.createdAt = Date()
        self.duration = 0
        self.projectID = projectID
    }
}
