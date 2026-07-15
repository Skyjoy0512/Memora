import Foundation
import SwiftData

@Model
public final class TodoItem {
    public var id: UUID
    public var title: String
    public var notes: String?
    public var assignee: String?
    public var speaker: String?
    public var priority: String
    public var dueDate: Date?
    public var relativeDueDate: String?
    public var projectID: UUID?
    public var parentID: UUID?
    public var sourceAudioFileID: UUID?
    public var isCompleted: Bool = false
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        title: String,
        notes: String? = nil,
        assignee: String? = nil,
        speaker: String? = nil,
        priority: String = "medium",
        dueDate: Date? = nil,
        relativeDueDate: String? = nil,
        projectID: UUID? = nil,
        parentID: UUID? = nil,
        sourceAudioFileID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.assignee = assignee
        self.speaker = speaker
        self.priority = priority
        self.dueDate = dueDate
        self.relativeDueDate = relativeDueDate
        self.projectID = projectID
        self.parentID = parentID
        self.sourceAudioFileID = sourceAudioFileID
        self.createdAt = Date()
    }
}
