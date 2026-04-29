import SwiftUI
import SwiftData

// MARK: - AskAI Action Methods

extension AskAIView {
    func reloadScopeOptions() {
        availableScopes = makeAvailableScopes(from: scope)
    }

    func reloadForActiveScope() {
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

    func startNewSession() {
        activeSessionID = nil
        messages = []
        infoMessage = "新しい会話を開始します。"
    }

    func sendMessage(_ text: String) {
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
    func generateAIResponse(for userMessage: String, session: AskAISession) async {
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

    func createSession(titleSeed: String, scope: ChatScope) -> AskAISession {
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

    func persistMessage(_ message: AskAIConversationMessage, sessionID: UUID) {
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

    func loadMessages(for session: AskAISession) {
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
}
