import SwiftUI
import SwiftData
import PhotosUI

// MARK: - File Detail View

struct FileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let audioFile: AudioFile
    var autoStartTranscription = false
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @State private var viewModel: FileDetailViewModel?
    @State private var selectedTab: FileDetailTab = .summary
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var previewPhotoID: UUID?
    @State private var showAskAI = false
    @State private var calendarEventLink: CalendarEventLink?
    @State private var suggestedEvent: FileDetailHelpers.EventKitEventWrapper?
    @State private var isLinkingEvent = false
    @State private var cachedProjectTitle: String?

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    var currentAPIKey: String {
        switch currentProvider {
        case .openai: return KeychainService.load(key: .apiKeyOpenAI)
        case .gemini: return KeychainService.load(key: .apiKeyGemini)
        case .deepseek: return KeychainService.load(key: .apiKeyDeepSeek)
        case .local: return ""
        }
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // タブごとの context-aware actions
                switch selectedTab {
                case .summary:
                    if viewModel?.summaryResult != nil {
                        Button("再生成", systemImage: "arrow.clockwise") {
                            viewModel?.showGenerationFlow = true
                        }
                    }
                    Button("共有", systemImage: "square.and.arrow.up") {
                        viewModel?.showShareSheet = true
                    }
                    .disabled(viewModel?.summaryResult == nil)

                case .transcript:
                    if viewModel?.transcriptResult != nil {
                        Button("再文字起こし", systemImage: "arrow.clockwise") {
                            viewModel?.startTranscription()
                        }
                        .disabled(viewModel?.isTranscribing == true)
                    }
                    Button("共有", systemImage: "square.and.arrow.up") {
                        viewModel?.showShareSheet = true
                    }
                    .disabled(viewModel?.transcriptResult == nil)

                case .memo:
                    Button("保存", systemImage: "checkmark") {
                        viewModel?.saveMemo()
                    }
                    .disabled(viewModel?.memoHasUnsavedChanges != true)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("削除", systemImage: "trash", role: .destructive) {
                    viewModel?.showDeleteAlert = true
                }
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let vm = FileDetailViewModel(
                audioFile: audioFile,
                modelContext: modelContext,
                provider: currentProvider,
                transcriptionMode: currentTranscriptionMode,
                apiKey: currentAPIKey
            )
            vm.setupAudioPlayer()
            vm.loadSavedData()
            selectedTab = preferredInitialTab(for: vm)
            viewModel = vm
            cachedProjectTitle = resolveProjectTitle()
            loadCalendarEventLink()

            if autoStartTranscription && !audioFile.isTranscribed {
                vm.startTranscription()
            }
        }
        .onDisappear {
            viewModel?.cleanup()
        }
        .sheet(isPresented: $showAskAI) {
            AskAIView(scope: .file(fileId: audioFile.id))
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard let vm = viewModel, !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await vm.importPhoto(from: data)
                    }
                }
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: FileDetailViewModel) -> some View {
        @Bindable var vm = vm
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: MemoraSpacing.lg) {
                    FileDetailHeader(
                        vm: vm,
                        audioFile: audioFile,
                        cachedProjectTitle: cachedProjectTitle,
                        calendarEventLink: calendarEventLink,
                        suggestedEvent: suggestedEvent,
                        isLinkingEvent: isLinkingEvent,
                        onUnlinkCalendar: unlinkCalendarEvent,
                        onLinkSuggested: linkSuggestedEvent
                    )

                    PlayerControls(vm: vm)

                    tabPicker

                    tabContent(vm: vm)
                }
                .padding(.horizontal, MemoraSpacing.md)
                .padding(.top, MemoraSpacing.xxl)
                .padding(.bottom, 80)
            }

            AskAICompactBar(
                provider: currentProvider,
                showAskAI: $showAskAI
            )
        }
        .sheet(isPresented: $vm.showGenerationFlow) {
            GenerationFlowSheet(isPresented: $vm.showGenerationFlow) { config in
                vm.startSummarization(with: config)
            }
        }
        .sheet(isPresented: $vm.showShareSheet) {
            ShareSheet(
                shareText: vm.transcriptResult?.text,
                shareURL: vm.audioURL,
                audioFile: audioFile
            )
        }
        .alert("ファイルを削除", isPresented: $vm.showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                vm.deleteAudioFile()
                dismiss()
            }
        } message: {
            Text("この録音ファイルを削除しますか？")
        }
        .alert("エラー", isPresented: $vm.showErrorAlert) {
            Button("OK", role: .cancel) {
                vm.errorMessage = nil
                vm.recoveryAction = nil
            }
        } message: {
            if let message = vm.errorMessage {
                if let recovery = vm.recoveryAction {
                    Text("\(message)\n\n\(recovery)")
                } else {
                    Text(message)
                }
            }
        }
        .alert("完了", isPresented: $vm.showSuccessAlert) {
            Button("OK", role: .cancel) {
                vm.successMessage = nil
            }
        } message: {
            if let message = vm.successMessage {
                Text(message)
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        NothingTabPicker(
            selection: $selectedTab,
            options: FileDetailTab.allCases.map { tab in
                NothingTabPicker<NothingTabOption<FileDetailTab>>.NothingTabOption(
                    value: tab,
                    label: tab.title,
                    icon: tab.icon
                )
            }
        )
    }

    // Type alias for cleaner syntax
    private typealias NothingTabOption<T> = NothingTabPicker<T>.NothingTabOption

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(@Bindable vm: FileDetailViewModel) -> some View {
        switch selectedTab {
        case .summary:
            SummaryTab(
                vm: vm,
                audioFile: audioFile,
                showGenerationFlow: $vm.showGenerationFlow,
                showShareSheet: $vm.showShareSheet
            )
        case .transcript:
            TranscriptTab(
                vm: vm,
                audioFile: audioFile,
                showShareSheet: $vm.showShareSheet
            )
        case .memo:
            MemoTab(
                vm: vm,
                selectedPhotoItems: $selectedPhotoItems,
                previewPhotoID: $previewPhotoID
            )
        }
    }

    // MARK: - Helpers

    private func resolveProjectTitle() -> String? {
        guard let projectID = audioFile.projectID else { return nil }
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { $0.id == projectID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first)?.title
    }

    private func loadCalendarEventLink() {
        let service = CalendarService()
        calendarEventLink = service.fetchLink(for: audioFile, modelContext: modelContext)

        // 紐付がなければ提案を探す
        if calendarEventLink == nil && service.isAuthorized {
            if let event = service.findMatchingEvent(for: audioFile) {
                suggestedEvent = FileDetailHelpers.EventKitEventWrapper(
                    id: event.calendarItemIdentifier,
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate
                )
            }
        }
    }

    private func linkSuggestedEvent(_ wrapper: FileDetailHelpers.EventKitEventWrapper) {
        isLinkingEvent = true
        let service = CalendarService()
        // Find the actual EKEvent again
        if let event = service.findMatchingEvent(for: audioFile) {
            do {
                let link = try service.linkEventToAudioFile(
                    event: event,
                    audioFile: audioFile,
                    modelContext: modelContext
                )
                calendarEventLink = link
                suggestedEvent = nil
            } catch {
                // Silently fail - not critical
            }
        }
        isLinkingEvent = false
    }

    private func unlinkCalendarEvent() {
        let service = CalendarService()
        do {
            try service.unlinkEvent(audioFile: audioFile, modelContext: modelContext)
            calendarEventLink = nil
            // Re-suggest
            if service.isAuthorized {
                if let event = service.findMatchingEvent(for: audioFile) {
                    suggestedEvent = FileDetailHelpers.EventKitEventWrapper(
                        id: event.calendarItemIdentifier,
                        title: event.title ?? "",
                        startDate: event.startDate,
                        endDate: event.endDate
                    )
                }
            }
        } catch {
            // Silently fail
        }
    }

    private func preferredInitialTab(for vm: FileDetailViewModel) -> FileDetailTab {
        if vm.summaryResult != nil || audioFile.isSummarized {
            return .summary
        }

        if vm.transcriptResult != nil || audioFile.isTranscribed || !(audioFile.referenceTranscript?.isEmpty ?? true) {
            return .transcript
        }

        return .memo
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: AudioFile.self,
        Transcript.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        configurations: config
    )

    let audioFile = AudioFile(title: "テスト録音", audioURL: "")
    audioFile.duration = 120

    container.mainContext.insert(audioFile)

    return NavigationStack {
        FileDetailView(audioFile: audioFile)
    }
    .modelContainer(container)
}
