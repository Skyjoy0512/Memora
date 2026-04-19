import SwiftUI
import SwiftData

// MARK: - Settings Bindings

/// SettingsView で使用する状態管理用クラス
/// View 間で共有する状態を一元管理
@MainActor
@Observable
final class SettingsState {
    // MARK: - Transcription Settings
    var transcriptionMode: String = "ローカル"
    var memoryPrivacyMode: String = MemoryPrivacyMode.standard.rawValue

    // MARK: - AI Provider
    var selectedProvider: String = "OpenAI"
    var apiKeyOpenAI: String = ""
    var apiKeyGemini: String = ""
    var apiKeyDeepSeek: String = ""

    // MARK: - Alerts
    var showDeleteAlert = false
    var showPlaudStatusAlert = false
    var plaudSyncStatus: String?

    // MARK: - Plaud Settings
    var plaudEmail: String = ""
    var plaudPassword: String = ""
    var plaudApiServer: String = "api.plaud.ai"
    var plaudServerURL: String = ""
    var plaudAutoSyncEnabled: Bool = false
    var isPlaudSyncing: Bool = false
    var isLoggedIn: Bool = false

    // MARK: - Custom Templates
    var showTemplateEditor = false
    var editingTemplate: CustomSummaryTemplate?
    var templateDraftName = ""
    var templateDraftPrompt = ""
    var templateDraftSections = ""

    // MARK: - Notion Settings
    var notionToken: String = ""
    var notionParentPageID: String = ""
    var isNotionTesting: Bool = false
    var notionTestResult: String?
    var isNotionSearching: Bool = false
    var notionSearchResults: [NotionService.NotionSearchResult] = []
    var selectedNotionPageID: String?
    var showNotionPagePicker: Bool = false

    // MARK: - Google Meet Settings
    var googleClientID: String = ""
    var googleRedirectURI: String = ""
    var isGoogleAuthorizing: Bool = false
    var googleAuthResult: String?
    var showGoogleMeetImport: Bool = false

    // MARK: - Debug
    var showDebugLog: Bool = false

    // MARK: - Computed Properties

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    var currentMemoryPrivacyMode: MemoryPrivacyMode {
        MemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
    }

    // MARK: - API Key Binding

    var currentAPIKeyBinding: Binding<String> {
        Binding(
            get: { [self] in
                switch self.currentProvider {
                case .openai:
                    return self.apiKeyOpenAI
                case .gemini:
                    return self.apiKeyGemini
                case .deepseek:
                    return self.apiKeyDeepSeek
                case .local:
                    return ""
                }
            },
            set: { [self] newValue in
                switch self.currentProvider {
                case .openai:
                    self.apiKeyOpenAI = newValue
                case .gemini:
                    self.apiKeyGemini = newValue
                case .deepseek:
                    self.apiKeyDeepSeek = newValue
                case .local:
                    break
                }
            }
        )
    }

    // MARK: - Initialization

    init() {
        // AppStorage から初期値を読み込み
        self.transcriptionMode = UserDefaults.standard.string(forKey: "transcriptionMode") ?? "ローカル"
        self.memoryPrivacyMode = UserDefaults.standard.string(forKey: "memoryPrivacyMode") ?? MemoryPrivacyMode.standard.rawValue
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "OpenAI"

        // Keychain から API キーを読み込み
        self.apiKeyOpenAI = KeychainService.load(key: .apiKeyOpenAI)
        self.apiKeyGemini = KeychainService.load(key: .apiKeyGemini)
        self.apiKeyDeepSeek = KeychainService.load(key: .apiKeyDeepSeek)
    }

    // MARK: - Persistence

    func saveToKeychain() {
        KeychainService.save(key: .apiKeyOpenAI, value: apiKeyOpenAI)
        KeychainService.save(key: .apiKeyGemini, value: apiKeyGemini)
        KeychainService.save(key: .apiKeyDeepSeek, value: apiKeyDeepSeek)
    }
}
