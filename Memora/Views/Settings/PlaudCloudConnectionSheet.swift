import BackgroundTasks
import SwiftUI
import SwiftData

struct PlaudCloudConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [PlaudSettings]

    @State private var isConnected = false
    @State private var isWorking = false
    @State private var statusMessage: String?

    private var settings: PlaudSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.blue)
                        Text("PLAUDクラウド同期")
                            .font(.title3.bold())
                        Text("PLAUDで認可した録音、文字起こし、要約をMemoraへ取り込みます。パスワードはMemoraに保存されません。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if isConnected {
                    Section("同期") {
                        LabeledContent("状態") {
                            Label("接続済み", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Toggle("自動同期", isOn: Binding(get: { settings?.autoSyncEnabled ?? true }, set: updateAutoSync))
                        Text("Memoraを開いた時と、iOSが許可したバックグラウンド処理時に新しい録音を確認します。実行時刻はiOSが決定します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button { Task { await syncNow() } } label: {
                            HStack {
                                Text("今すぐ同期")
                                Spacer()
                                if isWorking { ProgressView() }
                            }
                        }
                        .disabled(isWorking)
                        if let lastSyncAt = settings?.lastSyncAt {
                            LabeledContent("最終同期", value: lastSyncAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                        }
                    }
                    Section {
                        Button("連携を解除", role: .destructive, action: disconnect)
                    }
                } else {
                    Section {
                        Button { Task { await connect() } } label: {
                            HStack {
                                Text("PLAUDに接続")
                                Spacer()
                                if isWorking { ProgressView() }
                            }
                        }
                        .disabled(isWorking)
                    } footer: {
                        Text("タップするとPLAUDの認可画面が開き、認可後にMemoraへ戻ります。")
                    }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(statusMessage.contains("失敗") ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("PLAUD連携")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { isConnected = PlaudMCPOAuthService().account().isConnected }
        }
    }

    private func connect() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await PlaudMCPOAuthService().connect()
            let storedSettings = settings ?? PlaudSettings()
            if settings == nil { modelContext.insert(storedSettings) }
            storedSettings.isEnabled = true
            storedSettings.autoSyncEnabled = true
            storedSettings.updatedAt = Date()
            try modelContext.save()
            isConnected = true
            statusMessage = "PLAUDに接続しました"
            PlaudBackgroundSyncScheduler.shared.scheduleNextSync()
        } catch {
            statusMessage = "接続に失敗しました: \(error.localizedDescription)"
        }
    }

    private func syncNow() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await PlaudCloudSyncService(modelContext: modelContext).sync()
            if let settings {
                settings.lastSyncAt = Date()
                settings.updatedAt = Date()
                try modelContext.save()
            }
            statusMessage = "\(result.importedCount)件を取り込みました。\(result.skippedCount)件は同期済みです。"
        } catch {
            statusMessage = "同期に失敗しました: \(error.localizedDescription)"
        }
    }

    private func updateAutoSync(_ enabled: Bool) {
        guard let settings else { return }
        settings.autoSyncEnabled = enabled
        settings.updatedAt = Date()
        try? modelContext.save()
        if enabled { PlaudBackgroundSyncScheduler.shared.scheduleNextSync() }
        else { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PlaudBackgroundSyncScheduler.identifier) }
    }

    private func disconnect() {
        PlaudMCPOAuthService().disconnect()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PlaudBackgroundSyncScheduler.identifier)
        if let settings {
            settings.isEnabled = false
            settings.updatedAt = Date()
            try? modelContext.save()
        }
        isConnected = false
        statusMessage = "PLAUD連携を解除しました"
    }
}
