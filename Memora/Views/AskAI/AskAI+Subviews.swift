import SwiftUI

// MARK: - Header View

extension AskAIView {
    var headerView: some View {
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
}

// MARK: - Scope Selector

extension AskAIView {
    var scopeSelector: some View {
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
}

// MARK: - Session Strip

extension AskAIView {
    var sessionStrip: some View {
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

// MARK: - Suggestions Grid

extension AskAIView {
    var suggestionsGrid: some View {
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
}

// MARK: - Thinking Indicator

extension AskAIView {
    @ViewBuilder
    var thinkingIndicator: some View {
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
}

// MARK: - Input Bar

extension AskAIView {
    var inputBar: some View {
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
}
