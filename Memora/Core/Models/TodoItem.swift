import Foundation
import SwiftData

@Model
public final class TodoItem {
    public var id: UUID
    var title: String
    var notes: String?
    var assignee: String?
    var speaker: String?
    var priority: String
    var dueDate: Date?
    var relativeDueDate: String?
    var projectID: UUID?
    var isCompleted: Bool = false
    var createdAt: Date
    var completedAt: Date?

    init(
        title: String,
        notes: String? = nil,
        assignee: String? = nil,
        speaker: String? = nil,
        priority: String = "medium",
        dueDate: Date? = nil,
        relativeDueDate: String? = nil,
        projectID: UUID? = nil
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
        self.createdAt = Date()
    }
}
