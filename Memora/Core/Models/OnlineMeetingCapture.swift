import Foundation
import SwiftData

@Model
final class OnlineMeetingCapture {
    var id: UUID
    var audioFileID: UUID?
    var platform: String
    var meetingTitle: String
    var meetingURL: String?
    var captureMode: String
    var status: String
    var scheduledAt: Date?
    var startedAt: Date?
    var completedAt: Date?
    var duration: TimeInterval?
    var errorMessage: String?
    var createdAt: Date

    var isCompleted: Bool { status == "completed" }
    var isFailed: Bool { status == "failed" }

    init(
        platform: String,
        meetingTitle: String,
        meetingURL: String? = nil,
        captureMode: String = "local_broadcast"
    ) {
        self.id = UUID()
        self.platform = platform
        self.meetingTitle = meetingTitle
        self.meetingURL = meetingURL
        self.captureMode = captureMode
        self.status = "scheduled"
        self.createdAt = Date()
    }
}
