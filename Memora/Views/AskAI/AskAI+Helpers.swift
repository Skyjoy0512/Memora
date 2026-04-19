import SwiftUI
import SwiftData

// MARK: - AskAI Helper Methods

extension AskAIView {
    var activeScopeKey: String {
        scopeKey(for: activeScope)
    }

    var currentSession: AskAISession? {
        guard let activeSessionID else { return nil }
        return sessions.first { $0.id == activeSessionID }
    }

    var scopeDescription: String {
        label(for: activeScope)
    }

    var suggestions: [String] {
        switch activeScope {
        case .file:
            return ["要点をまとめて", "決定事項を確認", "次のアクションは？", "参加者の発言を分析"]
        case .project:
            return ["このプロジェクトの進捗を教えて", "未完了タスクを整理して", "重要な論点をまとめて", "次に確認すべき録音は？"]
        case .global:
            return ["最近の会議の傾向は？", "未完了のタスクを横断で整理して", "重要な決定事項を教えて", "今週の動きを要約して"]
        }
    }

    func decodeCitations(from json: String?) -> [AskAICitation] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AskAICitation].self, from: data)) ?? []
    }

    func fetchSessions(for scope: ChatScope) -> [AskAISession] {
        let descriptor = FetchDescriptor<AskAISession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let loaded = (try? modelContext.fetch(descriptor)) ?? []
        return loaded.filter { session in
            session.scopeType == scopeType(for: scope) && session.scopeID == scopeID(for: scope)
        }
    }

    func makeAvailableScopes(from initialScope: ChatScope) -> [AskAIScopeOption] {
        var options: [AskAIScopeOption] = []

        switch initialScope {
        case .file(let fileId):
            if let file = fetchAudioFile(id: fileId) {
                options.append(AskAIScopeOption(scope: .file(fileId: file.id), title: "File"))
                if let projectID = file.projectID {
                    options.append(AskAIScopeOption(scope: .project(projectId: projectID), title: "Project"))
                }
            } else {
                options.append(AskAIScopeOption(scope: initialScope, title: "File"))
            }
            options.append(AskAIScopeOption(scope: .global, title: "Global"))

        case .project(let projectId):
            options.append(AskAIScopeOption(scope: .project(projectId: projectId), title: "Project"))
            options.append(AskAIScopeOption(scope: .global, title: "Global"))

        case .global:
            options.append(AskAIScopeOption(scope: .global, title: "Global"))
        }

        return options
    }

    func fetchAudioFile(id: UUID) -> AudioFile? {
        var descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func fetchProject(id: UUID) -> Project? {
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func makeSessionTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Chat" : String(trimmed.prefix(24))
    }

    func label(for scope: ChatScope) -> String {
        switch scope {
        case .file(let fileId):
            return "\(fetchAudioFile(id: fileId)?.title ?? "このファイル") について質問"
        case .project(let projectId):
            return "\(fetchProject(id: projectId)?.title ?? "このプロジェクト") について質問"
        case .global:
            return "Memora 全体について質問"
        }
    }

    func scopeKey(for scope: ChatScope) -> String {
        switch scope {
        case .file(let fileId):
            return "file-\(fileId.uuidString)"
        case .project(let projectId):
            return "project-\(projectId.uuidString)"
        case .global:
            return "global"
        }
    }

    func scopeType(for scope: ChatScope) -> AskAIScopeType {
        switch scope {
        case .file:
            return .file
        case .project:
            return .project
        case .global:
            return .global
        }
    }

    func scopeID(for scope: ChatScope) -> UUID? {
        switch scope {
        case .file(let fileId):
            return fileId
        case .project(let projectId):
            return projectId
        case .global:
            return nil
        }
    }
}
