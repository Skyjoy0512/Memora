import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Content View

struct ContentView: View {
    @State private var bluetoothService = BluetoothAudioService()
    @State private var captureRegistry = CaptureSourceRegistry(sink: { _, _ in
        throw CaptureError.importSinkNotConfigured
    })
    @State private var v6Island = V6IslandController()
    @State private var v6RecordingSession = V6RecordingSessionController()
    @State private var v6GenerationSession = V6GenerationSessionController()
    @AppStorage(V6AuthStorageKey.stage) private var v6AuthStageRaw = V6AuthStage.onboarding.rawValue
    @AppStorage(V6AuthStorageKey.isPro) private var v6IsPro = false
    @AppStorage(V6AuthStorageKey.loginEmail) private var v6LoginEmail = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBluetoothConfigured = false
    @Query private var googleSettingsList: [GoogleMeetSettings]
    @Query(sort: \AudioFile.createdAt, order: .reverse) private var audioFiles: [AudioFile]
    @State private var selectedTab: Int = 0
    @State private var pendingOpenedAudioFileID: UUID?
    @State private var openedAudioFile: AudioFile?
    @State private var isTabBarHidden = false
    @State private var triggerRecording = false
    @State private var triggerFileImport = false
    @State private var v6ToastMessage: String?
    @State private var showGenerationProgress = false
    @State private var generatingAudioFile: AudioFile?
    @State private var showFileImporter = false
    @State private var showV6Paywall = false
    @State private var showMeetingCapture = false
    @State private var meetingCaptureViewModel = MeetingCaptureViewModel()
    @State private var importErrorMessage: String?

    private var importContentTypes: [UTType] {
        [.mpeg4Audio, .wav, .mp3, .aiff, .json, .plainText].compactMap { $0 }
    }

    private var isV6AuthPending: Bool {
        (V6AuthStage(rawValue: v6AuthStageRaw) ?? .onboarding) != .done
    }

    private var showRecordingCover: Binding<Bool> {
        Binding(
            get: { v6RecordingSession.wantsPresentation },
            set: { v6RecordingSession.wantsPresentation = $0 }
        )
    }

    var body: some View {
        ZStack {
            NavigationStack {
                V6AppShellView(
                    selectedTab: $selectedTab,
                    showPaywall: $showV6Paywall,
                    onStartRecording: {
                        v6RecordingSession.requestPresentation()
                    },
                    onImport: {
                        showFileImporter = true
                    },
                    onMeetingCapture: {
                        showMeetingCapture = true
                    },
                    onOpenFileDetail: { file in
                        openedAudioFile = file
                    }
                )
                .navigationBarBackButtonHidden()
                .navigationDestination(item: $openedAudioFile) { file in
                    FileDetailView(audioFile: file)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .disabled(isV6AuthPending)
            .accessibilityHidden(isV6AuthPending)
            .fullScreenCover(isPresented: showRecordingCover) {
                V6RecordingView { savedAudioFile in
                    v6RecordingSession.wantsPresentation = false
                    beginGeneration(for: savedAudioFile)
                }
                .environment(v6RecordingSession)
            }
            .fullScreenCover(isPresented: $showGenerationProgress) {
                V6GenerationProgressView(
                    onSkip: {
                        showGenerationProgress = false
                        v6GenerationSession.detach()
                        if let file = generatingAudioFile {
                            selectedTab = 0
                            openedAudioFile = file
                        }
                    },
                    onBackground: {
                        showGenerationProgress = false
                    },
                    onCompleted: { file in
                        showGenerationProgress = false
                        selectedTab = 0
                        openedAudioFile = file
                    }
                )
                .environment(v6GenerationSession)
            }
            .sheet(isPresented: $showMeetingCapture) {
                MeetingCaptureSetupView(viewModel: meetingCaptureViewModel)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: importContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImportResult(result)
            }
            .alert("インポートエラー", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { importErrorMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) { importErrorMessage = nil }
            } message: {
                if let importErrorMessage { Text(importErrorMessage) }
            }

            if isV6AuthPending {
                V6AuthFlowView(
                    authStageRaw: $v6AuthStageRaw,
                    isPro: $v6IsPro,
                    loginEmail: $v6LoginEmail,
                    toastMessage: $v6ToastMessage
                )
                .zIndex(10)
            } else {
                VStack {
                    V6DynamicIslandPill()
                        .padding(.top, 11)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .zIndex(20)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTabBarHidden)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selectedTab)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isV6AuthPending)
        .environment(bluetoothService)
        .environment(captureRegistry)
        .environment(v6Island)
        .environment(v6RecordingSession)
        .environment(v6GenerationSession)
        .task {
            DebugLogger.shared.markLaunchStep("ContentView.task")
            configureV6Island()
            configureV6RecordingSession()
            configureV6GenerationSession()
            configureMeetingCaptureIfNeeded()
            try? await Task.sleep(for: .seconds(1.5))
            configureCaptureRegistryIfNeeded()
            DebugLogger.shared.markLaunchStep("CaptureSourceRegistry 設定完了（遅延）")
            isBluetoothConfigured = true
        }
        .onChange(of: v6ToastMessage) { _, message in
            guard let message else { return }
            v6Island.showSnackbar(message)
            v6ToastMessage = nil
        }
        .onChange(of: pendingOpenedAudioFileID) { _, fileID in
            guard let fileID else { return }
            if let file = audioFiles.first(where: { $0.id == fileID }) {
                openedAudioFile = file
            }
            pendingOpenedAudioFileID = nil
        }
    }

    // MARK: - V6 Dynamic Island

    private func configureV6Island() {
        v6Island.onOpenRecording = { v6RecordingSession.requestPresentation() }
        v6Island.onOpenGeneration = { showGenerationProgress = true }
        v6Island.onOpenAskTab = { selectedTab = 2 }
        v6Island.onOpenAskSource = { _ in selectedTab = 2 }
    }

    // MARK: - V6 Recording / Generation

    private func configureV6RecordingSession() {
        v6RecordingSession.configure(audioFileRepository: AudioFileRepository(modelContext: modelContext))
    }

    private func configureV6GenerationSession() {
        v6GenerationSession.onCompleted = { file in
            v6Island.exitLiveGeneration()
            // Progress screen still visible: it handles its own foreground completion via
            // `onCompleted`, so avoid a redundant island snackbar (matches `.dc.html`'s
            // modal==='generating' branch, which transitions silently instead of toasting).
            guard !showGenerationProgress else { return }
            v6Island.showSnackbar(
                "要約が完成しました",
                tone: .success,
                actionLabel: "開く",
                action: {
                    selectedTab = 0
                    openedAudioFile = file
                }
            )
        }
    }

    private func beginGeneration(for file: AudioFile) {
        generatingAudioFile = file
        v6GenerationSession.start(audioFile: file, modelContext: modelContext)
        showGenerationProgress = true
    }

    private func configureMeetingCaptureIfNeeded() {
        meetingCaptureViewModel.configure(captureService: SystemAudioCaptureService())
        meetingCaptureViewModel.configure(modelContext: modelContext)
        meetingCaptureViewModel.configureBotService(BotMeetingService(), modelContext: modelContext)
    }

    // MARK: - Capture Sources

    private func configureCaptureRegistryIfNeeded() {
        captureRegistry.configure { sourceURL, suggestedTitle in
            let audioFile = try AudioFileImportService.importAudio(
                from: sourceURL,
                suggestedTitle: suggestedTitle,
                modelContext: modelContext,
                requiresSecurityScopedAccess: false
            )
            selectedTab = 0
            pendingOpenedAudioFileID = audioFile.id
            return audioFile
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            for url in urls {
                importAudioFile(from: url)
            }
        case .failure(let error):
            print("[ContentView] File import failed: \(error.localizedDescription)")
            importErrorMessage = "ファイルの選択に失敗しました。もう一度お試しください。"
        }
    }

    private func importAudioFile(from url: URL) {
        do {
            let audioFile = try AudioFileImportService.importAudio(
                from: url,
                modelContext: modelContext,
                requiresSecurityScopedAccess: true
            )
            selectedTab = 0
            pendingOpenedAudioFileID = audioFile.id
        } catch {
            print("[ContentView] Audio import failed: \(error.localizedDescription)")
            importErrorMessage = "ファイルのインポートに失敗しました。もう一度お試しください。"
        }
    }
}
