import SwiftUI
import SwiftData

struct AskAIView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = "standard"

    let scope: ChatScope

    @State var queryService: KnowledgeQueryService?
    @State var activeScope: ChatScope
    @State var availableScopes: [AskAIScopeOption] = []
    @State var sessions: [AskAISession] = []
    @State var activeSessionID: UUID?
    @State var messages: [AskAIConversationMessage] = []
    @State var inputText = ""
    @State var isLoading = false
    @State var infoMessage: String?
    @State var sourceBadges: [AskAISourceBadge] = []
    @State var pendingMessage: String?

    init(scope: ChatScope, initialMessage: String? = nil) {
        self.scope = scope
        _activeScope = State(initialValue: scope)
        if let msg = initialMessage, !msg.isEmpty {
            _pendingMessage = State(initialValue: msg)
        }
    }

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentAPIKey: String {
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
