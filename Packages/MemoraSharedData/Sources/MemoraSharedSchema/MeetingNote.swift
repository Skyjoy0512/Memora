import Foundation
import SwiftData

@Model
public final class MeetingNote {
    public var id: UUID
    public var audioFileID: UUID
    public var summary: String?
    public var decisions: [String]
    public var actionItems: [String]
    public var createdAt: Date
    public var updatedAt: Date?

    public init(audioFileID: UUID, summary: String? = nil) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.summary = summary
        self.decisions = []
        self.actionItems = []
        self.createdAt = Date()
    }
}
