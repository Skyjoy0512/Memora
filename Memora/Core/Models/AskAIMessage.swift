import Foundation
import SwiftData

enum AskAIMessageRole: String, CaseIterable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

@Model
final class AskAIMessage {
    var id: UUID
    var sessionID: UUID
    var roleRaw: String
    var content: String
    var citationsJSON: String?
    var createdAt: Date

    var role: AskAIMessageRole {
        get { AskAIMessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        role: AskAIMessageRole,
        content: String,
        citationsJSON: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.roleRaw = role.rawValue
        self.content = content
        self.citationsJSON = citationsJSON
        self.createdAt = createdAt
    }
}
