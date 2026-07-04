import SwiftUI

// MARK: - AI Model Type

/// AIモデル種別 — プロバイダ情報を含む
enum AIModelType: String, CaseIterable {
    case chatGPT5
    case chatGPT5Thinking
    case chatGPT5Mini
    case chatGPT4o
    case claudeOpus46
    case gemini31Pro

    var displayName: String {
        switch self {
        case .chatGPT5:          return "ChatGPT-5"
        case .chatGPT5Thinking:  return "ChatGPT-5 Thinking"
        case .chatGPT5Mini:        return "ChatGPT-5 mini"
        case .chatGPT4o:         return "ChatGPT-4o"
        case .claudeOpus46:     return "Claude Opus 4.6"
        case .gemini31Pro:      return "Gemini-3.1-Pro"
        }
    }

    var provider: String {
        switch self {
        case .chatGPT5, .chatGPT5Thinking, .chatGPT5Mini, .chatGPT4o:
            return "OpenAI"
        case .claudeOpus46:
            return "Anthropic"
        case .gemini31Pro:
            return "Google"
        }
    }

    var providerInitial: String {
        switch self {
        case .chatGPT5, .chatGPT5Thinking, .chatGPT5Mini, .chatGPT4o:
            return "O"
        case .claudeOpus46:
            return "A"
        case .gemini31Pro:
            return "G"
        }
    }

    var providerColor: Color {
        switch self {
        case .chatGPT5, .chatGPT5Thinking, .chatGPT5Mini, .chatGPT4o:
            return Color(hex: "10A37F")
        case .claudeOpus46:
            return Color(hex: "D97757")
        case .gemini31Pro:
            return Color(hex: "4285F4")
        }
    }

    var isBeta: Bool {
        self == .gemini31Pro
    }
}

// MARK: - AI Model Select Sheet

/// AIモデル選択ボトムシート — モデル一覧表示 + チェックマーク選択
struct AIModelSelectSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedModel: AIModelType
    let onStartGeneration: (GenerationConfig) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background overlay — 40% black, tappable to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }

            // Sheet content
            sheetContent
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Sheet Content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color(hex: "A7A7A7"))
                .frame(width: 72, height: 8)
                .padding(.top, 16)
                .padding(.bottom, 20)

            // Title
            Text("AIモデルを選択")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MemoraColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, 16)

            // Model list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AIModelType.allCases, id: \.self) { model in
                        modelRow(model)
                        if model != AIModelType.allCases.last {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
            }

            // Generate button
            generateButton
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .glassSheetBackground()
    }

    // MARK: - Model Row

    private func modelRow(_ model: AIModelType) -> some View {
        let isSelected = selectedModel == model
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedModel = model
            }
        } label: {
            HStack(spacing: 14) {
                // Provider icon circle with initial letter
                ZStack {
                    Circle()
                        .fill(model.providerColor.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Text(model.providerInitial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(model.providerColor)
                }

                // Model info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MemoraColor.textPrimary)

                        if model.isBeta {
                            Text("Beta")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(MemoraColor.accentBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(MemoraColor.accentBlue.opacity(0.1))
                                )
                        }
                    }

                    Text(model.provider)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(MemoraColor.textTertiary)
                }

                Spacer()

                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MemoraColor.accentBlue)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            var config = GenerationConfig()
            onStartGeneration(config)
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresented = false
            }
        } label: {
            Text("生成")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(MemoraColor.interactivePrimary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        AIModelSelectSheet(
            isPresented: .constant(true),
            selectedModel: .constant(.chatGPT5),
            onStartGeneration: { _ in }
        )
    }
}
