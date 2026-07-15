import Foundation
import SwiftData

@Model
public final class ScheduledBotMeeting {
    public var id: UUID
    public var platform: String
    public var meetingURL: String
    public var meetingTitle: String
    public var scheduledTime: Date
    public var durationMinutes: Int
    public var status: String
    public var serverJobID: String?
    public var audioFileID: UUID?
    public var errorMessage: String?
    public var resultSummary: String?
    public var createdAt: Date
    public var updatedAt: Date

    public var isCompleted: Bool { status == "completed" }
    public var isFailed: Bool { status == "failed" }

    public init(
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
