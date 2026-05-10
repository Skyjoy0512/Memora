import Foundation
import SwiftData

@Model
final class ScheduledBotMeeting {
    var id: UUID
    var platform: String
    var meetingURL: String
    var meetingTitle: String
    var scheduledTime: Date
    var durationMinutes: Int
    var status: String
    var serverJobID: String?
    var audioFileID: UUID?
    var errorMessage: String?
    var resultSummary: String?
    var createdAt: Date
    var updatedAt: Date

    var isCompleted: Bool { status == "completed" }
    var isFailed: Bool { status == "failed" }

    init(
        platform: String,
        meetingURL: String,
        meetingTitle: String,
        scheduledTime: Date,
        durationMinutes: Int = 60
    ) {
        self.id = UUID()
        self.platform = platform
        self.meetingURL = meetingURL
        self.meetingTitle = meetingTitle
        self.scheduledTime = scheduledTime
        self.durationMinutes = durationMinutes
        self.status = "pending"
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
