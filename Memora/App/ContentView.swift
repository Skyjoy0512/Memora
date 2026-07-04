import SwiftUI
import SwiftData

// MARK: - Content View

struct ContentView: View {
    @State private var bluetoothService = BluetoothAudioService()
    @State private var omiAdapter = OmiAdapter()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBluetoothConfigured = false
    @Query private var googleSettingsList: [GoogleMeetSettings]
    @State private var selectedTab: Int = 0
    @State private var pendingOpenedAudioFileID: UUID?
    @State private var isTabBarHidden = false
    @State private var triggerRecording = false
    @State private var triggerFileImport = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                pendingOpenedAudioFileID: $pendingOpenedAudioFileID,
                isTabBarHidden: $isTabBarHidden,
                triggerRecording: $triggerRecording,
                triggerFileImport: $triggerFileImport
            )
            .tabItem { Label("ホーム", systemImage: "house") }
            .tag(0)

            ToDoView()
                .tabItem { Label("ToDo", systemImage: "checkmark.circle") }
                .tag(1)

            AskAIView(scope: .global)
                .tabItem { Label("Ask AI", systemImage: "sparkles") }
                .tag(2)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(3)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTabBarHidden)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selectedTab)
        .environment(bluetoothService)
        .environment(omiAdapter)
        .task {
            DebugLogger.shared.markLaunchStep("ContentView.task")
            try? await Task.sleep(for: .seconds(1.5))
            configureOmiAdapterIfNeeded()
            DebugLogger.shared.markLaunchStep("OmiAdapter 設定完了（遅延）")
            isBluetoothConfigured = true
        }
        .onChange(of: omiAdapter.lastImportedAudio) { _, importedAudio in
            guard let importedAudio else { return }
            selectedTab = 0
            pendingOpenedAudioFileID = importedAudio.audioFileID
        }
    }

    // MARK: - Omi Adapter

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
