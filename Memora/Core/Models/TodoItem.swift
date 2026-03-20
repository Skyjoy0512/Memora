import Foundation
import SwiftData

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceFileId: UUID?
    var sourceFileTitle: String?
    var projectId: UUID?
    var assigneeLabel: String?
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        sourceFileId: UUID? = nil,
        sourceFileTitle: String? = nil,
        projectId: UUID? = nil,
        assigneeLabel: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.sourceFileId = sourceFileId
        self.sourceFileTitle = sourceFileTitle
        self.projectId = projectId
        self.assigneeLabel = assigneeLabel
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}
