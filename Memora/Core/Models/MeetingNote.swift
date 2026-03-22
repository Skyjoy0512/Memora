import Foundation
import SwiftData

@Model
public final class MeetingNote {
    public var id: UUID
    var audioFileID: UUID
    var summary: String?
    var decisions: [String]
    var actionItems: [String]
    var createdAt: Date
    var updatedAt: Date?

    init(audioFileID: UUID, summary: String? = nil) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.summary = summary
        self.decisions = []
        self.actionItems = []
        self.createdAt = Date()
    }
}
