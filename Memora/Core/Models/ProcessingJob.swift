import Foundation
import SwiftData

@Model
final class ProcessingJob {
    @Attribute(.unique) var id: UUID
    var audioFile: AudioFile?
    var templateType: String
    var modelProvider: String
    var status: JobStatus
    var step: JobStep
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ProcessingChunk.job)
    var chunks: [ProcessingChunk]

    enum JobStatus: String, Codable {
        case queued = "queued"
        case running = "running"
        case completed = "completed"
        case failed = "failed"
    }

    enum JobStep: String, Codable {
        case transcription = "transcription"
        case summary = "summary"
        case decisions = "decisions"
        case todos = "todos"
    }

    init(
        id: UUID = UUID(),
        templateType: String,
        modelProvider: String,
        status: JobStatus = .queued,
        step: JobStep = .transcription
    ) {
        self.id = id
        self.templateType = templateType
        self.modelProvider = modelProvider
        self.status = status
        self.step = step
        self.chunks = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
