import SwiftUI
import SwiftData
import Speech

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bluetoothService: BluetoothAudioService
    @EnvironmentObject private var omiAdapter: OmiAdapter
    @AppStorage("selectedProvider") private var selectedProvider: String = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = MemoryPrivacyMode.standard.rawValue
    @State private var showDeleteAlert = false

    // Plaud 設定
    @Query private var plaudSettingsList: [PlaudSettings]
    @Query(sort: \MemoryFact.key) private var memoryFacts: [MemoryFact]
    @Query(sort: \MemoryProfile.createdAt, order: .forward) private var memoryProfiles: [MemoryProfile]
    @State private var plaudEmail: String = ""
    @State private var plaudPassword: String = ""
    @State private var plaudApiServer: String = "api.plaud.ai"
    @State private var plaudServerURL: String = ""
    @State private var plaudAutoSyncEnabled: Bool = false
    @State private var isPlaudSyncing: Bool = false
    @State private var plaudSyncStatus: String?
    @State private var showPlaudStatusAlert: Bool = false
    @State private var isLoggedIn: Bool = false
    @State private var showDebugLog: Bool = false

    // Notion 設定
    @Query private var notionSettingsList: [NotionSettings]
    @State private var notionToken: String = ""
    @State private var notionParentPageID: String = ""
    @State private var isNotionTesting: Bool = false
    @State private var notionTestResult: String?
    @State private var isNotionSearching: Bool = false
    @State private var notionSearchResults: [NotionService.NotionSearchResult] = []
    @State private var selectedNotionPageID: String?
    @State private var showNotionPagePicker: Bool = false

    var notionSettings: NotionSettings? {
        notionSettingsList.first
    }

    var plaudSettings: PlaudSettings? {
        plaudSettingsList.first
    }

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    private var currentMemoryPrivacyMode: MemoryPrivacyMode {
        MemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
    }

    var body: some View {
        NavigationStack {
            List {
                transcriptionSettingsSection
                aiProviderSection
                apiKeySection
                notionIntegrationSection
                memorySettingsSection
                usageInstructionsSection
                dataManagementSection
                deviceConnectionSection
                realtimeTranscriptionSection
                bleDebugSection
                developerFeaturesSection
                debugSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadPlaudSettings()
            loadNotionSettings()
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
        .alert("Plaud 同期", isPresented: $showPlaudStatusAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let status = plaudSyncStatus {
                Text(status)
            }
        }
    }

    // MARK: - Section Views

    @ViewBuilder
    private var transcriptionSettingsSection: some View {
        Section("文字起こし設定") {
            Picker("文字起こしモード", selection: $transcriptionMode) {
                ForEach(TranscriptionMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .tag(mode.rawValue)

                        Text(mode.description)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .pickerStyle(.inline)

            if currentTranscriptionMode == .api {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API文字起こしには有料プランを使用します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)

                    Text("ローカル文字起こしは無料ですが、API文字起こしはプロバイダーに応じて料金が発生します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }

            if currentTranscriptionMode == .local {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ローカル文字起こしは SFSpeechRecognizer を使用します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Text("インターネット接続不要・無料で利用できます。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentGreen)
                }
                .padding(.vertical, MemoraSpacing.xxxs)

                if #available(iOS 26.0, *) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { SpeechAnalyzerFeatureFlag.isEnabled },
                            set: { SpeechAnalyzerFeatureFlag.isEnabled = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iOS 26 SpeechAnalyzer（ベータ）")
                                Text("有効にすると iOS 26 ネイティブエンジンを使用します。不安定な場合があります。")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if SpeechAnalyzerFeatureFlag.isEnabled {
                            Text("⚠️ SpeechAnalyzer はベータ機能です。クラッシュする場合はオフにしてください。")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentRed)
                        }
                    }
                }
            }

            NavigationLink {
                STTDiagnosticsView()
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .foregroundStyle(MemoraColor.accentBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STT 診断")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text("backend 状態、asset 状態、フォールバック理由を確認")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
        }
    }

    @ViewBuilder
    private var aiProviderSection: some View {
        Section("AI プロバイダー選択") {
            Picker("プロバイダー", selection: $selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    HStack {
                        Text(provider.rawValue)
                            .tag(provider.rawValue)

                        Spacer()

                        if provider == currentProvider {
                            Image(systemName: "checkmark")
                                .foregroundStyle(MemoraColor.textSecondary)
                        }

                        if !provider.supportsTranscription {
                            Text("要約のみ")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .pickerStyle(.inline)

            VStack(alignment: .leading, spacing: 8) {
                Text("選択中のプロバイダー:")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                Text(currentProvider.rawValue)
                    .font(MemoraTypography.subheadline)
                    .fontWeight(.semibold)

                if currentTranscriptionMode == .api && !currentProvider.supportsTranscription {
                    Text("※ 選択されたプロバイダーはAPI文字起こしをサポートしていません")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)
                }
            }
            .padding(.vertical, MemoraSpacing.xxxs)

            VStack(alignment: .leading, spacing: 4) {
                Text("料金目安（参考）:")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                costInfo(for: currentProvider)
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        Section("API キー設定") {
            SecureField("API キー", text: currentAPIKeyBinding)
                .textFieldStyle(.plain)

            if !currentAPIKeyBinding.wrappedValue.isEmpty {
                Text("API キーが設定されています")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentGreen)
            }

            if currentTranscriptionMode == .api {
                Text("API文字起こしまたは要約には API キーが必要です。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            } else {
                Text("要約には API キーが必要です。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }

            Text("API キーはローカルにのみ保存されます。")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var memorySettingsSection: some View {
        Section {
            NavigationLink {
                MemorySettingsView()
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(MemoraColor.accentBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory 設定")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text("\(memoryFacts.count) 件保存・\(currentMemoryPrivacyMode.title)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !memoryProfiles.isEmpty {
                        Text("Profile")
                            .font(MemoraTypography.caption2)
                            .foregroundStyle(MemoraColor.accentBlue)
                            .padding(.horizontal, MemoraSpacing.xs)
                            .padding(.vertical, 4)
                            .background(MemoraColor.accentBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
        } header: {
            Text("Memory")
        } footer: {
            Text("AskAI に使う保存済み memory の確認、編集、無効化、削除を行えます。")
        }
    }

    @ViewBuilder
    private var usageInstructionsSection: some View {
        Section("使用方法") {
            Text("文字起こし・要約の流れ：")
                .font(MemoraTypography.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Files タブでファイルを選択")
                    .font(MemoraTypography.subheadline)

                Text("   → 録音画面を開く")
                    .font(MemoraTypography.caption1)

                Text("2. 詳細画面で「文字起こし」をタップ")
                    .font(MemoraTypography.caption1)

                Text("3. 詳細画面で「要約」をタップ")
                    .font(MemoraTypography.caption1)
            }
        }
    }

    @ViewBuilder
    private var dataManagementSection: some View {
        Section("データ管理") {
            Button {
                showDeleteAlert = true
            } label: {
                Text("API キーを削除")
            }
            .foregroundStyle(MemoraColor.accentRed)
        }
    }

    @ViewBuilder
    private var deviceConnectionSection: some View {
        Section("Omi 接続") {
            if !omiAdapter.sdkAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Omi Swift SDK が未設定です")
                        .font(MemoraTypography.subheadline)

                    Text("公式 SDK を package として追加した状態でビルドすると、scan / connect / live preview / audio import が有効になります。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if omiAdapter.isConnected {
                VStack(spacing: 13) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text("デバイスに接続されています")
                        .font(MemoraTypography.subheadline)

                    if let deviceName = omiAdapter.connectedDeviceName {
                        Text(deviceName)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    if let statusMessage = omiAdapter.statusMessage {
                        Text(statusMessage)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Text("状態: \(omiAdapter.connectionState.description)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.disconnect() }) {
                        Text("セッション終了")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.accentRed)
                            .cornerRadius(MemoraRadius.sm)
                    }

                    Text(omiAdapter.sessionTerminationDescription)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if !omiAdapter.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("発見したデバイス")
                            .font(MemoraTypography.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        if omiAdapter.isScanning {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)

                                Text("検索中")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(omiAdapter.discoveredDevices) { device in
                        Button(action: { omiAdapter.connect(to: device) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(MemoraColor.textSecondary)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.stableDisplayName)
                                        .font(MemoraTypography.subheadline)
                                        .foregroundStyle(.primary)

                                    Text(device.subtitle)
                                        .font(MemoraTypography.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                        }
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.sm)
                    }
                }
            } else if omiAdapter.isScanning {
                HStack(spacing: 13) {
                    ProgressView()
                        .tint(.gray)
                    Text("デバイスを検索中...")
                        .font(MemoraTypography.subheadline)
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("デバイスが見つかりませんでした")
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.startScan() }) {
                        Label("再スキャン", systemImage: "arrow.clockwise")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.divider)
                            .cornerRadius(MemoraRadius.sm)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var realtimeTranscriptionSection: some View {
        Section("Omi Preview") {
            if omiAdapter.isConnected {
                VStack(spacing: 13) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentGreen)
                        Text("公式 Omi path で接続中")
                            .font(MemoraTypography.subheadline)
                    }

                    Text("live transcript は preview 用です。取り込んだ audio file を Memora 側 STT pipeline で再処理して final transcript を確定します。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    if !omiAdapter.previewTranscript.isEmpty {
                        ScrollView {
                            Text(omiAdapter.previewTranscript)
                                .font(MemoraTypography.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 80, maxHeight: 180)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.sm)
                    }

                    if let importedAudio = omiAdapter.lastImportedAudio {
                        Text("取り込み済み: \(importedAudio.title)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("デバイスに接続していません")
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: { omiAdapter.startScan() }) {
                        Label("デバイスを検索", systemImage: "magnifyingglass")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.divider)
                            .cornerRadius(MemoraRadius.sm)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bleDebugSection: some View {
        if bluetoothService.isConnected {
            Section("汎用 BLE 実験機能（開発者向け）") {
                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("発見されたサービス UUID:")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)

                        ForEach(bluetoothService.discoveredServices, id: \.uuidString) { serviceUUID in
                            Text(serviceUUID.uuidString)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.vertical, MemoraSpacing.xxxs)
                        }

                        if bluetoothService.discoveredServices.isEmpty {
                            Text("サービスが見つかりません")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("発見されたキャラクタリスティック UUID:")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)

                        ForEach(bluetoothService.discoveredCharacteristics, id: \.uuidString) { characteristicUUID in
                            Text(characteristicUUID.uuidString)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.vertical, MemoraSpacing.xxxs)
                        }

                        if bluetoothService.discoveredCharacteristics.isEmpty {
                            Text("キャラクタリスティックが見つかりません")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var developerFeaturesSection: some View {
        Section("開発者機能") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(MemoraColor.accentBlue)
                    Text("Plaud エクスポートインポート")
                        .font(MemoraTypography.subheadline)
                }
                Text("FAB の「Plaud」ボタンから Plaud アプリのエクスポートファイル（JSON/TXT）をインポートできます。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }

            Toggle("Plaud 連携を有効化", isOn: Binding(
                get: { plaudSettings?.isEnabled ?? false },
                set: { newValue in
                    if let settings = plaudSettings {
                        settings.isEnabled = newValue
                        settings.updatedAt = Date()
                    } else if newValue {
                        let newSettings = PlaudSettings()
                        newSettings.isEnabled = true
                        newSettings.apiServer = plaudApiServer
                        newSettings.email = plaudEmail
                        newSettings.password = plaudPassword
                        newSettings.autoSyncEnabled = plaudAutoSyncEnabled
                        modelContext.insert(newSettings)
                    } else {
                        return
                    }
                    try? modelContext.save()
                }
            ))

            if plaudSettings?.isEnabled ?? false {
                if isLoggedIn {
                    // ログイン済み
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MemoraColor.accentGreen)
                            Text("ログイン中: \(plaudSettings?.email ?? "")")
                                .font(MemoraTypography.subheadline)
                        }

                        Toggle("自動同期", isOn: Binding(
                            get: { plaudSettings?.autoSyncEnabled ?? false },
                            set: { newValue in
                                if let settings = plaudSettings {
                                    settings.autoSyncEnabled = newValue
                                    settings.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            }
                        ))

                        Button(action: {
                            Task {
                                await syncPlaudRecordings()
                            }
                        }) {
                            HStack {
                                Text("手動同期")
                                if isPlaudSyncing {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isPlaudSyncing)

                        if let lastSync = plaudSettings?.lastSyncAt {
                            Text("最終同期: \(formatDate(lastSync))")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }

                        Button(action: {
                            logoutPlaud()
                        }) {
                            Text("ログアウト")
                                .foregroundStyle(MemoraColor.accentRed)
                        }
                    }
                } else {
                    // 未ログイン
                    Picker("API サーバー", selection: $plaudApiServer) {
                        Text("api.plaud.ai").tag("api.plaud.ai")
                        Text("api-euc1.plaud.ai").tag("api-euc1.plaud.ai")
                        Text("カスタム").tag("custom")
                    }
                    .pickerStyle(.menu)

                    if plaudApiServer == "custom" {
                        TextField("カスタム API サーバー", text: $plaudServerURL)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }

                    TextField("メールアドレス", text: $plaudEmail)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("パスワード", text: $plaudPassword)
                        .textFieldStyle(.plain)

                    Button(action: {
                        Task {
                            await loginPlaud()
                        }
                    }) {
                        HStack {
                            Text("ログイン")
                            if isPlaudSyncing {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isPlaudSyncing || plaudEmail.isEmpty || plaudPassword.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        Section("デバッグ") {
            NavigationLink {
                DebugLogView()
            } label: {
                HStack {
                    Image(systemName: "ladybug")
                        .foregroundStyle(MemoraColor.accentRed)
                    Text("デバッグログ")
                    Spacer()
                    if let lastLog = DebugLogger.shared.logs.last {
                        Text("\(lastLog.message)")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Text("アプリ初回起動時のパフォーマンスを確認できます")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Notion Integration Section

    @ViewBuilder
    private var notionIntegrationSection: some View {
        Section {
            Toggle("Notion 連携を有効化", isOn: Binding(
                get: { notionSettings?.isEnabled ?? false },
                set: { newValue in
                    if let settings = notionSettings {
                        settings.isEnabled = newValue
                        settings.updatedAt = Date()
                    } else if newValue {
                        let newSettings = NotionSettings()
                        newSettings.isEnabled = true
                        modelContext.insert(newSettings)
                    }
                    try? modelContext.save()
                }
            ))

            if notionSettings?.isEnabled == true {
                SecureField("Internal Integration Token", text: Binding(
                    get: { notionToken },
                    set: { newValue in
                        notionToken = newValue
                        if let settings = notionSettings {
                            settings.integrationToken = newValue
                            settings.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .font(.system(.body, design: .monospaced))

                if !notionToken.isEmpty {
                    // 親ページ選択
                    HStack {
                        TextField("親ページ ID", text: Binding(
                            get: { selectedNotionPageID ?? notionParentPageID },
                            set: { newValue in
                                notionParentPageID = newValue
                                selectedNotionPageID = newValue
                                if let settings = notionSettings {
                                    settings.parentPageID = newValue
                                    settings.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))

                        Spacer()

                        Button {
                            showNotionPagePicker = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(MemoraColor.accentBlue)
                        }
                    }

                    // 接続テスト
                    Button {
                        Task { await testNotionConnection() }
                    } label: {
                        HStack {
                            Text("接続テスト")
                            if isNotionTesting {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isNotionTesting || notionToken.isEmpty)

                    if let result = notionTestResult {
                        Text(result)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(result.contains("成功") ? MemoraColor.accentGreen : MemoraColor.accentRed)
                    }

                    // 設定状態
                    if notionSettings?.isConfigured == true {
                        HStack(spacing: MemoraSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MemoraColor.accentGreen)
                            Text("設定完了")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentGreen)
                        }

                        if let lastExport = notionSettings?.lastExportAt {
                            Text("最終エクスポート: \(formatDate(lastExport))")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Token と親ページ ID を設定してください")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Notion 連携")
        } footer: {
            Text("会議の文字起こし・要約を Notion ページとしてエクスポートします。notion.so/my-integrations から Internal Integration Token を取得してください。")
        }
        .sheet(isPresented: $showNotionPagePicker) {
            NotionPagePickerView(
                token: notionToken,
                selectedPageID: Binding(
                    get: { selectedNotionPageID ?? notionParentPageID },
                    set: { newValue in
                        selectedNotionPageID = newValue
                        notionParentPageID = newValue
                        if let settings = notionSettings {
                            settings.parentPageID = newValue
                            settings.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                ),
                isPresented: $showNotionPagePicker
            )
        }
    }

    // MARK: - Helper Properties

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

    // MARK: - Helper Functions

    @ViewBuilder
    private func costInfo(for provider: AIProvider) -> some View {
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
        }
    }

    private func loadNotionSettings() {
        guard let settings = notionSettings else { return }
        notionToken = settings.integrationToken
        notionParentPageID = settings.parentPageID
        selectedNotionPageID = settings.parentPageID.isEmpty ? nil : settings.parentPageID
    }

    private func testNotionConnection() async {
        isNotionTesting = true
        notionTestResult = nil

        do {
            let service = NotionService()
            let user = try await service.testConnection(token: notionToken)
            notionTestResult = "接続成功: \(user.name ?? "ユーザー")"
        } catch {
            notionTestResult = "エラー: \(error.localizedDescription)"
        }

        isNotionTesting = false
    }

    private func loadPlaudSettings() {
        guard let settings = plaudSettings else { return }
        plaudEmail = settings.email
        plaudPassword = settings.password
        plaudApiServer = settings.apiServer
        plaudAutoSyncEnabled = settings.autoSyncEnabled

        // トークンが有効かチェック
        isLoggedIn = settings.isTokenValid
    }

    private func loginPlaud() async {
        isPlaudSyncing = true

        do {
            let service = PlaudService()

            // API サーバーを決定
            let server = plaudApiServer == "custom" ? plaudServerURL : plaudApiServer

            // ログイン
            let authResponse = try await service.login(
                apiServer: server,
                email: plaudEmail,
                password: plaudPassword
            )

            // ユーザー情報を取得
            let userInfo = try await service.getUserInfo(
                apiServer: server,
                token: authResponse.accessToken
            )

            // 設定を保存
            var settings: PlaudSettings

            if let existing = plaudSettings {
                settings = existing
            } else {
                settings = PlaudSettings()
                settings.isEnabled = true
                modelContext.insert(settings)
            }

            settings.apiServer = server
            settings.email = plaudEmail
            settings.password = plaudPassword
            settings.accessToken = authResponse.accessToken
            settings.refreshToken = authResponse.refreshToken
            settings.userId = userInfo.id
            settings.tokenExpiresAt = authResponse.calculatedExpiresAt
            settings.updatedAt = Date()

            try? modelContext.save()

            isLoggedIn = true
            plaudSyncStatus = "ログインに成功しました"
        } catch {
            plaudSyncStatus = "エラー: \(error.localizedDescription)"
        }

        isPlaudSyncing = false
        showPlaudStatusAlert = true
    }

    private func logoutPlaud() {
        if let settings = plaudSettings {
            settings.accessToken = ""
            settings.refreshToken = ""
            settings.tokenExpiresAt = nil
            settings.updatedAt = Date()
            try? modelContext.save()
        }

        isLoggedIn = false
        plaudPassword = ""
    }

    private func syncPlaudRecordings() async {
        isPlaudSyncing = true

        guard let settings = plaudSettings else {
            plaudSyncStatus = "設定が見つかりません"
            isPlaudSyncing = false
            showPlaudStatusAlert = true
            return
        }

        // トークンが期限切れならリフレッシュ
        if settings.shouldRefreshToken {
            do {
                let service = PlaudService()
                let authResponse = try await service.refreshToken(
                    apiServer: settings.apiServer,
                    refreshToken: settings.refreshToken
                )

                settings.accessToken = authResponse.accessToken
                settings.refreshToken = authResponse.refreshToken
                settings.tokenExpiresAt = authResponse.calculatedExpiresAt
                settings.updatedAt = Date()
                try? modelContext.save()
            } catch {
                // リフレッシュ失敗
                plaudSyncStatus = "トークンのリフレッシュに失敗しました: \(error.localizedDescription)"
                isPlaudSyncing = false
                showPlaudStatusAlert = true
                return
            }
        }

        do {
            let service = PlaudService()
            let recordings = try await service.syncRecordings(
                apiServer: settings.apiServer,
                token: settings.accessToken
            )

            var importedCount = 0
            var skippedCount = 0

            for recording in recordings {
                // 既にインポート済みか確認（タイトルと作成日時で判定）
                let alreadyExists: Bool
                do {
                    let existing = try modelContext.fetch(
                        FetchDescriptor<AudioFile>(
                            predicate: #Predicate { audioFile in
                                audioFile.title == recording.title &&
                                audioFile.createdAt == recording.createdAt
                            }
                        )
                    ).first
                    alreadyExists = existing != nil
                } catch {
                    alreadyExists = false
                }

                if alreadyExists {
                    skippedCount += 1
                    continue
                }

                // 音声ファイルをダウンロードして Memora に保存
                let audioUrl = try await service.importRecordingToMemora(
                    recording: recording,
                    apiServer: settings.apiServer,
                    token: settings.accessToken
                )

                // AudioFile を作成
                let audioFile = AudioFile(
                    title: recording.title,
                    audioURL: audioUrl.path
                )
                audioFile.createdAt = recording.createdAt
                audioFile.duration = recording.duration

                // Plaud から要約があれば設定
                if let summary = recording.summary {
                    audioFile.summary = summary
                    audioFile.isSummarized = true
                }

                modelContext.insert(audioFile)

                // 文字起こしがあれば参照文字起こしとして保存
                if let transcriptText = recording.transcript, !transcriptText.isEmpty {
                    audioFile.referenceTranscript = transcriptText
                    // isTranscribed = true にはしない（Memora 側文字起こしではない）
                }

                importedCount += 1
            }

            try modelContext.save()

            // 最終同期日時を更新
            if let settings = plaudSettings {
                settings.lastSyncAt = Date()
                settings.updatedAt = Date()
                try? modelContext.save()
            }

            var statusMessage = "\(importedCount) 件の録音をインポートしました"
            if skippedCount > 0 {
                statusMessage += "（\(skippedCount) 件は既存のためスキップ）"
            }
            plaudSyncStatus = statusMessage
        } catch {
            plaudSyncStatus = "エラー: \(error.localizedDescription)"
        }

        isPlaudSyncing = false
        showPlaudStatusAlert = true
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatRecordingTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

private struct MemorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryFact.key) private var memoryFacts: [MemoryFact]
    @Query(sort: \MemoryProfile.createdAt, order: .forward) private var memoryProfiles: [MemoryProfile]
    @AppStorage("memoryPrivacyMode") private var memoryPrivacyMode = MemoryPrivacyMode.standard.rawValue

    @State private var summaryStyle = ""
    @State private var preferredLanguage = ""
    @State private var roleLabel = ""
    @State private var glossary = ""
    @State private var disabledFactIDs = DisabledMemoryFactsStore.load()
    @State private var editingDraft: MemoryFactDraft?

    private var privacyMode: MemoryPrivacyMode {
        MemoryPrivacyMode(rawValue: memoryPrivacyMode) ?? .standard
    }

    private var profile: MemoryProfile? {
        memoryProfiles.first
    }

    private var enabledFactCount: Int {
        memoryFacts.filter { !disabledFactIDs.contains($0.id) }.count
    }

    var body: some View {
        List {
            privacySection
            profileSection
            candidateSection
            savedFactsSection
        }
        .navigationTitle("Memory 設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfileFields()
            disabledFactIDs = DisabledMemoryFactsStore.load()
        }
        .sheet(item: $editingDraft) { draft in
            MemoryFactEditorSheet(
                draft: draft,
                onSave: saveFactEdits
            )
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section("プライバシーモード") {
            Picker("モード", selection: $memoryPrivacyMode) {
                ForEach(MemoryPrivacyMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title)
                            .tag(mode.rawValue)

                        Text(mode.shortDescription)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .pickerStyle(.inline)

            VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                Text(privacyMode.description)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                Text("現在: 有効 \(enabledFactCount) 件 / 無効 \(memoryFacts.count - enabledFactCount) 件")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textTertiary)
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section {
            TextField("要約スタイル", text: $summaryStyle)
            TextField("優先言語", text: $preferredLanguage)
            TextField("ロール・肩書き", text: $roleLabel)
            TextField("用語メモ", text: $glossary, axis: .vertical)
                .lineLimit(2...4)

            Button("プロフィール memory を保存") {
                saveProfileFields()
            }

            if hasAnyProfileField {
                Button("プロフィール memory をクリア", role: .destructive) {
                    clearProfileFields()
                }
            }
        } header: {
            Text("Profile Memory")
        } footer: {
            Text("AskAI の応答スタイルや個人設定に使う固定情報です。")
        }
    }

    @ViewBuilder
    private var candidateSection: some View {
        let candidates = memoryFacts.filter { $0.lastConfirmedAt == nil }
        if !candidates.isEmpty {
            Section {
                ForEach(candidates) { fact in
                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                        HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fact.key)
                                    .font(MemoraTypography.subheadline)
                                    .foregroundStyle(.primary)

                                Text(fact.value)
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Text("候補")
                                .font(MemoraTypography.caption2)
                                .foregroundStyle(MemoraColor.accentBlue)
                                .padding(.horizontal, MemoraSpacing.xs)
                                .padding(.vertical, 4)
                                .background(MemoraColor.accentBlue.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        HStack(spacing: MemoraSpacing.sm) {
                            Button {
                                fact.confirm()
                                try? modelContext.save()
                            } label: {
                                Label("承認", systemImage: "checkmark.circle")
                                    .font(MemoraTypography.caption1)
                            }
                            .buttonStyle(.bordered)
                            .tint(MemoraColor.accentGreen)

                            Button(role: .destructive) {
                                DisabledMemoryFactsStore.remove(id: fact.id)
                                disabledFactIDs.remove(fact.id)
                                modelContext.delete(fact)
                                try? modelContext.save()
                            } label: {
                                Label("却下", systemImage: "xmark.circle")
                                    .font(MemoraTypography.caption1)
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Text(fact.source)
                                .font(MemoraTypography.caption2)
                                .foregroundStyle(MemoraColor.textTertiary)
                        }
                    }
                    .padding(.vertical, MemoraSpacing.xxxs)
                }
            } header: {
                Text("承認待ち (\(candidates.count))")
            } footer: {
                Text("要約完了時に自動抽出された記憶候補です。承認すると AskAI で活用されます。")
            }
        }
    }

    @ViewBuilder
    private var savedFactsSection: some View {
        Section {
            if memoryFacts.isEmpty {
                VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                    Text("保存済み memory はまだありません。")
                        .font(MemoraTypography.subheadline)

                    Text("CL-B5 の抽出候補承認フローが入ると、ここに preference / glossary / persona が並びます。")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            } else {
                ForEach(memoryFacts) { fact in
                    Button {
                        editingDraft = MemoryFactDraft(
                            id: fact.id,
                            key: fact.key,
                            value: fact.value,
                            source: fact.source,
                            confidence: fact.confidence
                        )
                    } label: {
                        MemoryFactRow(
                            fact: fact,
                            isDisabled: disabledFactIDs.contains(fact.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(disabledFactIDs.contains(fact.id) ? "有効化" : "無効化") {
                            toggleFactDisabled(fact)
                        }
                        .tint(disabledFactIDs.contains(fact.id) ? MemoraColor.accentGreen : .orange)

                        Button("削除", role: .destructive) {
                            deleteFact(fact)
                        }
                    }
                }
            }
        } header: {
            Text("保存済み Memory")
        } footer: {
            Text("無効化した memory は保持したまま AskAI の対象から外せます。")
        }
    }

    private var hasAnyProfileField: Bool {
        [summaryStyle, preferredLanguage, roleLabel, glossary]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func loadProfileFields() {
        guard let profile else {
            summaryStyle = ""
            preferredLanguage = ""
            roleLabel = ""
            glossary = ""
            return
        }

        summaryStyle = profile.summaryStyle ?? ""
        preferredLanguage = profile.preferredLanguage ?? ""
        roleLabel = profile.roleLabel ?? ""
        glossary = profile.glossaryJSON ?? ""
    }

    private func saveProfileFields() {
        let target = profile ?? {
            let newProfile = MemoryProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()

        target.update(
            summaryStyle: trimmedOrNil(summaryStyle),
            preferredLanguage: trimmedOrNil(preferredLanguage),
            roleLabel: trimmedOrNil(roleLabel),
            glossaryJSON: trimmedOrNil(glossary)
        )

        try? modelContext.save()
        loadProfileFields()
    }

    private func clearProfileFields() {
        guard let profile else { return }
        profile.update(
            summaryStyle: nil,
            preferredLanguage: nil,
            roleLabel: nil,
            glossaryJSON: nil
        )
        try? modelContext.save()
        loadProfileFields()
    }

    private func saveFactEdits(_ draft: MemoryFactDraft) {
        guard let fact = memoryFacts.first(where: { $0.id == draft.id }) else { return }

        fact.key = draft.key.trimmingCharacters(in: .whitespacesAndNewlines)
        fact.value = draft.value.trimmingCharacters(in: .whitespacesAndNewlines)
        fact.source = draft.source.trimmingCharacters(in: .whitespacesAndNewlines)
        fact.confidence = draft.confidence
        try? modelContext.save()
    }

    private func toggleFactDisabled(_ fact: MemoryFact) {
        disabledFactIDs = DisabledMemoryFactsStore.toggle(id: fact.id)
    }

    private func deleteFact(_ fact: MemoryFact) {
        DisabledMemoryFactsStore.remove(id: fact.id)
        disabledFactIDs.remove(fact.id)
        modelContext.delete(fact)
        try? modelContext.save()
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct MemoryFactRow: View {
    let fact: MemoryFact
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.key)
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(isDisabled ? MemoraColor.textSecondary : .primary)

                    Text(fact.value)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Text(isDisabled ? "無効" : "有効")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(isDisabled ? .orange : MemoraColor.accentGreen)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 4)
                    .background((isDisabled ? Color.orange : MemoraColor.accentGreen).opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: MemoraSpacing.sm) {
                Label(fact.source, systemImage: "tray.full")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textSecondary)

                Label("\(Int(fact.confidence * 100))%", systemImage: "chart.bar")
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
        .padding(.vertical, MemoraSpacing.xxxs)
    }
}

private struct MemoryFactEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var draft: MemoryFactDraft
    let onSave: (MemoryFactDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("編集") {
                    TextField("Key", text: $draft.key)
                    TextField("Value", text: $draft.value, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Source", text: $draft.source)

                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text("\(Int(draft.confidence * 100))%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $draft.confidence, in: 0...1)
                    }
                }
            }
            .navigationTitle("Memory 編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        draft.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

private struct MemoryFactDraft: Identifiable {
    let id: UUID
    var key: String
    var value: String
    var source: String
    var confidence: Double
}

private enum MemoryPrivacyMode: String, CaseIterable, Identifiable {
    case standard = "standard"
    case paused = "paused"
    case off = "off"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "標準"
        case .paused:
            return "保存停止"
        case .off:
            return "完全オフ"
        }
    }

    var shortDescription: String {
        switch self {
        case .standard:
            return "memory を保存し、AskAI に反映"
        case .paused:
            return "既存 memory は残し、新規保存を止める"
        case .off:
            return "保存も利用も停止"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "承認済み memory を AskAI に渡し、今後の抽出候補も保存対象として扱います。"
        case .paused:
            return "既存の memory は保持しますが、新しい memory 候補は保存しない前提で扱います。"
        case .off:
            return "保存済み memory を AskAI に渡さず、新規 memory 保存も停止する最も強いモードです。"
        }
    }
}

private enum DisabledMemoryFactsStore {
    private static let key = "disabledMemoryFactIDs"

    static func load() -> Set<UUID> {
        Set(
            (UserDefaults.standard.stringArray(forKey: key) ?? [])
                .compactMap(UUID.init(uuidString:))
        )
    }

    @discardableResult
    static func toggle(id: UUID) -> Set<UUID> {
        var ids = load()
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        save(ids)
        return ids
    }

    static func remove(id: UUID) {
        var ids = load()
        ids.remove(id)
        save(ids)
    }

    private static func save(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString).sorted(), forKey: key)
    }
}

private struct STTDiagnosticsView: View {
    @AppStorage("selectedProvider") private var selectedProvider: String = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("speechAnalyzerEnabled") private var speechAnalyzerEnabled: Bool = false
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @AppStorage("sttDiagnosticsLastFallbackReason") private var storedFallbackReason = "未診断"

    @State private var snapshot: STTDiagnosticsSnapshot?
    @State private var recentEntries: [STTBackendDiagnosticEntry] = []
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    private var currentMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    private var currentAPIKey: String {
        switch currentProvider {
        case .openai:
            return apiKeyOpenAI
        case .gemini:
            return apiKeyGemini
        case .deepseek:
            return apiKeyDeepSeek
        }
    }

    private var lastRecordedEntry: STTBackendDiagnosticEntry? {
        recentEntries.last ?? STTDiagnosticsLog.shared.persistedLastEntry
    }

    private var lastFallbackReasonText: String {
        let normalizedStoredReason = storedFallbackReason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedStoredReason.isEmpty, normalizedStoredReason != "未診断" {
            return normalizedStoredReason
        }

        if let runtimeReason = lastRecordedEntry?.fallbackReason, !runtimeReason.isEmpty {
            return runtimeReason
        }

        return "まだフォールバックは記録されていません。"
    }

    var body: some View {
        List {
            configurationSection
            diagnosticsSection
            recentExecutionSection
            fallbackSection
            testSection
        }
        .navigationTitle("STT 診断")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard snapshot == nil else { return }
            await refreshDiagnostics(performFullTest: false)
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        Section("現在の構成") {
            LabeledContent("文字起こしモード", value: currentMode.rawValue)
            LabeledContent("AI プロバイダー", value: currentProvider.rawValue)

            if currentMode == .local {
                LabeledContent("SpeechAnalyzer", value: speechAnalyzerEnabled ? "ON" : "OFF")
            } else {
                LabeledContent("API キー", value: currentAPIKey.isEmpty ? "未設定" : "設定済み")
            }
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section("診断パネル") {
            if let snapshot {
                STTDiagnosticsCard(snapshot.backendPanel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                STTDiagnosticsCard(snapshot.assetPanel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                    Text("診断メモ")
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    Text(snapshot.testSummary)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Text("診断モード: \(snapshot.diagnosticModeLabel)")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text("更新: \(snapshot.generatedAtText)")
                        .font(MemoraTypography.caption2)
                        .foregroundStyle(MemoraColor.textTertiary)
                }
                .padding(MemoraSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MemoraColor.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
            } else if isRefreshing {
                HStack(spacing: MemoraSpacing.sm) {
                    ProgressView()
                    Text("診断情報を取得中...")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentRed)
            } else {
                Text("診断情報はまだありません。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var recentExecutionSection: some View {
        Section("直近の実行ログ") {
            if let lastRecordedEntry {
                STTLastExecutionCard(entry: lastRecordedEntry)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if recentEntries.count > 1 {
                    VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                        Text("履歴")
                            .font(MemoraTypography.subheadline)
                            .fontWeight(.semibold)

                        ForEach(Array(recentEntries.reversed().dropFirst().prefix(4))) { entry in
                            HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                                Text(entry.recordedAtText)
                                    .font(MemoraTypography.caption2)
                                    .foregroundStyle(MemoraColor.textTertiary)
                                    .frame(width: 110, alignment: .leading)

                                Text(entry.summary)
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(MemoraSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MemoraColor.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                }
            } else {
                Text("まだ文字起こし実行ログはありません。ここには実際の backend 使用履歴を表示します。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var fallbackSection: some View {
        Section("前回のフォールバック理由") {
            Text(lastFallbackReasonText)
                .font(MemoraTypography.body)
                .foregroundStyle(.primary)

            if let snapshot {
                Text("現在の判定: \(snapshot.fallbackReason)")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }

            Text("ここには実際の文字起こし実行で記録された最後のフォールバック理由を保持します。")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var testSection: some View {
        Section("テスト文字起こし診断") {
            Button {
                Task {
                    await refreshDiagnostics(performFullTest: true)
                }
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(MemoraColor.accentBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRefreshing ? "診断を実行中..." : "テスト診断を実行")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.primary)

                        Text("backend 選択、権限、locale、asset 状態を同じ経路で再評価")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
            .disabled(isRefreshing)

            Text("実音声の文字起こしは走らせません。ローカル + SpeechAnalyzer ON の場合は preflight を実行し、必要に応じて asset install request まで確認します。")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func refreshDiagnostics(performFullTest: Bool) async {
        isRefreshing = true
        errorMessage = nil

        let snapshot = await STTDiagnosticsRunner.makeSnapshot(
            mode: currentMode,
            provider: currentProvider,
            speechAnalyzerEnabled: speechAnalyzerEnabled,
            apiKeyConfigured: !currentAPIKey.isEmpty,
            performFullTest: performFullTest
        )

        self.snapshot = snapshot
        let inMemoryEntries = STTDiagnosticsLog.shared.recentEntries
        if inMemoryEntries.isEmpty, let persistedEntry = STTDiagnosticsLog.shared.persistedLastEntry {
            self.recentEntries = [persistedEntry]
        } else {
            self.recentEntries = inMemoryEntries
        }
        self.isRefreshing = false
    }
}

private enum STTDiagnosticsRunner {
    static func makeSnapshot(
        mode: TranscriptionMode,
        provider: AIProvider,
        speechAnalyzerEnabled: Bool,
        apiKeyConfigured: Bool,
        performFullTest: Bool
    ) async -> STTDiagnosticsSnapshot {
        switch mode {
        case .api:
            return makeAPISnapshot(provider: provider, apiKeyConfigured: apiKeyConfigured)
        case .local:
            return await makeLocalSnapshot(
                speechAnalyzerEnabled: speechAnalyzerEnabled,
                performFullTest: performFullTest
            )
        }
    }

    private static func makeAPISnapshot(
        provider: AIProvider,
        apiKeyConfigured: Bool
    ) -> STTDiagnosticsSnapshot {
        let supportsTranscription = provider.supportsTranscription
        let backendStatus: STTDiagnosticsTone = supportsTranscription && apiKeyConfigured ? .success : .warning
        let fallbackReason: String

        if !supportsTranscription {
            fallbackReason = "選択中の \(provider.rawValue) は API 文字起こし未対応のため、API モードでは開始できません。OpenAI を選択してください。"
        } else if !apiKeyConfigured {
            fallbackReason = "API キーが未設定のため、CloudSTTBackend を開始できません。"
        } else {
            fallbackReason = "フォールバックは発生していません。現在は \(provider.rawValue) API を使用予定です。"
        }

        return STTDiagnosticsSnapshot(
            backendPanel: STTDiagnosticsPanel(
                title: "Backend Status",
                badgeText: supportsTranscription ? "API" : "要修正",
                tone: backendStatus,
                summary: supportsTranscription ? "\(provider.rawValue) API を使用予定" : "API 文字起こしに未対応",
                details: [
                    "文字起こしモード: API",
                    "選択プロバイダー: \(provider.rawValue)",
                    "API キー: \(apiKeyConfigured ? "設定済み" : "未設定")"
                ]
            ),
            assetPanel: STTDiagnosticsPanel(
                title: "Asset Status",
                badgeText: "N/A",
                tone: .neutral,
                summary: "API モードでは SpeechAnalyzer asset は使用しません。",
                details: [
                    "ローカルモデル: 未使用",
                    "SpeechAnalyzer asset: チェック対象外"
                ]
            ),
            fallbackReason: fallbackReason,
            testSummary: supportsTranscription
                ? "API backend の設定整合性を確認しました。"
                : "API backend の選択条件を満たしていないため、設定の修正が必要です。",
            diagnosticModeLabel: "設定チェック",
            generatedAt: Date()
        )
    }

    private static func makeLocalSnapshot(
        speechAnalyzerEnabled: Bool,
        performFullTest: Bool
    ) async -> STTDiagnosticsSnapshot {
        let locale = Locale(identifier: "ja_JP")
        let authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        let recognizer = SFSpeechRecognizer(locale: locale)
        let recognizerAvailable = recognizer?.isAvailable ?? false

        #if targetEnvironment(simulator)
        let simulatorReason = "シミュレータでは SpeechAnalyzer を使わず、SFSpeechRecognizer へフォールバックします。"
        #else
        let simulatorReason = ""
        #endif

        if #available(iOS 26.0, *), speechAnalyzerEnabled {
            if performFullTest {
                let result = await SpeechAnalyzerPreflight().run(locale: locale)
                return makeSpeechAnalyzerSnapshot(
                    locale: locale,
                    authorizationStatus: authorizationStatus,
                    recognizerAvailable: recognizerAvailable,
                    simulatorReason: simulatorReason,
                    result: result
                )
            }

            let inspection = await inspectSpeechAnalyzer(locale: locale)
            return makeSpeechAnalyzerSnapshot(
                locale: locale,
                authorizationStatus: authorizationStatus,
                recognizerAvailable: recognizerAvailable,
                simulatorReason: simulatorReason,
                inspection: inspection
            )
        }

        let fallbackReason: String
        if !simulatorReason.isEmpty {
            fallbackReason = simulatorReason
        } else if speechAnalyzerEnabled {
            fallbackReason = "現在の OS では SpeechAnalyzer を使えないため、SFSpeechRecognizer を使用します。"
        } else {
            fallbackReason = "SpeechAnalyzer ベータ機能が OFF のため、SFSpeechRecognizer を使用します。"
        }

        let recognizerTone: STTDiagnosticsTone = recognizerAvailable ? .success : .warning
        return STTDiagnosticsSnapshot(
            backendPanel: STTDiagnosticsPanel(
                title: "Backend Status",
                badgeText: "SpeechRecognizer",
                tone: recognizerTone,
                summary: recognizerAvailable
                    ? "SFSpeechRecognizer を使用予定です。"
                    : "SFSpeechRecognizer の利用可否を再確認してください。",
                details: [
                    "文字起こしモード: ローカル",
                    "SpeechAnalyzer トグル: \(speechAnalyzerEnabled ? "ON" : "OFF")",
                    "Speech 権限: \(authorizationStatus.label)",
                    "SFSpeechRecognizer: \(recognizerAvailable ? "利用可能" : "利用不可")"
                ]
            ),
            assetPanel: STTDiagnosticsPanel(
                title: "Asset Status",
                badgeText: "未使用",
                tone: .neutral,
                summary: "この構成では SpeechAnalyzer asset を使用しません。",
                details: [
                    "SpeechAnalyzer: \(speechAnalyzerEnabled ? "OS 非対応" : "無効")",
                    "on-device asset: チェック対象外"
                ]
            ),
            fallbackReason: fallbackReason,
            testSummary: recognizerAvailable
                ? "SFSpeechRecognizer backend の基本状態を確認しました。"
                : "SFSpeechRecognizer の権限または availability を見直してください。",
            diagnosticModeLabel: "設定チェック",
            generatedAt: Date()
        )
    }

    @available(iOS 26.0, *)
    private static func makeSpeechAnalyzerSnapshot(
        locale: Locale,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus,
        recognizerAvailable: Bool,
        simulatorReason: String,
        inspection: SpeechAnalyzerInspection
    ) -> STTDiagnosticsSnapshot {
        let backendTone: STTDiagnosticsTone = inspection.canUseSpeechAnalyzer ? .success : .warning
        let fallbackReason = inspection.canUseSpeechAnalyzer
            ? "フォールバックは発生していません。SpeechAnalyzer を優先できます。"
            : inspection.fallbackReason

        return STTDiagnosticsSnapshot(
            backendPanel: STTDiagnosticsPanel(
                title: "Backend Status",
                badgeText: inspection.canUseSpeechAnalyzer ? "SpeechAnalyzer" : "Fallback",
                tone: backendTone,
                summary: inspection.canUseSpeechAnalyzer
                    ? "SpeechAnalyzer を優先して使用できます。"
                    : "SpeechAnalyzer 条件を満たさず、SFSpeechRecognizer を使用予定です。",
                details: [
                    "文字起こしモード: ローカル",
                    "SpeechAnalyzer トグル: ON",
                    "Speech 権限: \(authorizationStatus.label)",
                    "SFSpeechRecognizer: \(recognizerAvailable ? "利用可能" : "利用不可")"
                ]
            ),
            assetPanel: STTDiagnosticsPanel(
                title: "Asset Status",
                badgeText: inspection.assetBadge,
                tone: inspection.assetTone,
                summary: inspection.assetSummary,
                details: inspection.assetDetails
            ),
            fallbackReason: simulatorReason.isEmpty ? fallbackReason : simulatorReason,
            testSummary: inspection.testSummary,
            diagnosticModeLabel: "高速チェック",
            generatedAt: Date()
        )
    }

    @available(iOS 26.0, *)
    private static func makeSpeechAnalyzerSnapshot(
        locale: Locale,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus,
        recognizerAvailable: Bool,
        simulatorReason: String,
        result: SpeechAnalyzerPreflightResult
    ) -> STTDiagnosticsSnapshot {
        let backendDetails = [
            "文字起こしモード: ローカル",
            "SpeechAnalyzer トグル: ON",
            "Speech 権限: \(authorizationStatus.label)",
            "SFSpeechRecognizer: \(recognizerAvailable ? "利用可能" : "利用不可")"
        ]

        switch result {
        case .ready(let diagnostics):
            return STTDiagnosticsSnapshot(
                backendPanel: STTDiagnosticsPanel(
                    title: "Backend Status",
                    badgeText: "SpeechAnalyzer",
                    tone: .success,
                    summary: "SpeechAnalyzer preflight を通過し、優先使用できます。",
                    details: backendDetails
                ),
                assetPanel: STTDiagnosticsPanel(
                    title: "Asset Status",
                    badgeText: diagnostics.assetStatus,
                    tone: .success,
                    summary: "SpeechAnalyzer asset と locale の整合性を確認しました。",
                    details: makeSpeechAnalyzerAssetDetails(
                        locale: locale,
                        diagnostics: diagnostics
                    )
                ),
                fallbackReason: simulatorReason.isEmpty
                    ? "フォールバックは発生していません。SpeechAnalyzer を優先できます。"
                    : simulatorReason,
                testSummary: "SpeechAnalyzer preflight を実行し、availability / locale / asset / audio format を確認しました。",
                diagnosticModeLabel: "preflight 実行",
                generatedAt: Date()
            )

        case .unavailable(let reason, let diagnostics):
            return STTDiagnosticsSnapshot(
                backendPanel: STTDiagnosticsPanel(
                    title: "Backend Status",
                    badgeText: "Fallback",
                    tone: .warning,
                    summary: "SpeechAnalyzer preflight が通らないため、SFSpeechRecognizer を使用予定です。",
                    details: backendDetails
                ),
                assetPanel: STTDiagnosticsPanel(
                    title: "Asset Status",
                    badgeText: diagnostics.assetStatus == "unknown" ? "未準備" : diagnostics.assetStatus,
                    tone: .warning,
                    summary: reason.description,
                    details: makeSpeechAnalyzerAssetDetails(
                        locale: locale,
                        diagnostics: diagnostics
                    )
                ),
                fallbackReason: simulatorReason.isEmpty ? reason.description : simulatorReason,
                testSummary: "SpeechAnalyzer preflight を実行し、フォールバック条件を確認しました。",
                diagnosticModeLabel: "preflight 実行",
                generatedAt: Date()
            )
        }
    }

    @available(iOS 26.0, *)
    private static func makeSpeechAnalyzerAssetDetails(
        locale: Locale,
        diagnostics: SpeechAnalyzerDiagnostics
    ) -> [String] {
        [
            "要求 locale: \(locale.identifier)",
            "解決 locale: \(diagnostics.supportedLocale?.identifier ?? "なし")",
            "asset state: \(diagnostics.assetStatus)",
            "互換 audio format: \(diagnostics.compatibleFormatsDescription)",
            String(format: "preflight: %.1fms", diagnostics.checkDurationMs)
        ]
    }

    @available(iOS 26.0, *)
    private static func inspectSpeechAnalyzer(locale: Locale) async -> SpeechAnalyzerInspection {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return SpeechAnalyzerInspection(
                canUseSpeechAnalyzer: false,
                fallbackReason: "SpeechAnalyzer が \(locale.identifier) と等価な locale を解決できないため、SFSpeechRecognizer にフォールバックします。",
                assetBadge: "locale NG",
                assetTone: .warning,
                assetSummary: "SpeechAnalyzer locale が未対応です。",
                assetDetails: [
                    "要求 locale: \(locale.identifier)",
                    "supported locale: なし"
                ],
                testSummary: "SpeechAnalyzer locale 判定で停止しました。"
            )
        }

        let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .transcription)
        let assetStatus = await AssetInventory.status(forModules: [transcriber])
        let compatibleFormats = await transcriber.availableCompatibleAudioFormats
        let formatLine = compatibleFormats.isEmpty
            ? "互換 audio format: 取得なし"
            : "互換 audio format: \(compatibleFormats.prefix(2).map { String(describing: $0) }.joined(separator: ", "))"

        if assetStatus == .installed {
            return SpeechAnalyzerInspection(
                canUseSpeechAnalyzer: true,
                fallbackReason: "フォールバックは発生していません。SpeechAnalyzer asset はインストール済みです。",
                assetBadge: "installed",
                assetTone: .success,
                assetSummary: "SpeechAnalyzer asset は利用可能です。",
                assetDetails: [
                    "要求 locale: \(locale.identifier)",
                    "解決 locale: \(supportedLocale.identifier)",
                    "asset state: \(String(describing: assetStatus))",
                    formatLine
                ],
                testSummary: "現在の asset / locale 状態から SpeechAnalyzer を優先できると判定しました。"
            )
        }

        return SpeechAnalyzerInspection(
            canUseSpeechAnalyzer: false,
            fallbackReason: "SpeechAnalyzer asset が \(String(describing: assetStatus)) のため、準備完了まで SFSpeechRecognizer にフォールバックします。",
            assetBadge: String(describing: assetStatus),
            assetTone: .warning,
            assetSummary: "SpeechAnalyzer asset はまだ準備完了ではありません。",
            assetDetails: [
                "要求 locale: \(locale.identifier)",
                "解決 locale: \(supportedLocale.identifier)",
                "asset state: \(String(describing: assetStatus))",
                formatLine
            ],
            testSummary: "現在の asset 状態からフォールバック候補を判定しました。"
        )
    }
}

private struct SpeechAnalyzerInspection {
    let canUseSpeechAnalyzer: Bool
    let fallbackReason: String
    let assetBadge: String
    let assetTone: STTDiagnosticsTone
    let assetSummary: String
    let assetDetails: [String]
    let testSummary: String
}

private struct STTDiagnosticsSnapshot {
    let backendPanel: STTDiagnosticsPanel
    let assetPanel: STTDiagnosticsPanel
    let fallbackReason: String
    let testSummary: String
    let diagnosticModeLabel: String
    let generatedAt: Date

    var generatedAtText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: generatedAt)
    }
}

private struct STTDiagnosticsPanel {
    let title: String
    let badgeText: String
    let tone: STTDiagnosticsTone
    let summary: String
    let details: [String]
}

private enum STTDiagnosticsTone {
    case success
    case warning
    case neutral

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .neutral:
            return "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .success:
            return MemoraColor.accentGreen
        case .warning:
            return .orange
        case .neutral:
            return MemoraColor.textSecondary
        }
    }

    var background: Color {
        switch self {
        case .success:
            return MemoraColor.accentGreen.opacity(0.12)
        case .warning:
            return Color.orange.opacity(0.12)
        case .neutral:
            return MemoraColor.divider.opacity(0.18)
        }
    }
}

private struct STTDiagnosticsCard: View {
    let panel: STTDiagnosticsPanel

    init(_ panel: STTDiagnosticsPanel) {
        self.panel = panel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(panel.title)
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    Text(panel.summary)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(panel.badgeText, systemImage: panel.tone.iconName)
                    .font(MemoraTypography.caption1)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 6)
                    .background(panel.tone.background)
                    .clipShape(Capsule())
                    .foregroundStyle(panel.tone.tint)
            }

            ForEach(panel.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: MemoraSpacing.xs) {
                    Circle()
                        .fill(MemoraColor.textTertiary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)

                    Text(detail)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
    }
}

private struct STTLastExecutionCard: View {
    let entry: STTBackendDiagnosticEntry

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Execution")
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    Text(entry.backend.rawValue)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.recordedAtText)
                    .font(MemoraTypography.caption2)
                    .foregroundStyle(MemoraColor.textTertiary)
            }

            VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                labeledLine("task", value: entry.taskId)
                labeledLine("locale", value: entry.locale)
                if let assetState = entry.assetState {
                    labeledLine("asset", value: assetState)
                }
                if let audioFormat = entry.audioFormat, !audioFormat.isEmpty {
                    labeledLine("format", value: audioFormat)
                }
                if let processingTimeMs = entry.processingTimeMs {
                    labeledLine("time", value: String(format: "%.1fms", processingTimeMs))
                }
                if let fallbackReason = entry.fallbackReason, !fallbackReason.isEmpty {
                    labeledLine("fallback", value: fallbackReason)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
    }

    @ViewBuilder
    private func labeledLine(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: MemoraSpacing.xs) {
            Text("\(title):")
                .font(MemoraTypography.caption1)
                .foregroundStyle(MemoraColor.textSecondary)

            Text(value)
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)
        }
    }
}

private extension SFSpeechRecognizerAuthorizationStatus {
    var label: String {
        switch self {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "unknown"
        }
    }
}

private extension STTBackendDiagnosticEntry {
    var recordedAtText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: recordedAt)
    }
}

private struct NotionPagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let token: String
    @Binding var selectedPageID: String
    @Binding var isPresented: Bool

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [NotionService.NotionSearchResult] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.gray)
                        Spacer()
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)
                } else if searchResults.isEmpty {
                    Text("ページが見つかりませんでした")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(searchResults, id: \.id) { page in
                        Button {
                            selectedPageID = page.id
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title ?? "（無題）")
                                        .font(MemoraTypography.subheadline)
                                        .foregroundStyle(.primary)

                                    Text(page.type ?? "page")
                                        .font(MemoraTypography.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if page.id == selectedPageID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(MemoraColor.accentBlue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "ページを検索")
            .onChange(of: searchText) { _, newValue in
                Task { await searchNotionPages(query: newValue) }
            }
            .navigationTitle("Notion ページ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
            .task {
                await searchNotionPages(query: "")
            }
        }
    }

    private func searchNotionPages(query: String) async {
        isSearching = true
        errorMessage = nil

        do {
            let service = NotionService()
            searchResults = try await service.searchPages(token: token, query: query)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(OmiAdapter())
        .environmentObject(BluetoothAudioService())
}
