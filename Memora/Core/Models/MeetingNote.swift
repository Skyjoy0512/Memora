import Foundation
import SwiftData

@Model
final class MeetingNote {
    @Attribute(.unique) var id: UUID
    var audioFile: AudioFile?
    var templateType: TemplateType
    var summary: String
    var decisions: [String]
    var actionItems: [String]
    var generatedByModel: String
    var createdAt: Date

    enum TemplateType: String, Codable {
        case summary = "summary"
        case detailed = "detailed"
        case actionFocused = "action_focused"
    }

    init(
        id: UUID = UUID(),
        templateType: TemplateType,
        summary: String,
        decisions: [String],
        actionItems: [String],
        generatedByModel: String
    ) {
        self.id = id
        self.templateType = templateType
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.generatedByModel = generatedByModel
        self.createdAt = Date()
    }
}
