import SwiftUI
import SwiftData

struct AskAIView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = "standard"

    let scope: ChatScope
    var onOpenSourceTitle: ((String) -> Void)?

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

    init(scope: ChatScope, initialMessage: String? = nil, onOpenSourceTitle: ((String) -> Void)? = nil) {
        self.scope = scope
        self.onOpenSourceTitle = onOpenSourceTitle
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
        VStack(spacing: 0) {
            v6Header
            v6ScopeTabs
            v6ScopeCaption
            chatScrollView
        }
        .safeAreaInset(edge: .bottom) {
            v6InputBar
        }
        .background(V6Color.white)
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
