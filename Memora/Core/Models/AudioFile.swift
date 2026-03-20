import Foundation
import SwiftData

@Model
final class AudioFile {
    @Attribute(.unique) var id: UUID
    var title: String
    var recordedAt: Date
    var durationSec: Double
    var localPath: String
    var sourceType: SourceType
    var summaryLine: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transcript.audioFile)
    var transcript: Transcript?

    @Relationship(deleteRule: .cascade, inverse: \MeetingNote.audioFile)
    var meetingNote: MeetingNote?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.audioFile)
    var attachments: [Attachment]

    @Relationship(deleteRule: .cascade, inverse: \ProcessingJob.audioFile)
    var jobs: [ProcessingJob]

    var project: Project?

    enum SourceType: String, Codable {
        case iphoneRecording = "iphone_recording"
        case importedFile = "imported_file"
        case plaudSync = "plaud_sync"
    }

    init(
        id: UUID = UUID(),
        title: String,
        recordedAt: Date = Date(),
        durationSec: Double,
        localPath: String,
        sourceType: SourceType,
        summaryLine: String? = nil,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.recordedAt = recordedAt
        self.durationSec = durationSec
        self.localPath = localPath
        self.sourceType = sourceType
        self.summaryLine = summaryLine
        self.project = project
        self.attachments = []
        self.jobs = []
        self.createdAt = Date()
    }
}
