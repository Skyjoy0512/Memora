import SwiftUI

// MARK: - AI Provider Section

struct AIProviderSection: View {
    @Bindable var state: SettingsState
    @AppStorage("selectedProvider") var selectedProvider: String = "OpenAI"

    var body: some View {
        Section {

            Picker("プロバイダー", selection: $state.selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    HStack {
                        Text(provider.rawValue)
                            .tag(provider.rawValue)

                        Spacer()

                        if provider == state.currentProvider {
                            Image(systemName: "checkmark")
                                .foregroundStyle(MemoraColor.textSecondary)
                        }

                        if provider == .local {
                            Text(LocalLLMProvider.isAvailable ? "On-Device" : "未対応")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(LocalLLMProvider.isAvailable ? MemoraColor.accentGreen : .secondary)
                        } else if !provider.supportsTranscription {
                            Text("要約のみ")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .pickerStyle(.inline)

            if state.currentProvider == .local {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: MemoraSpacing.xs) {
                        Image(systemName: LocalLLMProvider.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(LocalLLMProvider.isAvailable ? MemoraColor.accentGreen : MemoraColor.accentRed)
                        Text(LocalLLMProvider.isAvailable ? "On-Device LLM 利用可能" : "この端末では On-Device LLM は利用できません")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    if LocalLLMProvider.isAvailable {
                        Text("iOS 26 Foundation Models を使用します。API キー不要・無料。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentGreen)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中のプロバイダー:")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Text(state.currentProvider.rawValue)
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    if state.currentTranscriptionMode == .api && !state.currentProvider.supportsTranscription {
                        Text("※ 選択されたプロバイダーはAPI文字起こしをサポートしていません")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentRed)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("料金目安（参考）:")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                costInfo(for: state.currentProvider)
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        } header: {
            GlassSectionHeader(title: "AI プロバイダー選択", icon: "cpu")
        }
    }
}

// MARK: - Cost Info Helper

private func costInfo(for provider: AIProvider) -> some View {
    Group {
        switch provider {
    case .openai:
        VStack(alignment: .leading, spacing: 2) {
            Text("• API文字起こし: $0.006 / 分")
            Text("• 要約: $0.00015 / 1K tokens")
        }
        .font(MemoraTypography.caption1)
        .foregroundStyle(.secondary)

    case .gemini:
        VStack(alignment: .leading, spacing: 2) {
            Text("• API文字起こし: $0.0025 / 15秒")
            Text("• 要約: $0.000075 / 1K tokens (無料枠あり)")
        }
        .font(MemoraTypography.caption1)
        .foregroundStyle(.secondary)

    case .deepseek:
        VStack(alignment: .leading, spacing: 2) {
            Text("• 要約: $0.00014 / 1K tokens (かなり安価)")
            Text("• 文字起こし: 未対応（ローカル推奨）")
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
