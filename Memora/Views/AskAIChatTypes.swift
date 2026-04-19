import Foundation

struct AskAIScopeOption: Identifiable, Hashable {
    let scope: ChatScope
    let title: String

    var id: String {
        switch scope {
        case .file(let fileId):
            return "file-\(fileId.uuidString)"
        case .project(let projectId):
            return "project-\(projectId.uuidString)"
        case .global:
            return "global"
        }
    }
}

struct AskAIConversationMessage: Identifiable, Hashable {
    let id: UUID
    let role: AskAIMessageRole
    let content: String
    let citations: [AskAICitation]
    let createdAt: Date
}

struct AskAICitation: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let sourceLabel: String
    let excerpt: String
}

struct AskAISourceBadge: Hashable, Identifiable {
    let id: String
    let label: String
    let systemImage: String
}
