import Foundation
import SwiftData

@Model
final class ProcessingChunk {
    @Attribute(.unique) var id: UUID
    var job: ProcessingJob?
    var chunkIndex: Int
    var timeRangeStartSec: Double
    var timeRangeEndSec: Double
    var status: ProcessingJob.JobStatus
    var retryCount: Int
    var partialTranscript: String?

    init(
        id: UUID = UUID(),
        chunkIndex: Int,
        timeRangeStartSec: Double,
        timeRangeEndSec: Double,
        status: ProcessingJob.JobStatus = .queued,
        retryCount: Int = 0
    ) {
        self.id = id
        self.chunkIndex = chunkIndex
        self.timeRangeStartSec = timeRangeStartSec
        self.timeRangeEndSec = timeRangeEndSec
        self.status = status
        self.retryCount = retryCount
    }
}
