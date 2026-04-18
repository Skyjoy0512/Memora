import SwiftUI
import SwiftData

// MARK: - Developer Features Section

struct DeveloperFeaturesSection: View {
    @Bindable var state: SettingsState
    @Environment(\.modelContext) private var modelContext
    @Query private var plaudSettingsList: [PlaudSettings]

    private var plaudSettings: PlaudSettings? {
        plaudSettingsList.first
    }

    var body: some View {
        Section {
            // Plaud エクスポートインポート説明
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

            // Gemma 4 Experimental
            VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                HStack {
                    Image(systemName: "flask")
                        .foregroundStyle(.purple)
                    Text("Gemma 4 実験プロファイル")
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)
                }

                if Gemma4DeviceGate.isEligible {
                    Toggle(isOn: Binding(
                        get: { Gemma4FeatureFlag.isEnabled },
                        set: { Gemma4FeatureFlag.isEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gemma 4 プロファイルを有効化")
                            Text("Local 選択時に Foundation Models を Gemma 4 プロファイル経由で使用します。")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if Gemma4FeatureFlag.isEnabled {
                        HStack(spacing: MemoraSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MemoraColor.accentGreen)
                            Text("Gemma 4 実験プロファイル有効")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentGreen)
                        }

                        Text(Gemma4DeviceGate.deviceSummary)
                            .font(MemoraTypography.caption2)
                            .foregroundStyle(MemoraColor.textTertiary)

                        NavigationLink {
                            Gemma4BenchmarkView()
                        } label: {
                            HStack(spacing: MemoraSpacing.sm) {
                                Image(systemName: "gauge.with.dots.needle.33percent")
                                    .foregroundStyle(MemoraColor.accentBlue)
                                Text("ベンチマークを実行")
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: MemoraSpacing.xs) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(MemoraColor.accentRed)
                            Text("このデバイスでは利用できません")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentRed)
                        }

                        if let reason = Gemma4DeviceGate.ineligibilityReason {
                            Text(reason)
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }

                        Text(Gemma4DeviceGate.deviceSummary)
                            .font(MemoraTypography.caption2)
                            .foregroundStyle(MemoraColor.textTertiary)
                    }
                }
            }
            .padding(.vertical, MemoraSpacing.xxxs)

            // Plaud 連携 Toggle
            Toggle("Plaud 連携を有効化", isOn: Binding(
                get: { plaudSettings?.isEnabled ?? false },
                set: { newValue in
                    if let settings = plaudSettings {
                        settings.isEnabled = newValue
                        settings.updatedAt = Date()
                    } else if newValue {
                        let newSettings = PlaudSettings()
                        newSettings.isEnabled = true
                        newSettings.apiServer = state.plaudApiServer
                        newSettings.email = state.plaudEmail
                        newSettings.password = state.plaudPassword
                        newSettings.autoSyncEnabled = state.plaudAutoSyncEnabled
                        modelContext.insert(newSettings)
                    } else {
                        return
                    }
                    try? modelContext.save()
                }
            ))

            // Plaud 設定 UI
            if plaudSettings?.isEnabled ?? false {
                plaudSettingsContent
            }
        }
    }

    @ViewBuilder
    private var plaudSettingsContent: some View {
        if state.isLoggedIn {
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
                        if state.isPlaudSyncing {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(state.isPlaudSyncing)

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
            Picker("API サーバー", selection: $state.plaudApiServer) {
                Text("api.plaud.ai").tag("api.plaud.ai")
                Text("api-euc1.plaud.ai").tag("api-euc1.plaud.ai")
                Text("カスタム").tag("custom")
            }
            .pickerStyle(.menu)

            if state.plaudApiServer == "custom" {
                TextField("カスタム API サーバー", text: $state.plaudServerURL)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            TextField("メールアドレス", text: $state.plaudEmail)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("パスワード", text: $state.plaudPassword)
                .textFieldStyle(.plain)

            Button(action: {
                Task {
                    await loginPlaud()
                }
            }) {
                HStack {
                    Text("ログイン")
                    if state.isPlaudSyncing {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(state.isPlaudSyncing || state.plaudEmail.isEmpty || state.plaudPassword.isEmpty)
        } header: {
            GlassSectionHeader(title: "開発者機能", icon: "hammer")
        }
    }

    // MARK: - Plaud Actions

    private func loginPlaud() async {
        state.isPlaudSyncing = true

        do {
            let service = PlaudService()

            // API サーバーを決定
            let server = state.plaudApiServer == "custom" ? state.plaudServerURL : state.plaudApiServer

            // ログイン
            let authResponse = try await service.login(
                apiServer: server,
                email: state.plaudEmail,
                password: state.plaudPassword
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
            settings.email = state.plaudEmail
            settings.password = state.plaudPassword
            settings.accessToken = authResponse.accessToken
            settings.refreshToken = authResponse.refreshToken
            settings.userId = userInfo.id
            settings.tokenExpiresAt = authResponse.calculatedExpiresAt
            settings.updatedAt = Date()

            try? modelContext.save()

            state.isLoggedIn = true
            state.plaudSyncStatus = "ログインに成功しました"
        } catch {
            state.plaudSyncStatus = "ログインに失敗しました。メールアドレスとパスワードを確認してください。"
            print("Plaudログインエラー: \(error.localizedDescription)")
        }

        state.isPlaudSyncing = false
        state.showPlaudStatusAlert = true
    }

    private func logoutPlaud() {
        if let settings = plaudSettings {
            settings.accessToken = ""
            settings.refreshToken = ""
            settings.tokenExpiresAt = nil
            settings.updatedAt = Date()
            try? modelContext.save()
        }

        state.isLoggedIn = false
        state.plaudPassword = ""
    }

    private func syncPlaudRecordings() async {
        state.isPlaudSyncing = true

        guard let settings = plaudSettings else {
            state.plaudSyncStatus = "設定が見つかりません"
            state.isPlaudSyncing = false
            state.showPlaudStatusAlert = true
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
                state.plaudSyncStatus = "セッションの更新に失敗しました。再度ログインしてください。"
                print("Plaudトークンリフレッシュエラー: \(error.localizedDescription)")
                state.isPlaudSyncing = false
                state.showPlaudStatusAlert = true
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
            state.plaudSyncStatus = statusMessage
        } catch {
            state.plaudSyncStatus = "同期に失敗しました。しばらくしてから再度お試しください。"
            print("Plaud同期エラー: \(error.localizedDescription)")
        }

        state.isPlaudSyncing = false
        state.showPlaudStatusAlert = true
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
