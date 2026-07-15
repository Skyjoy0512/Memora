import Foundation
import SwiftData

@Model
public final class OnlineMeetingCapture {
    public var id: UUID
    public var audioFileID: UUID?
    public var platform: String
    public var meetingTitle: String
    public var meetingURL: String?
    public var captureMode: String
    public var status: String
    public var scheduledAt: Date?
    public var startedAt: Date?
    public var completedAt: Date?
    public var duration: TimeInterval?
    public var errorMessage: String?
    public var createdAt: Date

    public var isCompleted: Bool { status == "completed" }
    public var isFailed: Bool { status == "failed" }

    public init(
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
