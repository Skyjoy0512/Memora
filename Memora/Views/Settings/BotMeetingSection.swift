import SwiftUI
import SwiftData

struct BotMeetingSection: View {
    @Bindable var state: SettingsState
    @Environment(\.modelContext) private var modelContext
    @Query private var configList: [BotMeetingConfig]
    @State private var viewModel = BotMeetingViewModel()

    private var config: BotMeetingConfig? {
        configList.first
    }

    var body: some View {
        Section {
            Toggle("Bot 参加を有効化", isOn: Binding(
                get: { config?.isEnabled ?? false },
                set: { newValue in
                    let c = getOrCreateConfig()
                    c.isEnabled = newValue
                    c.updatedAt = Date()
                    try? modelContext.save()

                    if newValue {
                        viewModel.updateServerConfig(url: c.serverURL, apiKey: c.apiKey)
                    }
                }
            ))

            if config?.isEnabled == true {
                TextField("サーバーURL", text: Binding(
                    get: { config?.serverURL ?? "" },
                    set: { newValue in
                        let c = getOrCreateConfig()
                        c.serverURL = newValue
                        c.updatedAt = Date()
                        try? modelContext.save()
                        viewModel.updateServerConfig(url: newValue, apiKey: c.apiKey)
                    }
                ))
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .font(.system(.body, design: .monospaced))

                SecureField("API キー", text: Binding(
                    get: { config?.apiKey ?? "" },
                    set: { newValue in
                        let c = getOrCreateConfig()
                        c.apiKey = newValue
                        c.updatedAt = Date()
                        try? modelContext.save()
                        viewModel.updateServerConfig(url: c.serverURL, apiKey: newValue)
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))

                HStack(spacing: MemoraSpacing.sm) {
                    switch viewModel.connectionStatus {
                    case .unknown:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("接続テスト中...")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)
                    case .connected:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentGreen)
                        Text("接続成功")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentGreen)
                    case .failed(let msg):
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentRed)
                        Text(msg)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentRed)
                    }
                }

                Button {
                    Task {
                        let c = getOrCreateConfig()
                        viewModel.updateServerConfig(url: c.serverURL, apiKey: c.apiKey)
                        viewModel.configure(botService: BotMeetingService(), modelContext: modelContext)
                        await viewModel.testConnection()
                    }
                } label: {
                    HStack {
                        Text("接続テスト")
                        if viewModel.connectionStatus == .testing {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(viewModel.connectionStatus == .testing)

                NavigationLink {
                    BotMeetingStatusView(viewModel: viewModel)
                } label: {
                    Label("予約済み会議一覧", systemImage: "list.bullet.rectangle")
                }
            }
        } header: {
            GlassSectionHeader(title: "Bot 会議参加", icon: "bot.circle.fill")
        } footer: {
            Text("Bot サーバーを設定すると、Zoom / Google Meet / Teams の会議にBotが自動参加し録音します。サーバーのデプロイ手順は別途ドキュメントを参照してください。")
        }
        .onAppear {
            if let c = config {
                viewModel.updateServerConfig(url: c.serverURL, apiKey: c.apiKey)
                viewModel.configure(botService: BotMeetingService(), modelContext: modelContext)
            }
        }
    }

    private func getOrCreateConfig() -> BotMeetingConfig {
        if let existing = config {
            return existing
        }
        let newConfig = BotMeetingConfig()
        modelContext.insert(newConfig)
        return newConfig
    }
}

#Preview {
    List {
        BotMeetingSection(state: SettingsState())
    }
}
