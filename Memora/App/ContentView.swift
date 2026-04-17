import SwiftUI
import SwiftData

enum MainTab: Hashable {
    case files
    case projects
    case todo
    case askAI
    case settings
}

struct ContentView: View {
    @State private var bluetoothService = BluetoothAudioService()
    @State private var omiAdapter = OmiAdapter()
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

            AskAIView(scope: .global)
                .tabItem { Label("Ask AI", systemImage: "sparkle") }
                .tag(MainTab.askAI)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .tint(MemoraColor.accentNothing)
        .nothingTheme(showDotMatrix: true)
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
