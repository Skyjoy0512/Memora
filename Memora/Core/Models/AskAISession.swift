import Foundation
import SwiftData

enum AskAIScopeType: String, CaseIterable {
    case file = "file"
    case project = "project"
    case global = "global"
}

@Model
final class AskAISession {
    var id: UUID
    var scopeTypeRaw: String
    var scopeID: UUID?
    var title: String
    var createdAt: Date
    var updatedAt: Date

    var scopeType: AskAIScopeType {
        get { AskAIScopeType(rawValue: scopeTypeRaw) ?? .file }
        set { scopeTypeRaw = newValue.rawValue }
    }

    init(
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

    func rename(_ title: String) {
        self.title = title
        self.updatedAt = Date()
    }
}
