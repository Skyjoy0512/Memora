import SwiftUI
import SwiftData

// MARK: - Content View

struct ContentView: View {
    @State private var bluetoothService = BluetoothAudioService()
    @State private var omiAdapter = OmiAdapter()
    @Environment(\.modelContext) private var modelContext
    @State private var isBluetoothConfigured = false
    @Query private var googleSettingsList: [GoogleMeetSettings]
    @State private var selectedTab: Int = 0
    @State private var pendingOpenedAudioFileID: UUID?
    @State private var isFABExpanded = false
    @State private var isTabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                HomeView(
                    pendingOpenedAudioFileID: $pendingOpenedAudioFileID,
                    isTabBarHidden: $isTabBarHidden
                )
                .tabItem { Label("Files", systemImage: "folder.fill") }
                .tag(0)

                ProjectsView(isTabBarHidden: $isTabBarHidden)
                    .tabItem { Label("Projects", systemImage: "rectangle.stack.fill") }
                    .tag(1)

                ToDoView()
                    .tabItem { Label("ToDo", systemImage: "checkmark.circle") }
                    .tag(2)

                AskAIView(scope: .global)
                    .tabItem { Label("Ask AI", systemImage: "sparkle") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(4)
            }
            .tint(.black)

            // FAB (only on Files tab, hidden on detail pages)
            if selectedTab == 0 && !isTabBarHidden {
                fabView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isTabBarHidden)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
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
            selectedTab = 0
            pendingOpenedAudioFileID = importedAudio.audioFileID
        }
    }

    // MARK: - FAB

    private var fabView: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isFABExpanded {
                fabMenu
                    .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
            }

            fabButton
        }
        .padding(.trailing, 16)
        .padding(.bottom, 80)
    }

    private var fabButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isFABExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(isFABExpanded ? 45 : 0))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(FABGlassButtonStyle())
    }

    // MARK: - FAB Menu

    private var fabMenu: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isFABExpanded = false
                }
                selectedTab = 0
            } label: {
                Label("録音", systemImage: "mic.fill")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            Divider().padding(.leading, 44)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isFABExpanded = false
                }
                selectedTab = 0
            } label: {
                Label("インポート", systemImage: "square.and.arrow.down")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .frame(width: 180)
        .background(fabMenuBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private var fabMenuBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
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

// MARK: - FAB Glass Button Style

struct FABGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            configuration.label
                .background(Color.black)
                .clipShape(Circle())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}
