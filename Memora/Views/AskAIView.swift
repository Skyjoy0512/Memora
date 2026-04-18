import SwiftUI
import SwiftData

struct AskAIView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
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
            return KeychainService.load(key: .apiKeyOpenAI)
        case .gemini:
            return KeychainService.load(key: .apiKeyGemini)
        case .deepseek:
            return KeychainService.load(key: .apiKeyDeepSeek)
        case .local:
            return "" // Local プロバイダーは API キー不要
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
                    .foregroundStyle(MemoraColor.accentNothing)
                    .font(.title3)
                    .nothingGlow(.subtle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(scopeDescription)
                        .font(MemoraTypography.phiBody)
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(currentSession?.title ?? "新しい会話")
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(currentProvider.rawValue)
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.accentNothing)
                    .padding(.horizontal, MemoraSpacing.sm)
                    .padding(.vertical, MemoraSpacing.xxxs)
                    .background(MemoraColor.accentNothingSubtle)
                    .clipShape(Capsule())
            }

            if !sourceBadges.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: MemoraSpacing.xs) {
                        ForEach(sourceBadges) { badge in
                            Label(badge.label, systemImage: badge.systemImage)
                                .font(MemoraTypography.phiCaption)
                                .foregroundStyle(MemoraColor.textSecondary)
                                .padding(.horizontal, MemoraSpacing.sm)
                                .padding(.vertical, MemoraSpacing.xxxs)
                                .glassCard(.init(cornerRadius: MemoraRadius.pill, accentTint: false, glow: false))
                        }
                    }
                }
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.top, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
        .glassCard(.init(cornerRadius: 0, accentTint: false, glow: false))
        .nothingDotMatrix()
    }

    private var scopeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MemoraSpacing.xs) {
                ForEach(availableScopes) { option in
                    Button {
                        activeScope = option.scope
                    } label: {
                        Text(option.title)
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(activeScopeKey == option.id ? .white : MemoraColor.textPrimary)
                            .padding(.horizontal, MemoraSpacing.md)
                            .padding(.vertical, MemoraSpacing.xxs)
                            .background(activeScopeKey == option.id ? MemoraColor.accentNothing : Color.clear)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(activeScopeKey == option.id ? Color.clear : MemoraColor.divider, lineWidth: 0.5)
                            }
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
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count)件")
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.textTertiary)
                }
            }
            .padding(.horizontal, MemoraSpacing.lg)

            ScrollView(.horizontal) {
                HStack(spacing: MemoraSpacing.xs) {
                    Button {
                        startNewSession()
                    } label: {
                        Label("新規チャット", systemImage: "plus")
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(MemoraColor.accentNothing)
                            .padding(.horizontal, MemoraSpacing.sm)
                            .padding(.vertical, MemoraSpacing.xxs)
                            .background(MemoraColor.accentNothingSubtle)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(sessions) { session in
                        Button {
                            activeSessionID = session.id
                            loadMessages(for: session)
                        } label: {
                            Text(session.title)
                                .font(MemoraTypography.phiCaption)
                                .foregroundStyle(activeSessionID == session.id ? .white : MemoraColor.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, MemoraSpacing.sm)
                                .padding(.vertical, MemoraSpacing.xxs)
                                .background(activeSessionID == session.id ? MemoraColor.accentNothing : Color.clear)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(activeSessionID == session.id ? Color.clear : MemoraColor.divider, lineWidth: 0.5)
                                }
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
            .scrollDismissesKeyboard(.interactively)
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
                            .foregroundStyle(MemoraColor.accentNothing)
                        Text(text)
                            .font(MemoraTypography.phiBody)
                            .foregroundStyle(MemoraColor.textPrimary)
                            .lineLimit(2)
                    }
                    .padding(MemoraSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(.default)
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
                Text(currentProvider == .local ? "Warming up local model..." : "Thinking...")
                    .font(MemoraTypography.phiBody)
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
                .font(MemoraTypography.phiBody)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage(inputText)
                }

            Text(currentProvider.rawValue)
                .font(MemoraTypography.phiCaption)
                .foregroundStyle(MemoraColor.textSecondary)
                .padding(.horizontal, MemoraSpacing.xs)
                .padding(.vertical, 6)
                .background(MemoraColor.divider.opacity(0.08))
                .clipShape(Capsule())

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.vertical, MemoraSpacing.md)
        .glassCard(.init(cornerRadius: 0, accentTint: false, glow: false, dotMatrix: false))
    }

    private var sendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
            ? MemoraColor.textTertiary
            : MemoraColor.accentNothing
    }

    private func reloadScopeOptions() {
        availableScopes = makeAvailableScopes(from: scope)
    }

    private func reloadForActiveScope() {
        if let qs = queryService {
            sourceBadges = qs.buildContext(for: activeScope).sourceBadges.map {
                AskAISourceBadge(id: $0.id, label: $0.label, systemImage: $0.systemImage)
            }
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
            createdAt: .now
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
        guard let qs = queryService else {
            let message = AskAIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "サービスが初期化されていません。画面を開き直してください。",
                citations: [],
                createdAt: .now
            )
            isLoading = false
            messages.append(message)
            persistMessage(message, sessionID: session.id)
            return
        }

        // Local プロバイダー以外では API キーをチェック
        if currentProvider != .local {
            let apiKey = currentAPIKey
            guard !apiKey.isEmpty else {
                let message = AskAIConversationMessage(
                    id: UUID(),
                    role: .assistant,
                    content: "APIキーが設定されていません。設定画面からAPIキーを設定してください。",
                    citations: [],
                    createdAt: .now
                )
                isLoading = false
                messages.append(message)
                persistMessage(message, sessionID: session.id)
                return
            }
        } else if !LocalLLMProvider.isAvailable && !Gemma4ExperimentalProvider.isReady {
            let message = AskAIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "この端末では On-Device AI が利用できません。設定画面からプロバイダーを変更してください。",
                citations: [],
                createdAt: .now
            )
            isLoading = false
            messages.append(message)
            persistMessage(message, sessionID: session.id)
            return
        }

        let service = AIService()
        service.setProvider(currentProvider)

        do {
            // Local プロバイダーは空文字列で configure する
            try await service.configure(apiKey: currentAPIKey)

            let contextPack = qs.buildContext(for: activeScope, query: userMessage)

            sourceBadges = contextPack.sourceBadges.map {
                AskAISourceBadge(id: $0.id, label: $0.label, systemImage: $0.systemImage)
            }

            let prompt = qs.makePrompt(userMessage: userMessage, contextPack: contextPack)

            let responseText: String
            if currentProvider == .local {
                // Local プロバイダーは generate を直接使用（構造化出力ではなく自由テキスト）
                responseText = try await service.generate(prompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let result = try await service.summarize(transcript: prompt)
                responseText = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let citations = Array(contextPack.citations.map {
                AskAICitation(id: $0.id, title: $0.title, sourceLabel: $0.sourceLabel, excerpt: $0.excerpt)
            }.prefix(4))

            let assistantMessage = AskAIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: responseText.isEmpty ? "回答を生成できませんでした。" : responseText,
                citations: citations,
                createdAt: .now
            )

            session.updatedAt = Date()
            isLoading = false
            messages.append(assistantMessage)
            persistMessage(assistantMessage, sessionID: session.id)
            try? modelContext.save()
        } catch {
            print("[AskAIView] AI response generation failed: \(error.localizedDescription)")
            let message = AskAIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "回答の生成に失敗しました。もう一度お試しください。",
                citations: [],
                createdAt: .now
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
        if let qs = queryService {
            sourceBadges = qs.buildContext(for: activeScope).sourceBadges.map {
                AskAISourceBadge(id: $0.id, label: $0.label, systemImage: $0.systemImage)
            }
        }
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
        var descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchProject(id: UUID) -> Project? {
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
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
