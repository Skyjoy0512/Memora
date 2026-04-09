import SwiftUI
import SwiftData

enum MainTab: Hashable {
    case files
    case projects
    case todo
    case settings
}

struct ContentView: View {
    @StateObject private var bluetoothService = BluetoothAudioService()
    @StateObject private var omiAdapter = OmiAdapter()
    @Environment(\.modelContext) private var modelContext
    @State private var isBluetoothConfigured = false
    @Query private var googleSettingsList: [GoogleMeetSettings]
    @State private var selectedTab: MainTab = .files
    @State private var pendingOpenedAudioFileID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(pendingOpenedAudioFileID: $pendingOpenedAudioFileID)
                .tabItem { Label("Files", systemImage: "folder.fill") }
                .tag(MainTab.files)

            ProjectsView()
                .tabItem { Label("Projects", systemImage: "rectangle.stack.fill") }
                .tag(MainTab.projects)

            ToDoView()
                .tabItem { Label("ToDo", systemImage: "checkmark.circle") }
                .tag(MainTab.todo)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .environmentObject(bluetoothService)
        .environmentObject(omiAdapter)
        .onAppear {
            DebugLogger.shared.markLaunchStep("ContentView.onAppear")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                configureOmiAdapterIfNeeded()
                DebugLogger.shared.markLaunchStep("OmiAdapter 設定完了（遅延）")
                isBluetoothConfigured = true
            }
        }
        .onChange(of: omiAdapter.lastImportedAudio) { _, importedAudio in
            guard let importedAudio else { return }
            selectedTab = .files
            pendingOpenedAudioFileID = importedAudio.audioFileID
        }
    }

    private func configureOmiAdapterIfNeeded() {
        omiAdapter.configureAudioImportHandler { sourceURL, suggestedTitle in
            try await MainActor.run {
                try AudioFileImportService.importOmiAudio(
                    from: sourceURL,
                    suggestedTitle: suggestedTitle,
                    modelContext: modelContext
                )
            }
        }
    }
}

// MARK: - SpeechAPIInfoView

struct SpeechAPIInfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SpeechAnalyzer API チェック")
                .font(MemoraTypography.title2)
                .fontWeight(.semibold)

            Divider()

            if #available(iOS 26.0, *) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: SpeechAnalyzerFeatureFlag.isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(SpeechAnalyzerFeatureFlag.isEnabled ? MemoraColor.accentGreen : MemoraColor.accentRed)
                        Text("iOS 26 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()

                    if SpeechAnalyzerFeatureFlag.isEnabled {
                        Text("SpeechAnalyzer（ベータ）が有効です")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentGreen)
                            .padding(.horizontal)
                    } else {
                        Text("SpeechAnalyzer は現在無効です（設定から有効化可能）")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                Text("iOS 26 SpeechAnalyzer API はベータ版です。設定から有効にできます。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(MemoraColor.accentBlue)
                        Text("iOS 10-25 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                Text("現在は SFSpeechRecognizer を使用し、SpeechAnalyzer 非対応端末をカバーします。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }

            Divider()

            Text("iOS バージョン: \(UIDevice.current.systemVersion)")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)

            Button("OK", role: .cancel) { }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .padding()
    }
}

#Preview {
    SpeechAPIInfoView()
}
