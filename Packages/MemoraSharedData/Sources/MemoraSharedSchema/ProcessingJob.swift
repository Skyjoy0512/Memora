import Foundation
import SwiftData

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
        self.jobType = jobType
        self.status = "pending"
        self.stage = "none"
        self.retryCount = 0
        self.maxRetries = 2
        self.createdAt = Date()
    }

    // MARK: - Status Update Helpers

    public func markStarted(stage: String) {
        status = "running"
        startedAt = Date()
        self.stage = stage
    }

    public func updateProgress(_ value: Double, stage: String) {
        progress = value
        self.stage = stage
    }

    public func markCompleted() {
        status = "completed"
        completedAt = Date()
        progress = 1.0
    }

    public func markFailed(_ error: String, stage: String) {
        status = "failed"
        self.error = error
        self.stage = stage
    }

    public var canRetry: Bool {
        retryCount < maxRetries
    }

    public func incrementRetry() {
        retryCount += 1
        status = "pending"
        stage = "none"
        error = nil
        startedAt = nil
        completedAt = nil
        progress = 0
    }

    // MARK: - Cleanup

    /// 完了済みまたは失敗した ProcessingJob を一括削除する
    @MainActor
    public static func cleanupCompletedJobs(in context: ModelContext) {
        let descriptor = FetchDescriptor<ProcessingJob>(
            predicate: #Predicate { $0.status == "completed" || $0.status == "failed" }
        )
        if let jobs = try? context.fetch(descriptor) {
            for job in jobs {
                context.delete(job)
            }
            try? context.save()
        }
    }
}
