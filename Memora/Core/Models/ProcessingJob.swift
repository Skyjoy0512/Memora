import Foundation
import SwiftData

@Model
public final class ProcessingJob {
    public var id: UUID
    var audioFileID: UUID
    var jobType: String
    var status: String
    var progress: Double = 0
    var error: String?
    var startedAt: Date?
    var completedAt: Date?
    var stage: String
    var retryCount: Int = 0
    var maxRetries: Int = 1
    var createdAt: Date

    init(audioFileID: UUID, jobType: String) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.jobType = jobType
        self.status = "pending"
        self.stage = "none"
        self.retryCount = 0
        self.maxRetries = 2
        self.createdAt = Date()
    }

    // MARK: - Status Update Helpers

    func markStarted(stage: String) {
        status = "running"
        startedAt = Date()
        self.stage = stage
    }

    func updateProgress(_ value: Double, stage: String) {
        progress = value
        self.stage = stage
    }

    func markCompleted() {
        status = "completed"
        completedAt = Date()
        progress = 1.0
    }

    func markFailed(_ error: String, stage: String) {
        status = "failed"
        self.error = error
        self.stage = stage
    }

    var canRetry: Bool {
        retryCount < maxRetries
    }

    func incrementRetry() {
        retryCount += 1
        status = "pending"
        stage = "none"
        error = nil
        startedAt = nil
        completedAt = nil
        progress = 0
    }
}
