import Foundation
import SwiftData

@MainActor
final class KnowledgeQueryService {

    // MARK: - Types (referenced from AskAIView — do not move in this task)

    struct ContextSource {
        let type: String
        let title: String
        let body: String
        let systemImage: String
        let shortLabel: String
    }

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
        let title: String
        let sourceLabel: String
        let excerpt: String
    }

    // MARK: - Properties

    private let modelContext: ModelContext
    private let memoryPrivacyMode: String

    // MARK: - Init

    init(modelContext: ModelContext, memoryPrivacyMode: String = "standard") {
        self.modelContext = modelContext
        self.memoryPrivacyMode = memoryPrivacyMode
    }

    // MARK: - Public API

    func buildContext(for scope: ChatScope) -> ContextPack {
        switch scope {
        case .file(let fileId):
            return fetchFileContext(fileID: fileId)
        case .project(let projectId):
            return fetchProjectContext(projectID: projectId)
        case .global:
            return fetchGlobalContext()
        }
    }

    // MARK: - File Scope

    func fetchFileContext(fileID: UUID) -> ContextPack {
        guard let file = fetchAudioFile(id: fileID) else {
            return emptyPack(scopeTitle: "このファイル")
        }

        var sources: [ContextSource] = memoryContextSources()

        // Primary: KnowledgeChunk-based retrieval (rank descending, top-8)
        let chunks = fetchChunks(scopeType: .file, scopeID: fileID, limit: 8)

        if !chunks.isEmpty {
            for chunk in chunks {
                let image = sourceImage(for: chunk.sourceType)
                if let source = makeContextSource(
                    type: chunk.sourceTypeRaw,
                    title: "\(file.title) / \(chunk.sourceTypeRaw.capitalized)",
                    body: chunk.text,
                    systemImage: image,
                    shortLabel: chunk.sourceTypeRaw.capitalized
                ) {
                    sources.append(source)
                }
            }
        } else {
            // Fallback: direct entity queries when no chunks exist
            let transcript = fetchTranscript(for: file.id)?.text
            let memo = fetchMeetingMemo(for: file.id)?.plainTextCache

            sources += [
                makeContextSource(
                    type: "transcript",
                    title: "\(file.title) / Transcript",
                    body: transcript,
                    systemImage: "text.alignleft",
                    shortLabel: "Transcript"
                ),
                makeContextSource(
                    type: "summary",
                    title: "\(file.title) / Summary",
                    body: file.summary,
                    systemImage: "text.quote",
                    shortLabel: "Summary"
                ),
                makeContextSource(
                    type: "memo",
                    title: "\(file.title) / Memo",
                    body: memo,
                    systemImage: "square.and.pencil",
                    shortLabel: "Memo"
                ),
                makeContextSource(
                    type: "reference",
                    title: "\(file.title) / Plaud",
                    body: file.referenceTranscript,
                    systemImage: "doc.text",
                    shortLabel: "Plaud"
                )
            ].compactMap { $0 }
        }

        return makeContextPack(scopeTitle: file.title, sources: sources)
    }

    // MARK: - Project Scope

    func fetchProjectContext(projectID: UUID) -> ContextPack {
        let project = fetchProject(id: projectID)

        // KnowledgeChunk-based retrieval: rankHint descending, top-6
        let chunks = fetchChunks(scopeType: .project, scopeID: projectID, limit: 6)

        var sources: [ContextSource] = memoryContextSources()

        for chunk in chunks {
            if let source = makeContextSource(
                type: chunk.sourceTypeRaw,
                title: chunkTitle(sourceType: chunk.sourceType, scopeName: project?.title ?? "Project"),
                body: chunk.text,
                systemImage: sourceImage(for: chunk.sourceType),
                shortLabel: chunk.sourceTypeRaw.capitalized
            ) {
                sources.append(source)
            }
        }

        // Fallback: if no chunks found, use direct file queries
        if chunks.isEmpty {
            let files = fetchAudioFiles(projectID: projectID).prefix(4)
            let todos = fetchTodos(projectID: projectID).prefix(4)

            for file in files {
                if let summary = file.summary, !summary.isEmpty {
                    sources.append(ContextSource(
                        type: "summary",
                        title: "\(file.title) / Summary",
                        body: summary,
                        systemImage: "text.quote",
                        shortLabel: "Summary"
                    ))
                } else if let transcript = fetchTranscript(for: file.id)?.text, !transcript.isEmpty {
                    sources.append(ContextSource(
                        type: "transcript",
                        title: "\(file.title) / Transcript",
                        body: transcript,
                        systemImage: "text.alignleft",
                        shortLabel: "Transcript"
                    ))
                }

                if let memo = fetchMeetingMemo(for: file.id)?.plainTextCache, !memo.isEmpty {
                    sources.append(ContextSource(
                        type: "memo",
                        title: "\(file.title) / Memo",
                        body: memo,
                        systemImage: "square.and.pencil",
                        shortLabel: "Memo"
                    ))
                }
            }

            if !todos.isEmpty {
                let todoText = todos.map { "• \($0.title)" }.joined(separator: "\n")
                sources.append(ContextSource(
                    type: "todo",
                    title: "\(project?.title ?? "Project") / Todo",
                    body: todoText,
                    systemImage: "checklist",
                    shortLabel: "Todo"
                ))
            }
        }

        return makeContextPack(scopeTitle: project?.title ?? "このプロジェクト", sources: Array(sources.prefix(6)))
    }

    // MARK: - Global Scope

    func fetchGlobalContext() -> ContextPack {
        // KnowledgeChunk-based retrieval: rankHint + createdAt descending, top-8
        let chunks = fetchChunks(scopeType: .global, limit: 8)

        var sources: [ContextSource] = memoryContextSources()

        for chunk in chunks {
            if let source = makeContextSource(
                type: chunk.sourceTypeRaw,
                title: chunkTitle(sourceType: chunk.sourceType, scopeName: "Global"),
                body: chunk.text,
                systemImage: sourceImage(for: chunk.sourceType),
                shortLabel: chunk.sourceTypeRaw.capitalized
            ) {
                sources.append(source)
            }
        }

        // Fallback: if no chunks found, use direct queries
        if chunks.isEmpty {
            let files = fetchRecentAudioFiles(limit: 5)
            let todos = fetchTodos(projectID: nil).filter { !$0.isCompleted }.prefix(5)

            for file in files {
                if let summary = file.summary, !summary.isEmpty {
                    sources.append(ContextSource(
                        type: "summary",
                        title: "\(file.title) / Summary",
                        body: summary,
                        systemImage: "text.quote",
                        shortLabel: "Summary"
                    ))
                } else if let transcript = fetchTranscript(for: file.id)?.text, !transcript.isEmpty {
                    sources.append(ContextSource(
                        type: "transcript",
                        title: "\(file.title) / Transcript",
                        body: transcript,
                        systemImage: "text.alignleft",
                        shortLabel: "Transcript"
                    ))
                }
            }

            if !todos.isEmpty {
                let todoText = todos.map { "• \($0.title)" }.joined(separator: "\n")
                sources.append(ContextSource(
                    type: "todo",
                    title: "Global / Todo",
                    body: todoText,
                    systemImage: "checklist",
                    shortLabel: "Todo"
                ))
            }
        }

        return makeContextPack(scopeTitle: "Memora 全体", sources: Array(sources.prefix(6)))
    }

    // MARK: - Prompt Building

    func makePrompt(userMessage: String, contextPack: ContextPack) -> String {
        let contextBlock = contextPack.promptContext.isEmpty
            ? "コンテキストはまだありません。一般的な回答ではなく、分からない場合は分からないと答えてください。"
            : contextPack.promptContext
        let instructionBlock = contextPack.instructionHints.isEmpty
            ? ""
            : "\n追加指示:\n" + contextPack.instructionHints.map { "- \($0)" }.joined(separator: "\n")

        return """
        あなたは Memora の Ask AI アシスタントです。
        必ず日本語で簡潔に答えてください。
        与えられたコンテキストに根拠がある内容だけを優先し、断定できない点は推測だと明示してください。
        \(instructionBlock)

        スコープ:
        \(contextPack.scopeTitle)

        コンテキスト:
        \(contextBlock)

        質問:
        \(userMessage)
        """
    }

    // MARK: - KnowledgeChunk Fetching

    private func fetchChunks(
        scopeType: KnowledgeChunkScopeType,
        scopeID: UUID? = nil,
        sourceType: KnowledgeChunkSourceType? = nil,
        limit: Int = 6
    ) -> [KnowledgeChunk] {
        // Use predicate-based filtering for better performance
        let scopeTypeRaw = scopeType.rawValue

        var descriptor: FetchDescriptor<KnowledgeChunk>
        if let scopeID {
            descriptor = FetchDescriptor<KnowledgeChunk>(
                predicate: #Predicate {
                    $0.scopeTypeRaw == scopeTypeRaw && $0.scopeID == scopeID
                },
                sortBy: [
                    SortDescriptor(\.rankHint, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse)
                ]
            )
        } else {
            descriptor = FetchDescriptor<KnowledgeChunk>(
                predicate: #Predicate {
                    $0.scopeTypeRaw == scopeTypeRaw
                },
                sortBy: [
                    SortDescriptor(\.rankHint, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse)
                ]
            )
        }
        descriptor.fetchLimit = limit * 2

        var results = (try? modelContext.fetch(descriptor)) ?? []

        // Additional sourceType filter if needed (not in predicate to avoid complex predicates)
        if let sourceType {
            let sourceTypeRaw = sourceType.rawValue
            results = results.filter { $0.sourceTypeRaw == sourceTypeRaw }
        }

        return Array(results.prefix(limit))
    }

    // MARK: - Memory Context

    private func memoryContextSources() -> [ContextSource] {
        guard currentMemoryMode != .off else { return [] }

        var sources: [ContextSource] = []

        if let profileSource = makeProfileMemorySource() {
            sources.append(profileSource)
        }

        if let factsSource = makeFactsMemorySource() {
            sources.append(factsSource)
        }

        return sources
    }

    private func memoryInstructionHints() -> [String] {
        guard currentMemoryMode != .off else {
            return ["memory 設定が完全オフのため、保存済み memory を参照しないでください。"]
        }

        var hints: [String] = []
        if currentMemoryMode == .paused {
            hints.append("新規 memory 保存は停止中ですが、既存の承認済み memory は回答方針に使えます。")
        }
        if let profile = fetchPrimaryMemoryProfile() {
            if let lang = profile.preferredLanguage,
               !lang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hints.append("preferred language: \(lang)")
            }
            if let style = profile.summaryStyle,
               !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hints.append("summary style: \(style)")
            }
            if let role = profile.roleLabel,
               !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hints.append("user role: \(role)")
            }
            if let glossary = profile.glossaryJSON,
               !glossary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hints.append("glossary: \(glossary)")
            }
        }
        return hints
    }

    private var currentMemoryMode: MemoryPrivacyMode {
        MemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
    }

    private enum MemoryPrivacyMode: String {
        case standard
        case paused
        case off
    }

    private func makeProfileMemorySource() -> ContextSource? {
        guard let profile = fetchPrimaryMemoryProfile() else { return nil }

        let entries = [
            labeledLine("summaryStyle", value: profile.summaryStyle),
            labeledLine("preferredLanguage", value: profile.preferredLanguage),
            labeledLine("roleLabel", value: profile.roleLabel),
            labeledLine("glossary", value: profile.glossaryJSON)
        ].compactMap { $0 }

        guard !entries.isEmpty else { return nil }

        return ContextSource(
            type: "memory-profile",
            title: "Approved Memory / Profile",
            body: entries.joined(separator: "\n"),
            systemImage: "brain.head.profile",
            shortLabel: "Memory"
        )
    }

    private func makeFactsMemorySource() -> ContextSource? {
        let activeFacts = fetchActiveMemoryFacts()
        guard !activeFacts.isEmpty else { return nil }

        let body = activeFacts
            .prefix(6)
            .map { fact in
                let confidence = Int(fact.confidence * 100)
                return "\(fact.key): \(fact.value) (\(fact.source), \(confidence)%)"
            }
            .joined(separator: "\n")

        return ContextSource(
            type: "memory-facts",
            title: "Approved Memory / Facts",
            body: body,
            systemImage: "brain",
            shortLabel: "Memory"
        )
    }

    // MARK: - Pack Building

    private func makeContextPack(scopeTitle: String, sources: [ContextSource]) -> ContextPack {
        let limitedSources = sources.prefix(6)
        let promptContext = limitedSources.map { source in
            "[\(source.title)]\n\(truncate(source.body, limit: 900))"
        }.joined(separator: "\n\n")

        let badges = uniqueBadges(from: limitedSources.map {
            SourceBadge(id: $0.type, label: $0.shortLabel, systemImage: $0.systemImage)
        })

        let citations = limitedSources.map { source in
            Citation(
                id: source.title,
                title: source.title,
                sourceLabel: source.shortLabel,
                excerpt: truncate(source.body, limit: 120)
            )
        }

        return ContextPack(
            scopeTitle: scopeTitle,
            promptContext: promptContext,
            sourceBadges: badges,
            citations: citations,
            instructionHints: memoryInstructionHints()
        )
    }

    private func emptyPack(scopeTitle: String) -> ContextPack {
        ContextPack(
            scopeTitle: scopeTitle,
            promptContext: "",
            sourceBadges: [],
            citations: [],
            instructionHints: memoryInstructionHints()
        )
    }

    // MARK: - Data Fetching

    private func fetchAudioFile(id: UUID) -> AudioFile? {
        let descriptor = FetchDescriptor<AudioFile>()
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.id == id })
    }

    private func fetchAudioFiles(projectID: UUID) -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.projectID == projectID }
    }

    private func fetchRecentAudioFiles(limit: Int) -> [AudioFile] {
        var descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchProject(id: UUID) -> Project? {
        let descriptor = FetchDescriptor<Project>()
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.id == id })
    }

    private func fetchTranscript(for fileID: UUID) -> Transcript? {
        let descriptor = FetchDescriptor<Transcript>()
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.audioFileID == fileID })
    }

    private func fetchMeetingMemo(for fileID: UUID) -> MeetingMemo? {
        let descriptor = FetchDescriptor<MeetingMemo>()
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.audioFileID == fileID })
    }

    private func fetchTodos(projectID: UUID?) -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let todos = (try? modelContext.fetch(descriptor)) ?? []
        if let projectID {
            return todos.filter { $0.projectID == projectID }
        }
        return todos
    }

    private func fetchPrimaryMemoryProfile() -> MemoryProfile? {
        let descriptor = FetchDescriptor<MemoryProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func fetchActiveMemoryFacts() -> [MemoryFact] {
        guard currentMemoryMode != .off else { return [] }

        let disabledIDs = Set(
            (UserDefaults.standard.stringArray(forKey: "disabledMemoryFactIDs") ?? [])
                .compactMap(UUID.init(uuidString:))
        )
        let descriptor = FetchDescriptor<MemoryFact>(
            sortBy: [SortDescriptor(\.confidence, order: .reverse)]
        )

        return ((try? modelContext.fetch(descriptor)) ?? []).filter { !disabledIDs.contains($0.id) }
    }

    // MARK: - Helpers

    private func sourceImage(for sourceType: KnowledgeChunkSourceType) -> String {
        switch sourceType {
        case .summary: return "text.quote"
        case .transcript: return "text.alignleft"
        case .memo: return "square.and.pencil"
        case .todo: return "checklist"
        case .photoOCR: return "photo"
        case .referenceTranscript: return "doc.text"
        }
    }

    private func chunkTitle(sourceType: KnowledgeChunkSourceType, scopeName: String) -> String {
        let label: String
        switch sourceType {
        case .summary: label = "Summary"
        case .transcript: label = "Transcript"
        case .memo: label = "Memo"
        case .todo: label = "Todo"
        case .photoOCR: label = "Photo OCR"
        case .referenceTranscript: label = "Reference"
        }
        return "\(scopeName) / \(label)"
    }

    private func makeContextSource(
        type: String,
        title: String,
        body: String?,
        systemImage: String,
        shortLabel: String
    ) -> ContextSource? {
        guard let body else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ContextSource(
            type: type,
            title: title,
            body: trimmed,
            systemImage: systemImage,
            shortLabel: shortLabel
        )
    }

    private func uniqueBadges(from badges: [SourceBadge]) -> [SourceBadge] {
        var seen: Set<String> = []
        return badges.filter { badge in
            seen.insert(badge.id).inserted
        }
    }

    private func truncate(_ text: String, limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }

    private func labeledLine(_ key: String, value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(key): \(trimmed)"
    }
}
