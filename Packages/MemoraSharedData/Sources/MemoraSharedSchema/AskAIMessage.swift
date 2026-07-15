import Foundation
import SwiftData

public enum AskAIMessageRole: String, CaseIterable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

@Model
public final class AskAIMessage {
    public var id: UUID
    public var sessionID: UUID
    public var roleRaw: String
    public var content: String
    public var citationsJSON: String?
    public var createdAt: Date

    public var role: AskAIMessageRole {
        get { AskAIMessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    public init(
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
