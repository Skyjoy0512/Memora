import SwiftUI

// MARK: - V6 Header ("Ask" + 新しい会話)

extension AskAIView {
    var v6Header: some View {
        HStack {
            Text("Ask")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(V6Color.ink)
            Spacer()
            Button {
                startNewSession()
            } label: {
                Text("＋ 新しい会話")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(V6Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(V6Color.soft, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

// MARK: - V6 Scope Tabs (全体 / プロジェクト / ファイル — underline style, matches File Detail tabs)

extension AskAIView {
    private var projectScopeOption: AskAIScopeOption? {
        availableScopes.first { if case .project = $0.scope { return true } else { return false } }
    }

    private var fileScopeOption: AskAIScopeOption? {
        availableScopes.first { if case .file = $0.scope { return true } else { return false } }
    }

    var v6ScopeTabs: some View {
        HStack(spacing: 24) {
            v6ScopeTab(title: "全体", scope: .global)
            if let projectScopeOption {
                v6ScopeTab(title: "プロジェクト", scope: projectScopeOption.scope)
            }
            if let fileScopeOption {
                v6ScopeTab(title: "ファイル", scope: fileScopeOption.scope)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V6Color.soft).frame(height: 1)
        }
    }

    private func v6ScopeTab(title: String, scope: ChatScope) -> some View {
        let isActive = scopeKey(for: activeScope) == scopeKey(for: scope)
        return Button {
            activeScope = scope
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? V6Color.ink : V6Color.quiet)
                .padding(.bottom, 9)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isActive ? V6Color.ink : .clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    var v6ScopeCaption: some View {
        Text(scopeDescription)
            .font(.system(size: 11.5))
            .foregroundStyle(V6Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}

// MARK: - Chat Scroll View

extension AskAIView {
    var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        v6SuggestionsList
                    }

                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            onTaskify: { taskifyMessage($0) },
                            onOpenSource: { onOpenSourceTitle?($0.title) }
                        )
                    }

                    if isLoading {
                        v6SendingIndicator
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                MemoraAnimation.animate(reduceMotion) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isLoading) { _, _ in
                MemoraAnimation.animate(reduceMotion) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var v6SendingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(V6Color.neutralBorder).frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Empty State + Suggested Prompts

extension AskAIView {
    var v6SuggestionsList: some View {
        VStack(spacing: 10) {
            Text("気になることを聞いてみましょう")
                .font(.system(size: 13))
                .lineSpacing(6)
                .foregroundStyle(V6Color.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)

            ForEach(suggestions, id: \.self) { text in
                Button {
                    sendMessage(text)
                } label: {
                    Text(text)
                        .font(.system(size: 13.5))
                        .foregroundStyle(V6Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(V6Color.faint, in: RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Input Bar

extension AskAIView {
    var v6InputBar: some View {
        VStack(spacing: 10) {
            TextField("メッセージを入力", text: $inputText, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit { sendMessage(inputText) }

            HStack {
                Image(systemName: "paperclip")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V6Color.quiet)
                Spacer()
                Button {
                    sendMessage(inputText)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(v6SendButtonColor, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(V6Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous)
                .stroke(Color(hex: "ECECEC"), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var v6SendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
            ? V6Color.neutralBorder
            : V6Color.ink
    }
}
