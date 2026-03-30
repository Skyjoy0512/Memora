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

    init(audioFileID: UUID, jobType: String) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.jobType = jobType
        self.status = "pending"
    }
}
