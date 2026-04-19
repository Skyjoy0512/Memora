import SwiftUI
import SwiftData

struct AskAIView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    init(scope: ChatScope, initialMessage: String? = nil) {
        self.scope = scope
        _activeScope = State(initialValue: scope)
        if let msg = initialMessage, !msg.isEmpty {
            _pendingMessage = State(initialValue: msg)
        }
    }

    @State private var pendingMessage: String?

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
            if let msg = pendingMessage {
                pendingMessage = nil
                sendMessage(msg)
            }
        }
        .onChange(of: activeScopeKey) { _, _ in
            reloadForActiveScope()
        }
    }
}
