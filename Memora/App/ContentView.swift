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
    @State private var isFABExpanded = false
    @State private var isTabBarHidden = false
    @State private var triggerRecording = false
    @State private var triggerFileImport = false
    @State private var triggerMeetingCapture = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                HomeView(
                    pendingOpenedAudioFileID: $pendingOpenedAudioFileID,
                    isTabBarHidden: $isTabBarHidden,
                    triggerRecording: $triggerRecording,
                    triggerFileImport: $triggerFileImport,
                    triggerMeetingCapture: $triggerMeetingCapture
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
            .tint(MemoraColor.interactivePrimary)

            // FAB (only on Files tab, hidden on detail pages)
            if selectedTab == 0 && !isTabBarHidden {
                if isFABExpanded {
                    fabDismissBackdrop
                        .transition(.opacity)
                        .zIndex(1)
                }

                fabView
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTabBarHidden)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selectedTab)
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
                    .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
            }

            fabButton
        }
        .padding(.trailing, 18)
        .padding(.bottom, 78)
    }

    private var fabDismissBackdrop: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.3, dampingFraction: 0.82)) {
                    isFABExpanded = false
                }
            }
    }

    private var fabButton: some View {
        Button {
            MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.35, dampingFraction: 0.7)) {
                isFABExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(isFABExpanded ? 45 : 0))
                .frame(width: 64, height: 64)
                .contentShape(Circle())
        }
        .buttonStyle(FABGlassButtonStyle())
        .accessibilityLabel(isFABExpanded ? "アクションメニューを閉じる" : "アクションメニューを開く")
        .accessibilityHint("録音、インポート、会議キャプチャを選択します")
    }

    // MARK: - FAB Menu

    @ViewBuilder
    private var fabMenu: some View {
        let items: [FABActionItem] = [
            FABActionItem(title: "録音開始", icon: "mic.fill", tint: MemoraColor.accentRed) {
                closeFABAndRun { triggerRecording = true }
            },
            FABActionItem(title: "インポート", icon: "square.and.arrow.down.fill", tint: MemoraColor.accentBlue) {
                closeFABAndRun { triggerFileImport = true }
            },
            FABActionItem(title: "会議キャプチャ", icon: "waveform.circle.fill", tint: MemoraColor.accentGreen) {
                closeFABAndRun { triggerMeetingCapture = true }
            }
        ]

        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                fabMenuContent(items)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            }
        } else {
            fabMenuContent(items)
                .liquidGlass(cornerRadius: 24, opacity: 0.6, shadowRadius: 16)
        }
    }

    private func fabMenuContent(_ items: [FABActionItem]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                Button(action: item.action) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(item.tint, in: Circle())

                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MemoraColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MemoraColor.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 58)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(FABActionButtonStyle())
                .accessibilityLabel(item.title)
            }
        }
        .padding(8)
        .frame(width: 244)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }

    private func closeFABAndRun(_ action: @escaping () -> Void) {
        MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.3, dampingFraction: 0.82)) {
            isFABExpanded = false
        }
        action()
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
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            configuration.label
                .background(MemoraColor.interactivePrimary)
                .clipShape(Circle())
                .foregroundStyle(MemoraColor.interactivePrimaryLabel)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
        }
    }
}

private struct FABActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
}

private struct FABActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                ? MemoraColor.interactiveSecondaryBorder.opacity(0.24)
                : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
