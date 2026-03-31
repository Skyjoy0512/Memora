import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.repositoryFactory) private var repoFactory
    @EnvironmentObject private var bluetoothService: BluetoothAudioService
    @AppStorage("selectedProvider") private var selectedProvider: String = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @State private var showDeleteAlert = false
    @State private var isBluetoothEnabled = false

    // Plaud 設定
    @Query private var plaudSettingsList: [PlaudSettings]
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

    var plaudSettings: PlaudSettings? {
        plaudSettingsList.first
    }

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    var body: some View {
        NavigationStack {
            List {
                transcriptionSettingsSection
                aiProviderSection
                apiKeySection
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
            isBluetoothEnabled = bluetoothService.isConnected
        }
        .onChange(of: bluetoothService.isConnected) { newValue in
            isBluetoothEnabled = newValue
        }
        .onChange(of: bluetoothService.isScanning) { _ in
            isBluetoothEnabled = bluetoothService.isConnected
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
        Section("デバイス接続") {
            if bluetoothService.isConnected {
                VStack(spacing: 13) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text("デバイスに接続されています")
                        .font(MemoraTypography.subheadline)

                    if let device = bluetoothService.discoveredDevices.first {
                        Text(device.name)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: { bluetoothService.disconnect() }) {
                        Text("切断")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, MemoraSpacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.accentRed)
                            .cornerRadius(MemoraRadius.sm)
                    }
                }
            } else if bluetoothService.isScanning {
                HStack(spacing: 13) {
                    ProgressView()
                        .tint(.gray)
                    Text("デバイスを検索中...")
                        .font(MemoraTypography.subheadline)
                }
            } else if !bluetoothService.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("発見したデバイス")
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    ForEach(bluetoothService.discoveredDevices) { device in
                        Button(action: { bluetoothService.connect(to: device) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(MemoraColor.textSecondary)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(MemoraTypography.subheadline)
                                        .foregroundStyle(.primary)

                                    Text("RSSI: \(device.rssi) dBm")
                                        .font(MemoraTypography.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(MemoraSpacing.xs)
                        }
                        .background(MemoraColor.divider.opacity(MemoraOpacity.medium))
                        .cornerRadius(MemoraRadius.sm)
                    }
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

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("再スキャン", systemImage: "arrow.clockwise")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, MemoraSpacing.xs)
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
        Section("リアルタイム転写") {
            if bluetoothService.isConnected {
                VStack(spacing: 13) {
                    // デバイス接続ステータス
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentGreen)
                        Text("デバイスに接続されています")
                            .font(MemoraTypography.subheadline)
                    }

                    // 録音時間表示
                    if bluetoothService.isRecording {
                        VStack(spacing: 4) {
                            Text("録音中")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentRed)
                            Text(formatRecordingTime(bluetoothService.recordingDuration))
                                .font(MemoraTypography.title2)
                                .fontDesign(.monospaced)
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, MemoraSpacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(MemoraColor.accentRed.opacity(MemoraOpacity.medium))
                        .cornerRadius(MemoraRadius.sm)
                    }

                    // 録音制御ボタン
                    HStack(spacing: 13) {
                        if bluetoothService.isRecording {
                            Button(action: {
                                bluetoothService.stopRecording()
                            }) {
                                HStack {
                                    Image(systemName: "stop.circle.fill")
                                    Text("停止")
                                }
                                .font(MemoraTypography.subheadline)
                                .foregroundStyle(.white)
                                .padding(.vertical, MemoraSpacing.sm)
                                .frame(maxWidth: .infinity)
                                .background(MemoraColor.accentRed)
                                .cornerRadius(MemoraRadius.sm)
                            }
                        } else {
                            Button(action: {
                                bluetoothService.startRecording()
                            }) {
                                HStack {
                                    Image(systemName: "record.circle.fill")
                                    Text("録音開始")
                                }
                                .font(MemoraTypography.subheadline)
                                .foregroundStyle(.white)
                                .padding(.vertical, MemoraSpacing.sm)
                                .frame(maxWidth: .infinity)
                                .background(MemoraColor.accentRed)
                                .cornerRadius(MemoraRadius.sm)
                            }
                        }

                        Button(action: {
                            bluetoothService.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("切断")
                            }
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, MemoraSpacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(MemoraColor.divider)
                            .cornerRadius(MemoraRadius.sm)
                        }
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

                    Button(action: { bluetoothService.startScanning() }) {
                        Label("デバイスを検索", systemImage: "magnifyingglass")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.white)
                            .padding(.vertical, MemoraSpacing.xs)
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
            Section("BLE デバッグ（開発者向け）") {
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
                        if let factory = repoFactory {
                            try? factory.plaudSettingsRepo.save(newSettings)
                        } else {
                            modelContext.insert(newSettings)
                        }
                    } else {
                        return
                    }
                    if repoFactory == nil {
                        try? modelContext.save()
                    }
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
                                    if let factory = repoFactory {
                                        try? factory.plaudSettingsRepo.save(settings)
                                    } else {
                                        try? modelContext.save()
                                    }
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
                if let factory = repoFactory {
                    try? factory.plaudSettingsRepo.save(settings)
                } else {
                    modelContext.insert(settings)
                }
            }

            settings.apiServer = server
            settings.email = plaudEmail
            settings.password = plaudPassword
            settings.accessToken = authResponse.accessToken
            settings.refreshToken = authResponse.refreshToken
            settings.userId = userInfo.id
            settings.tokenExpiresAt = authResponse.calculatedExpiresAt
            settings.updatedAt = Date()

            if let factory = repoFactory {
                try? factory.plaudSettingsRepo.save(settings)
            } else {
                try? modelContext.save()
            }

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
            if let factory = repoFactory {
                try? factory.plaudSettingsRepo.save(settings)
            } else {
                try? modelContext.save()
            }
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
                if let factory = repoFactory {
                    try? factory.plaudSettingsRepo.save(settings)
                } else {
                    try? modelContext.save()
                }
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

                if let factory = repoFactory {
                    try? factory.audioFileRepo.save(audioFile)
                } else {
                    modelContext.insert(audioFile)
                }

                // 文字起こしがあれば Transcript を作成
                if let transcriptText = recording.transcript, !transcriptText.isEmpty {
                    let transcript = Transcript(
                        audioFileID: audioFile.id,
                        text: transcriptText
                    )
                    transcript.createdAt = recording.createdAt
                    audioFile.isTranscribed = true
                    if let factory = repoFactory {
                        try? factory.transcriptRepo.save(transcript)
                    } else {
                        modelContext.insert(transcript)
                    }
                }

                importedCount += 1
            }

            if repoFactory == nil {
                try modelContext.save()
            }

            // 最終同期日時を更新
            if let settings = plaudSettings {
                settings.lastSyncAt = Date()
                settings.updatedAt = Date()
                if let factory = repoFactory {
                    try? factory.plaudSettingsRepo.save(settings)
                } else {
                    try? modelContext.save()
                }
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

#Preview {
    SettingsView()
        .environmentObject(BluetoothAudioService())
}
