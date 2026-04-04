import SwiftUI
import SwiftData

struct AskAIView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = "standard"

    let scope: ChatScope

    @State private var queryService: KnowledgeQueryService?

    @State private var activeScope: ChatScope
    @State private var availableScopes: [AskAIScopeOption] = []
    @State private var sessions: [AskAISession] = []
    @State private var activeSessionID: UUID?
    @State private var messages: [AskAIConversationMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var infoMessage: String?
    @State private var sourceBadges: [AskAISourceBadge] = []

    init(scope: ChatScope) {
        self.scope = scope
        _activeScope = State(initialValue: scope)
    }

    private var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    private var currentAPIKey: String {
        switch currentProvider {
        case .openai:
            return apiKeyOpenAI
        case .gemini:
            return apiKeyGemini
        case .deepseek:
            return apiKeyDeepSeek
        }
    }

    private var activeScopeKey: String {
        scopeKey(for: activeScope)
    }

    private var currentSession: AskAISession? {
        guard let activeSessionID else { return nil }
        return sessions.first { $0.id == activeSessionID }
    }

    private var scopeDescription: String {
        label(for: activeScope)
    }

    private var suggestions: [String] {
        switch activeScope {
        case .file:
            return ["要点をまとめて", "決定事項を確認", "次のアクションは？", "参加者の発言を分析"]
        case .project:
            return ["このプロジェクトの進捗を教えて", "未完了タスクを整理して", "重要な論点をまとめて", "次に確認すべき録音は？"]
        case .global:
            return ["最近の会議の傾向は？", "未完了のタスクを横断で整理して", "重要な決定事項を教えて", "今週の動きを要約して"]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                scopeSelector
                sessionStrip
                chatScrollView
                thinkingIndicator
                inputBar
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("新規") {
                        startNewSession()
                    }
                }
            }
        }
        .task {
            queryService = KnowledgeQueryService(modelContext: modelContext, memoryPrivacyMode: memoryPrivacyMode)
            reloadScopeOptions()
            reloadForActiveScope()
        }
        .onChange(of: activeScopeKey) { _, _ in
            reloadForActiveScope()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(MemoraColor.accentBlue)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(scopeDescription)
                        .font(MemoraTypography.body)
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(currentSession?.title ?? "新しい会話")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(currentProvider.rawValue)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentBlue)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 4)
                    .background(MemoraColor.accentBlue.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !sourceBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MemoraSpacing.xs) {
                        ForEach(sourceBadges) { badge in
                            Label(badge.label, systemImage: badge.systemImage)
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                                .padding(.horizontal, MemoraSpacing.xs)
                                .padding(.vertical, 4)
                                .background(MemoraColor.divider.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.top, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
        .background(MemoraColor.divider.opacity(0.03))
    }

    private var scopeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MemoraSpacing.xs) {
                ForEach(availableScopes) { option in
                    Button {
                        activeScope = option.scope
                    } label: {
                        Text(option.title)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(activeScopeKey == option.id ? .white : MemoraColor.textPrimary)
                            .padding(.horizontal, MemoraSpacing.md)
                            .padding(.vertical, 8)
                            .background(activeScopeKey == option.id ? MemoraColor.accentPrimary : MemoraColor.divider.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.vertical, MemoraSpacing.sm)
        }
    }

    private var sessionStrip: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            HStack {
                Text("Session")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count)件")
                        .font(MemoraTypography.caption2)
                        .foregroundStyle(MemoraColor.textTertiary)
                }
            }
            .padding(.horizontal, MemoraSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MemoraSpacing.xs) {
                    Button {
                        startNewSession()
                    } label: {
                        Label("新規チャット", systemImage: "plus")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentBlue)
                            .padding(.horizontal, MemoraSpacing.sm)
                            .padding(.vertical, 8)
                            .background(MemoraColor.accentBlue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(sessions) { session in
                        Button {
                            activeSessionID = session.id
                            loadMessages(for: session)
                        } label: {
                            Text(session.title)
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(activeSessionID == session.id ? .white : MemoraColor.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, MemoraSpacing.sm)
                                .padding(.vertical, 8)
                                .background(activeSessionID == session.id ? MemoraColor.accentPrimary : MemoraColor.divider.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MemoraSpacing.lg)
            }
        }
        .padding(.bottom, MemoraSpacing.sm)
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: MemoraSpacing.lg) {
                    if messages.isEmpty {
                        suggestionsGrid
                    }

                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.bottom, MemoraSpacing.md)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isLoading) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var suggestionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MemoraSpacing.sm) {
            ForEach(suggestions, id: \.self) { text in
                Button {
                    inputText = text
                    sendMessage(text)
                } label: {
                    HStack(spacing: MemoraSpacing.xs) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(MemoraColor.accentBlue)
                        Text(text)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(MemoraColor.textPrimary)
                            .lineLimit(2)
                    }
                    .padding(MemoraSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MemoraColor.divider.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.top, MemoraSpacing.lg)
    }

    @ViewBuilder
    private var thinkingIndicator: some View {
        if isLoading {
            HStack(spacing: MemoraSpacing.sm) {
                Text("Thinking...")
                    .font(MemoraTypography.body)
                    .foregroundStyle(MemoraColor.textSecondary)
                ThinkingDots()
                Spacer()
            }
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.bottom, MemoraSpacing.sm)
        }
    }

    private var inputBar: some View {
        HStack(spacing: MemoraSpacing.sm) {
            Image(systemName: "paperclip")
                .foregroundStyle(MemoraColor.textTertiary)

            TextField("質問を入力...", text: $inputText, axis: .vertical)
                .font(MemoraTypography.body)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .onSubmit {
                    sendMessage(inputText)
                }

            Text(currentProvider.rawValue)
                .font(MemoraTypography.caption2)
                .foregroundStyle(MemoraColor.textSecondary)
                .padding(.horizontal, MemoraSpacing.xs)
                .padding(.vertical, 6)
                .background(MemoraColor.divider.opacity(0.08))
                .clipShape(Capsule())

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.vertical, MemoraSpacing.md)
        .background(MemoraColor.surfaceSecondary)
    }

    private var sendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
            ? MemoraColor.textTertiary
            : MemoraColor.accentPrimary
    }

    private func reloadScopeOptions() {
        availableScopes = makeAvailableScopes(from: scope)
    }

    private func reloadForActiveScope() {
        if let qs = queryService {
            sourceBadges = qs.buildContext(for: activeScope).sourceBadges.map {
                AskAISourceBadge(id: $0.id, label: $0.label, systemImage: $0.systemImage)
            }
        } else {
            sourceBadges = buildContextPack(for: activeScope).sourceBadges
        }
        let scopedSessions = fetchSessions(for: activeScope)
        sessions = scopedSessions

        if let activeSessionID,
           let selected = scopedSessions.first(where: { $0.id == activeSessionID }) {
            loadMessages(for: selected)
            return
        }

        if let firstSession = scopedSessions.first {
            activeSessionID = firstSession.id
            loadMessages(for: firstSession)
        } else {
            activeSessionID = nil
            messages = []
        }
    }

    private func startNewSession() {
        activeSessionID = nil
        messages = []
        infoMessage = "新しい会話を開始します。"
    }

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        let session = currentSession ?? createSession(titleSeed: trimmed, scope: activeScope)
        let userMessage = AskAIConversationMessage(
            id: UUID(),
            role: .user,
            content: trimmed,
            citations: [],
            createdAt: Date()
        )
        messages.append(userMessage)
        persistMessage(userMessage, sessionID: session.id)

        inputText = ""
        isLoading = true
        infoMessage = nil

        Task { @MainActor in
            await generateAIResponse(for: trimmed, session: session)
        }
    }

    @MainActor
    private func generateAIResponse(for userMessage: String, session: AskAISession) async {
        let service = AIService()
        service.setProvider(currentProvider)

        do {
            let apiKey = currentAPIKey
            guard !apiKey.isEmpty else {
                let message = AskAIConversationMessage(
                    id: UUID(),
                    role: .assistant,
                    content: "APIキーが設定されていません。設定画面からAPIキーを設定してください。",
                    citations: [],
                    createdAt: Date()
                )
                isLoading = false
                messages.append(message)
                persistMessage(message, sessionID: session.id)
                return
            }

            try await service.configure(apiKey: apiKey)

            let qsContext = queryService?.buildContext(for: activeScope)
            let localContext = buildContextPack(for: activeScope)

            sourceBadges = qsContext?.sourceBadges.map {
                AskAISourceBadge(id: $0.id, label: $0.label, systemImage: $0.systemImage)
            } ?? localContext.sourceBadges

            let prompt: String
            if let qs = queryService, let qsContext {
                prompt = qs.makePrompt(userMessage: userMessage, contextPack: qsContext)
            } else {
                prompt = makePrompt(userMessage: userMessage, contextPack: localContext)
            }
            let result = try await service.summarize(transcript: prompt)
            let responseText = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            let citations: [AskAICitation]
            if let qsContext {
                citations = Array(qsContext.citations.map {
                    AskAICitation(id: $0.id, title: $0.title, sourceLabel: $0.sourceLabel, excerpt: $0.excerpt)
                }.prefix(4))
            } else {
                citations = Array(localContext.citations.prefix(4))
            }
            let assistantMessage = AskAIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: responseText.isEmpty ? "回答を生成できませんでした。" : responseText,
                citations: citations,
                createdAt: Date()
            )

            session.updatedAt = Date()
            isLoading = false
            messages.append(assistantMessage)
            persistMessage(assistantMessage, sessionID: session.id)
            try? modelContext.save()
        } catch {
            let message = AskAIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "エラーが発生しました: \(error.localizedDescription)",
                citations: [],
                createdAt: Date()
            )
            isLoading = false
            messages.append(message)
            persistMessage(message, sessionID: session.id)
        }
    }

    private func createSession(titleSeed: String, scope: ChatScope) -> AskAISession {
        let title = makeSessionTitle(from: titleSeed)
        let session = AskAISession(
            scopeType: scopeType(for: scope),
            scopeID: scopeID(for: scope),
            title: title
        )
        modelContext.insert(session)
        try? modelContext.save()

        sessions.insert(session, at: 0)
        activeSessionID = session.id
        return session
    }

    private func persistMessage(_ message: AskAIConversationMessage, sessionID: UUID) {
        let citationsJSON: String?
        if message.citations.isEmpty {
            citationsJSON = nil
        } else if let data = try? JSONEncoder().encode(message.citations) {
            citationsJSON = String(data: data, encoding: .utf8)
        } else {
            citationsJSON = nil
        }

        let record = AskAIMessage(
            id: message.id,
            sessionID: sessionID,
            role: message.role,
            content: message.content,
            citationsJSON: citationsJSON,
            createdAt: message.createdAt
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func loadMessages(for session: AskAISession) {
        let descriptor = FetchDescriptor<AskAIMessage>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let loaded = (try? modelContext.fetch(descriptor)) ?? []
        messages = loaded
            .filter { $0.sessionID == session.id }
            .map {
                AskAIConversationMessage(
                    id: $0.id,
                    role: $0.role,
                    content: $0.content,
                    citations: decodeCitations(from: $0.citationsJSON),
                    createdAt: $0.createdAt
                )
            }
        sourceBadges = buildContextPack(for: activeScope).sourceBadges
        infoMessage = nil
    }

    private func decodeCitations(from json: String?) -> [AskAICitation] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AskAICitation].self, from: data)) ?? []
    }

    private func fetchSessions(for scope: ChatScope) -> [AskAISession] {
        let descriptor = FetchDescriptor<AskAISession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let loaded = (try? modelContext.fetch(descriptor)) ?? []
        return loaded.filter { session in
            session.scopeType == scopeType(for: scope) && session.scopeID == scopeID(for: scope)
        }
    }

    private func buildContextPack(for scope: ChatScope) -> AskAIContextPack {
        switch scope {
        case .file(let fileId):
            return buildFileContext(fileID: fileId)
        case .project(let projectId):
            return buildProjectContext(projectID: projectId)
        case .global:
            return buildGlobalContext()
        }
    }

    private func buildFileContext(fileID: UUID) -> AskAIContextPack {
        guard let file = fetchAudioFile(id: fileID) else {
            return AskAIContextPack(
                scopeTitle: "このファイル",
                promptContext: "",
                sourceBadges: [],
                citations: [],
                instructionHints: memoryInstructionHints()
            )
        }

        let transcript = fetchTranscript(for: file.id)?.text
        let memo = fetchMeetingMemo(for: file.id)?.plainTextCache
        let sources: [AskAIContextSource] = memoryContextSources() + [
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

        return makeContextPack(scopeTitle: file.title, sources: sources)
    }

    private func buildProjectContext(projectID: UUID) -> AskAIContextPack {
        let project = fetchProject(id: projectID)
        let files = fetchAudioFiles(projectID: projectID).prefix(4)
        let todos = fetchTodos(projectID: projectID).prefix(4)

        var sources: [AskAIContextSource] = memoryContextSources()

        for file in files {
            if let summary = file.summary, !summary.isEmpty {
                sources.append(
                    AskAIContextSource(
                        type: "summary",
                        title: "\(file.title) / Summary",
                        body: summary,
                        systemImage: "text.quote",
                        shortLabel: "Summary"
                    )
                )
            } else if let transcript = fetchTranscript(for: file.id)?.text, !transcript.isEmpty {
                sources.append(
                    AskAIContextSource(
                        type: "transcript",
                        title: "\(file.title) / Transcript",
                        body: transcript,
                        systemImage: "text.alignleft",
                        shortLabel: "Transcript"
                    )
                )
            }

            if let memo = fetchMeetingMemo(for: file.id)?.plainTextCache, !memo.isEmpty {
                sources.append(
                    AskAIContextSource(
                        type: "memo",
                        title: "\(file.title) / Memo",
                        body: memo,
                        systemImage: "square.and.pencil",
                        shortLabel: "Memo"
                    )
                )
            }
        }

        if !todos.isEmpty {
            let todoText = todos.map { "• \($0.title)" }.joined(separator: "\n")
            sources.append(
                AskAIContextSource(
                    type: "todo",
                    title: "\(project?.title ?? "Project") / Todo",
                    body: todoText,
                    systemImage: "checklist",
                    shortLabel: "Todo"
                )
            )
        }

        return makeContextPack(scopeTitle: project?.title ?? "このプロジェクト", sources: Array(sources.prefix(6)))
    }

    private func buildGlobalContext() -> AskAIContextPack {
        let files = fetchRecentAudioFiles(limit: 5)
        let todos = fetchTodos(projectID: nil).filter { !$0.isCompleted }.prefix(5)

        var sources: [AskAIContextSource] = memoryContextSources()

        for file in files {
            if let summary = file.summary, !summary.isEmpty {
                sources.append(
                    AskAIContextSource(
                        type: "summary",
                        title: "\(file.title) / Summary",
                        body: summary,
                        systemImage: "text.quote",
                        shortLabel: "Summary"
                    )
                )
            } else if let transcript = fetchTranscript(for: file.id)?.text, !transcript.isEmpty {
                sources.append(
                    AskAIContextSource(
                        type: "transcript",
                        title: "\(file.title) / Transcript",
                        body: transcript,
                        systemImage: "text.alignleft",
                        shortLabel: "Transcript"
                    )
                )
            }
        }

        if !todos.isEmpty {
            let todoText = todos.map { "• \($0.title)" }.joined(separator: "\n")
            sources.append(
                AskAIContextSource(
                    type: "todo",
                    title: "Global / Todo",
                    body: todoText,
                    systemImage: "checklist",
                    shortLabel: "Todo"
                )
            )
        }

        return makeContextPack(scopeTitle: "Memora 全体", sources: Array(sources.prefix(6)))
    }

    private func makeContextPack(scopeTitle: String, sources: [AskAIContextSource]) -> AskAIContextPack {
        let limitedSources = sources.prefix(6)
        let promptContext = limitedSources.map { source in
            "[\(source.title)]\n\(truncate(source.body, limit: 900))"
        }.joined(separator: "\n\n")

        let badges = uniqueBadges(from: limitedSources.map {
            AskAISourceBadge(id: $0.type, label: $0.shortLabel, systemImage: $0.systemImage)
        })

        let citations = limitedSources.map { source in
            AskAICitation(
                id: source.title,
                title: source.title,
                sourceLabel: source.shortLabel,
                excerpt: truncate(source.body, limit: 120)
            )
        }

        return AskAIContextPack(
            scopeTitle: scopeTitle,
            promptContext: promptContext,
            sourceBadges: badges,
            citations: citations,
            instructionHints: memoryInstructionHints()
        )
    }

    private func makePrompt(userMessage: String, contextPack: AskAIContextPack) -> String {
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

    private func memoryContextSources() -> [AskAIContextSource] {
        guard currentMemoryMode != .off else { return [] }

        var sources: [AskAIContextSource] = []

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
        if let preferredLanguage = fetchPrimaryMemoryProfile()?.preferredLanguage,
           !preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hints.append("preferred language: \(preferredLanguage)")
        }
        if let summaryStyle = fetchPrimaryMemoryProfile()?.summaryStyle,
           !summaryStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hints.append("summary style: \(summaryStyle)")
        }
        if let roleLabel = fetchPrimaryMemoryProfile()?.roleLabel,
           !roleLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hints.append("user role: \(roleLabel)")
        }
        return hints
    }

    private func makeProfileMemorySource() -> AskAIContextSource? {
        guard let profile = fetchPrimaryMemoryProfile() else { return nil }

        let entries = [
            labeledMemoryLine("summaryStyle", value: profile.summaryStyle),
            labeledMemoryLine("preferredLanguage", value: profile.preferredLanguage),
            labeledMemoryLine("roleLabel", value: profile.roleLabel),
            labeledMemoryLine("glossary", value: profile.glossaryJSON)
        ].compactMap { $0 }

        guard !entries.isEmpty else { return nil }

        return AskAIContextSource(
            type: "memory-profile",
            title: "Approved Memory / Profile",
            body: entries.joined(separator: "\n"),
            systemImage: "brain.head.profile",
            shortLabel: "Memory"
        )
    }

    private func makeFactsMemorySource() -> AskAIContextSource? {
        let activeFacts = fetchActiveMemoryFacts()
        guard !activeFacts.isEmpty else { return nil }

        let body = activeFacts
            .prefix(6)
            .map { fact in
                let confidence = Int(fact.confidence * 100)
                return "\(fact.key): \(fact.value) (\(fact.source), \(confidence)%)"
            }
            .joined(separator: "\n")

        return AskAIContextSource(
            type: "memory-facts",
            title: "Approved Memory / Facts",
            body: body,
            systemImage: "brain",
            shortLabel: "Memory"
        )
    }

    private func makeAvailableScopes(from initialScope: ChatScope) -> [AskAIScopeOption] {
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
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return Array(((try? modelContext.fetch(descriptor)) ?? []).prefix(limit))
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

    private var currentMemoryMode: AskAIMemoryPrivacyMode {
        AskAIMemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
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

    private func labeledMemoryLine(_ key: String, value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(key): \(trimmed)"
    }

    private func makeContextSource(
        type: String,
        title: String,
        body: String?,
        systemImage: String,
        shortLabel: String
    ) -> AskAIContextSource? {
        guard let body else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return AskAIContextSource(
            type: type,
            title: title,
            body: trimmed,
            systemImage: systemImage,
            shortLabel: shortLabel
        )
    }

    private func uniqueBadges(from badges: [AskAISourceBadge]) -> [AskAISourceBadge] {
        var seen: Set<String> = []
        return badges.filter { badge in
            seen.insert(badge.id).inserted
        }
    }

    private func truncate(_ text: String, limit: Int) -> String {
        if text.count <= limit {
            return text
        }
        return String(text.prefix(limit)) + "…"
    }

    private func makeSessionTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Chat" : String(trimmed.prefix(24))
    }

    private func label(for scope: ChatScope) -> String {
        switch scope {
        case .file(let fileId):
            return "\(fetchAudioFile(id: fileId)?.title ?? "このファイル") について質問"
        case .project(let projectId):
            return "\(fetchProject(id: projectId)?.title ?? "このプロジェクト") について質問"
        case .global:
            return "Memora 全体について質問"
        }
    }

    private func scopeKey(for scope: ChatScope) -> String {
        switch scope {
        case .file(let fileId):
            return "file-\(fileId.uuidString)"
        case .project(let projectId):
            return "project-\(projectId.uuidString)"
        case .global:
            return "global"
        }
    }

    private func scopeType(for scope: ChatScope) -> AskAIScopeType {
        switch scope {
        case .file:
            return .file
        case .project:
            return .project
        case .global:
            return .global
        }
    }

    private func scopeID(for scope: ChatScope) -> UUID? {
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

private struct MessageBubbleView: View {
    let message: AskAIConversationMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if !isUser { Spacer(minLength: 0) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: MemoraSpacing.xs) {
                Text(message.content)
                    .font(MemoraTypography.body)
                    .foregroundStyle(isUser ? .white : MemoraColor.textPrimary)
                    .lineSpacing(4)
                    .padding(MemoraSpacing.md)
                    .background(isUser ? MemoraColor.accentPrimary : MemoraColor.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))

                if !message.citations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MemoraSpacing.xs) {
                            ForEach(message.citations) { citation in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(citation.sourceLabel)
                                        .font(MemoraTypography.caption2)
                                        .foregroundStyle(MemoraColor.accentBlue)
                                    Text(citation.title)
                                        .font(MemoraTypography.caption2)
                                        .foregroundStyle(MemoraColor.textSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, MemoraSpacing.xs)
                                .padding(.vertical, 6)
                                .background(MemoraColor.divider.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: isUser ? 300 : .infinity, alignment: isUser ? .trailing : .leading)

            if isUser { Spacer(minLength: 0) }
        }
        .padding(.horizontal, MemoraSpacing.lg)
    }
}

private struct ThinkingDots: View {
    @State private var dotCount = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == dotCount ? MemoraColor.accentBlue : MemoraColor.divider)
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dotCount = (dotCount + 1) % 3
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

private struct AskAIScopeOption: Identifiable, Hashable {
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

private struct AskAIConversationMessage: Identifiable, Hashable {
    let id: UUID
    let role: AskAIMessageRole
    let content: String
    let citations: [AskAICitation]
    let createdAt: Date
}

private struct AskAICitation: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let sourceLabel: String
    let excerpt: String
}

private struct AskAISourceBadge: Hashable, Identifiable {
    let id: String
    let label: String
    let systemImage: String
}

private struct AskAIContextSource {
    let type: String
    let title: String
    let body: String
    let systemImage: String
    let shortLabel: String
}

private struct AskAIContextPack {
    let scopeTitle: String
    let promptContext: String
    let sourceBadges: [AskAISourceBadge]
    let citations: [AskAICitation]
    let instructionHints: [String]
}

private enum AskAIMemoryPrivacyMode: String {
    case standard
    case paused
    case off
}
