import SwiftUI
import SwiftData

// MARK: - Developer Features Section

struct DeveloperFeaturesSection: View {
    @Bindable var state: SettingsState
#if DEBUG
    @Environment(\.modelContext) private var modelContext
    @Query private var plaudSettingsList: [PlaudSettings]

    private var plaudSettings: PlaudSettings? {
        plaudSettingsList.first
    }
#endif

    var body: some View {
        Section {
#if DEBUG
            // 非公式 API を使う開発用のログイン・同期 UI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(MemoraColor.accentBlue)
                    Text("PLAUDクラウド同期")
                        .font(MemoraTypography.subheadline)
                }
                Text("PLAUDアカウントを認可すると、新しい録音・文字起こし・要約をMemoraへ取り込めます。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
#endif

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

#if DEBUG
            // 非公式 API を使う開発用のログイン・同期 UI
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
#endif
        }
        #if DEBUG
        .task {
            state.isLoggedIn = PlaudMCPOAuthService().account().isConnected
        }
        #endif
    }

#if DEBUG
    @ViewBuilder
    private var plaudSettingsContent: some View {
        if state.isLoggedIn {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MemoraColor.accentGreen)
                    Text("PLAUDに接続済み")
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
                        await syncPlaudCloudRecordings()
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
            Button(action: {
                Task {
                    await connectPlaudCloud()
                }
            }) {
                HStack {
                    Text("PLAUDに接続")
                    if state.isPlaudSyncing {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(state.isPlaudSyncing)
        }
    }

    // MARK: - Plaud Actions

    private func connectPlaudCloud() async {
        state.isPlaudSyncing = true
        defer {
            state.isPlaudSyncing = false
            state.showPlaudStatusAlert = true
        }
        do {
            try await PlaudMCPOAuthService().connect()
            if let settings = plaudSettings {
                settings.isEnabled = true
                settings.updatedAt = Date()
                try modelContext.save()
            }
            state.isLoggedIn = true
            state.plaudSyncStatus = "PLAUDに接続しました"
        } catch {
            state.plaudSyncStatus = error.localizedDescription
        }
    }

    private func syncPlaudCloudRecordings() async {
        state.isPlaudSyncing = true
        defer {
            state.isPlaudSyncing = false
            state.showPlaudStatusAlert = true
        }
        do {
            let result = try await PlaudCloudSyncService(modelContext: modelContext).sync()
            if let settings = plaudSettings {
                settings.lastSyncAt = Date()
                settings.updatedAt = Date()
                try modelContext.save()
            }
            var message = "\(result.importedCount)件の録音を取り込みました"
            if result.skippedCount > 0 { message += "（\(result.skippedCount)件は同期済み）" }
            if result.failedCount > 0 { message += "（\(result.failedCount)件は失敗）" }
            state.plaudSyncStatus = message
        } catch {
            state.plaudSyncStatus = error.localizedDescription
        }
    }

    private func logoutPlaud() {
        PlaudMCPOAuthService().disconnect()
        if let settings = plaudSettings {
            KeychainService.delete(key: .plaudAccessToken)
            KeychainService.delete(key: .plaudRefreshToken)
            KeychainService.saveDate(key: .plaudTokenExpiresAt, value: nil)
            settings.updatedAt = Date()
            try? modelContext.save()
        }

        state.isLoggedIn = false
        state.plaudPassword = ""
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
#endif
}
