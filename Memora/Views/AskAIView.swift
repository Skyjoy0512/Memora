import SwiftUI
import SwiftData

// MARK: - Ask AI View
struct AskAIView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""

    let scope: ChatScope

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false

    // MARK: - Computed
    private var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    private var currentAPIKey: String {
        switch currentProvider {
        case .openai: return apiKeyOpenAI
        case .gemini: return apiKeyGemini
        case .deepseek: return apiKeyDeepSeek
        }
    }

    private var scopeDescription: String {
        switch scope {
        case .file: return "このファイルについて質問"
        case .project: return "プロジェクトについて質問"
        case .global: return "何でも質問してください"
        }
    }

    private var suggestions: [String] {
        switch scope {
        case .file: return ["要点をまとめて", "決定事項を確認", "次のアクションは?", "参加者の発言を分析"]
        case .project: return ["このプロジェクトについて質問"]
        case .global: return ["何か改善点は?"]
        }
    }

    private func fetchTranscript(for fileId: UUID) -> String? {
        let descriptor = FetchDescriptor<Transcript>()
        let transcripts = try? modelContext.fetch(descriptor)
        return transcripts?.first(where: { $0.audioFileID == fileId })?.text
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                chatScrollView
                thinkingIndicator
                inputBar
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(MemoraColor.accentBlue)
                .font(.system(size: 20))
            Text(scopeDescription)
                .font(MemoraTypography.body)
                .foregroundStyle(MemoraColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.top, MemoraSpacing.md)
        .background(MemoraColor.divider.opacity(0.03))
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: MemoraSpacing.lg) {
                    if messages.isEmpty {
                        suggestionsGrid
                    }
                    messagesList
                    Color.clear.id("bottom")
                }
            }
            .onChange(of: messages.count) { _, _ in
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
                    .cornerRadius(MemoraRadius.md)
                }
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.vertical, MemoraSpacing.xl)
    }

    private var messagesList: some View {
        ForEach(messages) { msg in
            MessageBubbleView(message: msg)
        }
        .padding(.horizontal, MemoraSpacing.lg)
    }

    @ViewBuilder
    private var thinkingIndicator: some View {
        if isLoading {
            HStack(spacing: MemoraSpacing.sm) {
                Text("Thinking...")
                    .font(MemoraTypography.body)
                    .foregroundStyle(MemoraColor.textSecondary)
                ThinkingDots()
            }
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.bottom, MemoraSpacing.sm)
        }
    }

    private var inputBar: some View {
        HStack(spacing: MemoraSpacing.sm) {
            TextField("質問を入力...", text: $inputText)
                .font(MemoraTypography.body)
                .textFieldStyle(.roundedBorder)
                .onSubmit { sendMessage(inputText) }

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.bottom, MemoraSpacing.md)
    }

    private var sendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespaces).isEmpty
            ? MemoraColor.textTertiary
            : MemoraColor.accentPrimary
    }

    // MARK: - Actions
    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: trimmed))
        inputText = ""
        isLoading = true

        Task { @MainActor in
            await generateAIResponse(for: trimmed)
        }
    }

    @MainActor
    private func generateAIResponse(for userMessage: String) {
        let service = AIService()
        service.setProvider(currentProvider)

        Task {
            do {
                let apiKey = currentAPIKey
                guard !apiKey.isEmpty else {
                    isLoading = false
                    messages.append(ChatMessage(role: .assistant, content: "APIキーが設定されていません。設定画面からAPIキーを設定してください。"))
                    return
                }
                try await service.configure(apiKey: apiKey)

                var transcriptContext = ""
                if case .file(let fileId) = scope {
                    transcriptContext = fetchTranscript(for: fileId) ?? ""
                }

                let prompt: String
                if transcriptContext.isEmpty {
                    prompt = "質問に答えてください。\n\n質問: \(userMessage)"
                } else {
                    prompt = """
以下の文字起こしに基づいて質問に答えてください。
簡潔に日本語で答えてください。

文字起こし:
\(transcriptContext)

質問: \(userMessage)
"""
                }
                let result = try await service.summarize(transcript: prompt)
                isLoading = false
                messages.append(ChatMessage(role: .assistant, content: result.summary))
            } catch {
                isLoading = false
                messages.append(ChatMessage(role: .assistant, content: "エラーが発生しました: \(error.localizedDescription)"))
            }
        }
    }
}

// MARK: - Message Bubble
private struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if !isUser { Spacer() }
            VStack(alignment: isUser ? .trailing : .leading, spacing: MemoraSpacing.xxxs) {
                Text(message.content)
                    .font(MemoraTypography.body)
                    .foregroundStyle(isUser ? .white : MemoraColor.textPrimary)
                    .lineSpacing(4)
            }
            .padding(MemoraSpacing.md)
            .background(isUser ? MemoraColor.accentPrimary : MemoraColor.divider.opacity(0.05))
            .cornerRadius(MemoraRadius.md)
            .frame(maxWidth: isUser ? 280 : .infinity, alignment: isUser ? .trailing : .leading)
            .id(message.id.uuidString)
            if isUser { Spacer() }
        }
    }
}

// MARK: - Thinking Dots
private struct ThinkingDots: View {
    @State private var dotCount = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == dotCount ? MemoraColor.accentBlue : MemoraColor.divider)
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
