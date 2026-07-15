import SwiftUI

/// V6 設定画面から利用する、オンデバイスに限定した AI プロバイダー設定。
/// API キーは React Native や UserDefaults へ渡さず、既存の KeychainService に保存する。
struct V6AIProviderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("selectedProvider") private var selectedProvider = AIProvider.openai.rawValue
    @State private var openAIAPIKey = ""
    @State private var geminiAPIKey = ""
    @State private var deepSeekAPIKey = ""
    @State private var didLoadKeys = false

    private var provider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("AI モデル", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if provider == .local {
                        Label("ローカルモデルは API キー不要です", systemImage: "checkmark.shield")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("選択したプロバイダーのキーを入力してください。キーはこの端末のキーチェーンにのみ保存されます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("AI プロバイダー")
                }

                if provider == .openai {
                    keySection(title: "OpenAI API キー", key: $openAIAPIKey)
                }

                if provider == .gemini {
                    keySection(title: "Gemini API キー", key: $geminiAPIKey)
                }

                if provider == .deepseek {
                    keySection(title: "DeepSeek API キー", key: $deepSeekAPIKey)
                }
            }
            .navigationTitle("AI 設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: loadKeysIfNeeded)
        }
    }

    @ViewBuilder
    private func keySection(title: String, key: Binding<String>) -> some View {
        Section {
            SecureField(title, text: key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func loadKeysIfNeeded() {
        guard !didLoadKeys else { return }
        openAIAPIKey = KeychainService.load(key: .apiKeyOpenAI)
        geminiAPIKey = KeychainService.load(key: .apiKeyGemini)
        deepSeekAPIKey = KeychainService.load(key: .apiKeyDeepSeek)
        didLoadKeys = true
    }

    private func save() {
        KeychainService.save(key: .apiKeyOpenAI, value: openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
        KeychainService.save(key: .apiKeyGemini, value: geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
        KeychainService.save(key: .apiKeyDeepSeek, value: deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
