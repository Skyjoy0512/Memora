import SwiftUI
import SwiftData
import Speech

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(BluetoothAudioService.self) private var bluetoothService
    @Environment(OmiAdapter.self) private var omiAdapter
    @State private var state = SettingsState()

    var body: some View {
        NavigationStack {
            List {
                TranscriptionSettingsSection(state: state)
                AIProviderSection(state: state)
                APIKeySection(state: state)
                CustomTemplateSection(state: state)
                NotionIntegrationSection(state: state)
                GoogleMeetSection(state: state)
                MemorySettingsSection()
                UsageInstructionsSection()
                DataManagementSection(state: state)
                DeviceConnectionSection()
                RealtimeTranscriptionSection()
                BLEDebugSection()
                DeveloperFeaturesSection(state: state)
                DebugSection(state: state)
            }
            .tint(MemoraColor.accentNothing)
            .scrollContentBackground(.hidden)
            .background(MemoraColor.surfacePrimary)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            loadPlaudSettings()
            loadNotionSettings()
            loadGoogleSettings()
        }
        .alert("API キー削除", isPresented: $state.showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                switch state.currentProvider {
                case .openai:
                    state.apiKeyOpenAI = ""
                case .gemini:
                    state.apiKeyGemini = ""
                case .deepseek:
                    state.apiKeyDeepSeek = ""
                case .local:
                    break
                }
            }
        } message: {
            Text("API キーを削除しますか？")
        }
        .alert("Plaud 同期", isPresented: $state.showPlaudStatusAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let status = state.plaudSyncStatus {
                Text(status)
            }
        }
        .onChange(of: state.apiKeyOpenAI) { _, newValue in
            KeychainService.save(key: .apiKeyOpenAI, value: newValue)
        }
        .onChange(of: state.apiKeyGemini) { _, newValue in
            KeychainService.save(key: .apiKeyGemini, value: newValue)
        }
        .onChange(of: state.apiKeyDeepSeek) { _, newValue in
            KeychainService.save(key: .apiKeyDeepSeek, value: newValue)
        }
    }

    // MARK: - Load Settings

    private func loadPlaudSettings() {
        guard let settings = try? modelContext.fetch(
            FetchDescriptor<PlaudSettings>()
        ).first else { return }

        state.plaudEmail = settings.email
        state.plaudPassword = settings.password
        state.plaudApiServer = settings.apiServer
        state.plaudAutoSyncEnabled = settings.autoSyncEnabled

        // トークンが有効かチェック
        state.isLoggedIn = settings.isTokenValid
    }

    private func loadNotionSettings() {
        guard let settings = try? modelContext.fetch(
            FetchDescriptor<NotionSettings>()
        ).first else { return }

        state.notionToken = settings.integrationToken
        state.notionParentPageID = settings.parentPageID
        state.selectedNotionPageID = settings.parentPageID.isEmpty ? nil : settings.parentPageID
    }

    private func loadGoogleSettings() {
        guard let settings = try? modelContext.fetch(
            FetchDescriptor<GoogleMeetSettings>()
        ).first else { return }

        state.googleClientID = settings.clientID
        state.googleRedirectURI = settings.redirectURIScheme
    }
}

#Preview {
    SettingsView()
        .environment(OmiAdapter())
        .environment(BluetoothAudioService())
}
