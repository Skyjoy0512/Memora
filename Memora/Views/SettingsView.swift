import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedProvider") private var selectedProvider: String = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @State private var showDeleteAlert = false

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Transcription Settings
                Section("文字起こし設定") {
                    Picker("文字起こしモード", selection: $transcriptionMode) {
                        ForEach(TranscriptionMode.allCases) { mode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.rawValue)
                                    .tag(mode.rawValue)

                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .pickerStyle(.inline)

                    if currentTranscriptionMode == .api {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API文字起こしには有料プランを使用します。")
                                .font(.caption)
                                .foregroundStyle(.orange)

                            Text("ローカル文字起こしは無料ですが、API文字起こしはプロバイダーに応じて料金が発生します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if currentTranscriptionMode == .local {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ローカル文字起こしはiOS標準のSpeechフレームワークを使用します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("インターネット接続不要・無料で利用できます。")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - AI Provider Settings
                Section("AI プロバイダー選択") {
                    Picker("プロバイダー", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            HStack {
                                Text(provider.rawValue)
                                    .tag(provider.rawValue)

                                Spacer()

                                if provider == currentProvider {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.gray)
                                }

                                if !provider.supportsTranscription {
                                    Text("要約のみ")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .pickerStyle(.inline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("選択中のプロバイダー:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(currentProvider.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if currentTranscriptionMode == .api && !currentProvider.supportsTranscription {
                            Text("※ 選択されたプロバイダーはAPI文字起こしをサポートしていません")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("料金目安（参考）:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        costInfo(for: currentProvider)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - API Key Settings
                Section("API キー設定") {
                    SecureField("API キー", text: currentAPIKeyBinding)
                        .textFieldStyle(.plain)

                    if !currentAPIKeyBinding.wrappedValue.isEmpty {
                        Text("API キーが設定されています")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if currentTranscriptionMode == .api {
                        Text("API文字起こしまたは要約には API キーが必要です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("要約には API キーが必要です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("API キーはローカルにのみ保存されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Usage Instructions
                Section("使用方法") {
                    Text("文字起こし・要約の流れ：")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Files タブでファイルを選択")
                            .font(.subheadline)

                        Text("   → 録音画面を開く")
                            .font(.caption)

                        Text("2. 詳細画面で「文字起こし」をタップ")
                            .font(.caption)

                        Text("3. 詳細画面で「要約」をタップ")
                            .font(.caption)
                    }
                }

                // MARK: - Data Management
                Section("データ管理") {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Text("API キーを削除")
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("API キー削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                switch currentProvider {
                case .openai:
                    apiKeyOpenAI = ""
                case .gemini:
                    apiKeyGemini = ""
                case .deepseek:
                    apiKeyDeepSeek = ""
                }
            }
        } message: {
            Text("API キーを削除しますか？")
        }
    }

    private var currentAPIKeyBinding: Binding<String> {
        Binding(
            get: {
                switch currentProvider {
                case .openai:
                    return apiKeyOpenAI
                case .gemini:
                    return apiKeyGemini
                case .deepseek:
                    return apiKeyDeepSeek
                }
            },
            set: { newValue in
                switch currentProvider {
                case .openai:
                    apiKeyOpenAI = newValue
                case .gemini:
                    apiKeyGemini = newValue
                case .deepseek:
                    apiKeyDeepSeek = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func costInfo(for provider: AIProvider) -> some View {
        switch provider {
        case .openai:
            VStack(alignment: .leading, spacing: 2) {
                Text("• API文字起こし: $0.006 / 分")
                Text("• 要約: $0.00015 / 1K tokens")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .gemini:
            VStack(alignment: .leading, spacing: 2) {
                Text("• API文字起こし: $0.0025 / 15秒")
                Text("• 要約: $0.000075 / 1K tokens (無料枠あり)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .deepseek:
            VStack(alignment: .leading, spacing: 2) {
                Text("• 要約: $0.00014 / 1K tokens (かなり安価)")
                Text("• 文字起こし: 非対応（ローカル推奨）")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
