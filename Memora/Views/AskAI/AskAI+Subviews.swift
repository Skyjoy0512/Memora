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
            NothingTabPicker(selection: $activeScope, options: availableScopes.map {
                .init(value: $0.scope, label: $0.title)
            }, size: .compact)
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.vertical, MemoraSpacing.xs)
        }
    }
}

// MARK: - Session Strip (ChatGPT Token/Chip group)

extension AskAIView {
    var sessionStrip: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            HStack {
                Text("Session")
                    .font(MemoraTypography.chatLabel)
                    .foregroundStyle(MemoraColor.textSecondary)

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count)件")
                        .font(MemoraTypography.chatToken)
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
                            .font(MemoraTypography.chatToken)
                            .foregroundStyle(MemoraColor.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(MemoraColor.interactiveSecondaryBorder.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(sessions) { session in
                        Button {
                            activeSessionID = session.id
                            loadMessages(for: session)
                        } label: {
                            Text(session.title)
                                .font(MemoraTypography.chatToken)
                                .foregroundStyle(activeSessionID == session.id ? MemoraColor.interactivePrimaryLabel : MemoraColor.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(activeSessionID == session.id ? MemoraColor.interactivePrimary : Color.clear)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(activeSessionID == session.id ? Color.clear : MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
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
}

// MARK: - Chat Scroll View

extension AskAIView {
    var chatScrollView: some View {
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
        VStack(spacing: MemoraSpacing.xs) {
            ForEach(suggestions, id: \.self) { text in
                Button {
                    inputText = text
                    sendMessage(text)
                } label: {
                    HStack(spacing: MemoraSpacing.xs) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 16))
                            .foregroundStyle(MemoraColor.textTertiary)
                        Text(text)
                            .font(MemoraTypography.chatToken)
                            .foregroundStyle(MemoraColor.textPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.pill, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MemoraRadius.pill, style: .continuous)
                            .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.top, MemoraSpacing.lg)
    }
}

// MARK: - Thinking Indicator

extension AskAIView {
    @ViewBuilder
    var thinkingIndicator: some View {
        if isLoading {
            HStack(spacing: MemoraSpacing.sm) {
                Text(currentProvider == .local ? "Warming up local model..." : "Thinking...")
                    .font(MemoraTypography.chatBody)
                    .foregroundStyle(MemoraColor.textSecondary)
                ThinkingDots()
                Spacer()
            }
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.bottom, MemoraSpacing.sm)
        }
    }
}

// MARK: - Input Bar (ChatGPT-aligned)

extension AskAIView {
    var inputBar: some View {
        HStack(spacing: MemoraSpacing.sm) {
            TextField("質問を入力...", text: $inputText, axis: .vertical)
                .font(MemoraTypography.chatBody)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage(inputText)
                }

            Text(currentProvider.rawValue)
                .font(MemoraTypography.chatToken)
                .foregroundStyle(MemoraColor.textTertiary)
                .padding(.horizontal, MemoraSpacing.xs)
                .padding(.vertical, 6)
                .background(MemoraColor.interactiveSecondaryBorder.opacity(0.15))
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
        .background(MemoraColor.surfaceCard)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var sendButtonColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
            ? MemoraColor.textTertiary
            : MemoraColor.interactivePrimary
    }
}
