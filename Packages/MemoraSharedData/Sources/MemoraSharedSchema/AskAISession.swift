import Foundation
import SwiftData

public enum AskAIScopeType: String, CaseIterable {
    case file = "file"
    case project = "project"
    case global = "global"
}

@Model
public final class AskAISession {
    public var id: UUID
    public var scopeTypeRaw: String
    public var scopeID: UUID?
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date

    public var scopeType: AskAIScopeType {
        get { AskAIScopeType(rawValue: scopeTypeRaw) ?? .file }
        set { scopeTypeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        scopeType: AskAIScopeType,
        scopeID: UUID? = nil,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.scopeTypeRaw = scopeType.rawValue
        self.scopeID = scopeID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func rename(_ title: String) {
        self.title = title
        self.updatedAt = Date()
    }
}
