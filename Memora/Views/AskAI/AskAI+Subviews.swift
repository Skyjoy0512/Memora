import SwiftUI

// MARK: - Header View (ChatGPT-aligned minimal header)

extension AskAIView {
    var headerView: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(MemoraColor.textTertiary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(scopeDescription)
                        .font(MemoraTypography.chatBody)
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(currentSession?.title ?? "新しい会話")
                        .font(MemoraTypography.chatToken)
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                Spacer()

                Text(currentProvider.rawValue)
                    .font(MemoraTypography.chatToken)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MemoraColor.interactiveSecondaryBorder.opacity(0.3))
                    .clipShape(Capsule())
            }

            if !sourceBadges.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: MemoraSpacing.xs) {
                        ForEach(sourceBadges) { badge in
                            Label(badge.label, systemImage: badge.systemImage)
                                .font(MemoraTypography.chatToken)
                                .foregroundStyle(MemoraColor.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(MemoraColor.interactiveHoverBg)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
                                }
                        }
                    }
                }
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(MemoraTypography.chatToken)
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.top, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
    }
}

// MARK: - Scope Selector (ChatGPT SegmentedControl pill)

extension AskAIView {
    var scopeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(availableScopes) { option in
                    Button {
                        activeScope = option.scope
                    } label: {
                        Text(option.title)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(activeScope == option.scope ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Session Strip (ChatGPT Token/Chip group)

extension AskAIView {
    var sessionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentSession?.title ?? "新しい会話")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count)件")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button {
                        startNewSession()
                    } label: {
                        Label("新規チャット", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)

                    ForEach(sessions) { session in
                        Button {
                            activeSessionID = session.id
                            loadMessages(for: session)
                        } label: {
                            Text(session.title)
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(activeSessionID == session.id ? .accentColor : .secondary)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Chat Scroll View

extension AskAIView {
    var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
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
}

// MARK: - Suggestions Grid (ChatGPT Token/Chip group)

extension AskAIView {
    var suggestionsGrid: some View {
        VStack(spacing: 8) {
            ForEach(suggestions, id: \.self) { text in
                Button {
                    inputText = text
                    sendMessage(text)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.secondary)
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: - Thinking Indicator

extension AskAIView {
    @ViewBuilder
    var thinkingIndicator: some View {
        if isLoading {
            HStack(spacing: 12) {
                Text(currentProvider == .local ? "Warming up local model..." : "Thinking...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ThinkingDots()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Input Bar (ChatGPT-aligned)

extension AskAIView {
    var inputBar: some View {
        HStack(spacing: 10) {
            TextField("質問を入力...", text: $inputText, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage(inputText)
                }

            Text(currentProvider.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .liquidGlass(cornerRadius: 22, opacity: 0.28, shadowRadius: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var sendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
            ? Color.secondary
            : Color.accentColor
    }
}
