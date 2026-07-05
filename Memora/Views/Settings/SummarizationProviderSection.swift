import SwiftUI

// MARK: - Summarization Provider Section

/// 要約専用のプロバイダ選択。
/// 文字起こしプロバイダとは独立して選択できる。
struct SummarizationProviderSection: View {
    @Bindable var state: SettingsState
    @AppStorage("summarizationProvider") var summarizationProvider: String = "Gemini"

    var body: some View {
        Section {
            Picker("要約プロバイダ", selection: $state.summarizationProvider) {
                ForEach(AIProvider.allCases) { provider in
                    HStack {
                        Text(provider.rawValue)
                            .tag(provider.rawValue)

                        Spacer()

                        if provider == state.currentSummarizationProvider {
                            Image(systemName: "checkmark")
                                .foregroundStyle(MemoraColor.textSecondary)
                        }

                        if provider == .local {
                            Text(LocalLLMProvider.isAvailable ? "On-Device" : "未対応")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(LocalLLMProvider.isAvailable ? MemoraColor.accentGreen : .secondary)
                        }
                    }
                }
            }
            .pickerStyle(.inline)

            // コスト情報
            VStack(alignment: .leading, spacing: 4) {
                Text("料金目安（参考）:")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                summarizationCostInfo(for: state.currentSummarizationProvider)
            }
            .padding(.vertical, MemoraSpacing.xxxs)

            // Gemini 無料枠の学習利用警告
            if state.currentSummarizationProvider == .gemini {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: MemoraSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(MemoraColor.accentRed)
                        Text("Google の AI 改善に利用される可能性があります")
                            .font(MemoraTypography.caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(MemoraColor.accentRed)
                    }
                    Text("機微な内容の要約には使用しないでください。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }

            // 2系統の説明
            VStack(alignment: .leading, spacing: 8) {
                Text("要約は2系統から選べます:")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: MemoraSpacing.xs) {
                    Text("🆓")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("無料系統")
                            .font(MemoraTypography.caption1)
                            .fontWeight(.semibold)
                        Text("Gemini / DeepSeek / オンデバイス。低コストだが品質は標準的。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: MemoraSpacing.xs) {
                    Text("💎")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("高品質系統")
                            .font(MemoraTypography.caption1)
                            .fontWeight(.semibold)
                        Text("OpenAI (GPT) 。精度重視・ビジネス用途向け。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        } header: {
            GlassSectionHeader(title: "要約プロバイダ選択", icon: "text.bubble")
        }
    }
}

// MARK: - Summarization Cost Info Helper

private func summarizationCostInfo(for provider: AIProvider) -> some View {
    Group {
        switch provider {
        case .openai:
            VStack(alignment: .leading, spacing: 2) {
                Text("• 要約: $0.00015 / 1K tokens (GPT-5)")
                Text("• 高精度。ビジネス文書・会議録に最適。")
            }
            .font(MemoraTypography.caption1)
            .foregroundStyle(.secondary)

        case .gemini:
            VStack(alignment: .leading, spacing: 2) {
                Text("• 要約: $0.000075 / 1K tokens")
                Text("• 無料枠 1,500 リクエスト/日。コスト重視に最適。")
            }
            .font(MemoraTypography.caption1)
            .foregroundStyle(.secondary)

        case .deepseek:
            VStack(alignment: .leading, spacing: 2) {
                Text("• 要約: $0.00014 / 1K tokens")
                Text("• 低コスト。中国語・日本語に強い。")
            }
            .font(MemoraTypography.caption1)
            .foregroundStyle(.secondary)

        case .local:
            VStack(alignment: .leading, spacing: 2) {
                Text("• 無料・オフライン対応")
                Text("• iOS 26 Foundation Models を使用")
            }
            .font(MemoraTypography.caption1)
            .foregroundStyle(MemoraColor.accentGreen)
        }
    }
}
