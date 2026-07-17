import Foundation
import SwiftData
import MemoraSharedAskAI

@MainActor
final class KnowledgeQueryService {
    struct ContextPack {
        let scopeTitle: String
        let promptContext: String
        let sourceBadges: [SourceBadge]
        let citations: [Citation]
        let instructionHints: [String]
    }

    struct SourceBadge: Hashable, Identifiable {
        let id: String
        let label: String
        let systemImage: String
    }

    struct Citation: Hashable, Identifiable {
        let id: String
        let sourceType: String
        let title: String
        let sourceLabel: String
        let excerpt: String
    }

    private let core: KnowledgeQueryCore

    init(modelContext: ModelContext, memoryPrivacy: AskAIMemoryPrivacyConfiguration) {
        core = KnowledgeQueryCore(modelContext: modelContext, memoryPrivacy: memoryPrivacy)
    }

    func buildContext(for scope: ChatScope) -> ContextPack { present(core.buildContext(for: scope)) }
    func buildContext(for scope: ChatScope, query: String) -> ContextPack { present(core.buildContext(for: scope, query: query)) }
    func fetchFileContext(fileID: UUID) -> ContextPack { present(core.fetchFileContext(fileID: fileID)) }
    func fetchProjectContext(projectID: UUID) -> ContextPack { present(core.fetchProjectContext(projectID: projectID)) }
    func fetchGlobalContext() -> ContextPack { present(core.fetchGlobalContext()) }

    func makePrompt(userMessage: String, contextPack: ContextPack) -> String {
        core.makePrompt(userMessage: userMessage, contextPack: .init(
            scopeTitle: contextPack.scopeTitle,
            promptContext: contextPack.promptContext,
            citations: [],
            instructionHints: contextPack.instructionHints
        ))
    }

    private func present(_ pack: KnowledgeQueryCore.NeutralContextPack) -> ContextPack {
        let badges = uniqueBadges(pack.citations.map {
            SourceBadge(id: $0.sourceType, label: sourceLabel($0.sourceType), systemImage: sourceImage($0.sourceType))
        })
        return ContextPack(
            scopeTitle: pack.scopeTitle,
            promptContext: pack.promptContext,
            sourceBadges: badges,
            citations: pack.citations.map { Citation(id: $0.title, sourceType: $0.sourceType, title: $0.title, sourceLabel: sourceLabel($0.sourceType), excerpt: $0.excerpt) },
            instructionHints: pack.instructionHints
        )
    }

    private func uniqueBadges(_ badges: [SourceBadge]) -> [SourceBadge] {
        var seen: Set<String> = []
        return badges.filter { seen.insert($0.id).inserted }
    }

    private func sourceLabel(_ type: String) -> String {
        switch type {
        case "summary": return "Summary"; case "transcript": return "Transcript"; case "memo": return "Memo"
        case "todo": return "Todo"; case "photoOCR": return "OCR"; case "referenceTranscript": return "Reference"
        case "memory-profile", "memory-facts": return "Memory"; default: return type
        }
    }

    private func sourceImage(_ type: String) -> String {
        switch type {
        case "summary": return "text.quote"; case "transcript": return "text.alignleft"; case "memo": return "square.and.pencil"
        case "todo": return "checklist"; case "photoOCR": return "photo"; case "referenceTranscript": return "doc.text"
        case "memory-profile": return "brain.head.profile"; case "memory-facts": return "brain"; default: return "doc.text"
        }
    }
}
