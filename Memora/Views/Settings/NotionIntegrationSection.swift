import SwiftUI
import SwiftData

// MARK: - Notion Integration Section

struct NotionIntegrationSection: View {
    @Bindable var state: SettingsState
    @Environment(\.modelContext) private var modelContext
    @Query private var notionSettingsList: [NotionSettings]

    private var notionSettings: NotionSettings? {
        notionSettingsList.first
    }

    var body: some View {
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
                    get: { state.notionToken },
                    set: { newValue in
                        state.notionToken = newValue
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

                if !state.notionToken.isEmpty {
                    // 親ページ選択
                    HStack {
                        TextField("親ページ ID", text: Binding(
                            get: { state.selectedNotionPageID ?? state.notionParentPageID },
                            set: { newValue in
                                state.notionParentPageID = newValue
                                state.selectedNotionPageID = newValue
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
                            state.showNotionPagePicker = true
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
                            if state.isNotionTesting {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(state.isNotionTesting || state.notionToken.isEmpty)

                    if let result = state.notionTestResult {
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
            GlassSectionHeader(title: "Notion 連携", icon: "square.stack.3d.up")
        } footer: {
            Text("会議の文字起こし・要約を Notion ページとしてエクスポートします。notion.so/my-integrations から Internal Integration Token を取得してください。")
        }
        .sheet(isPresented: $state.showNotionPagePicker) {
            NotionPagePickerView(
                token: state.notionToken,
                selectedPageID: Binding(
                    get: { state.selectedNotionPageID ?? state.notionParentPageID },
                    set: { newValue in
                        state.selectedNotionPageID = newValue
                        state.notionParentPageID = newValue
                        if let settings = notionSettings {
                            settings.parentPageID = newValue
                            settings.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                ),
                isPresented: $state.showNotionPagePicker
            )
        }
    }

    // MARK: - Actions

    private func testNotionConnection() async {
        state.isNotionTesting = true
        state.notionTestResult = nil

        do {
            let service = NotionService()
            let user = try await service.testConnection(token: state.notionToken)
            state.notionTestResult = "接続成功: \(user.name ?? "ユーザー")"
        } catch {
            state.notionTestResult = "接続テストに失敗しました。トークンを確認してください。"
            print("Notion接続テストエラー: \(error.localizedDescription)")
        }

        state.isNotionTesting = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
