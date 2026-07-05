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
    @State private var askAIInitialMessage: String?
    @State private var calendarEventLink: CalendarEventLink?
    @State private var suggestedEvent: FileDetailHelpers.EventKitEventWrapper?
    @State private var isLinkingEvent = false
    @State private var cachedProjectTitle: String?

    // MARK: - Generation Sheet State
    @State private var selectedTemplate: GenerationTemplate = .summary
    @State private var selectedModel: AIModelType = .chatGPT5

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
        .toolbar(.hidden, for: .navigationBar)
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
            AskAIView(scope: .file(fileId: audioFile.id), initialMessage: askAIInitialMessage)
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
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Top Bar
                topBar(vm: vm)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Custom Tab Bar
                        tabBar(vm: vm)
                            .padding(.bottom, MemoraSpacing.lg)

                        // Title & Metadata
                        titleMetadataSection(vm: vm)
                            .padding(.bottom, MemoraSpacing.lg)

                        // Image Upload Area
                        imageUploadSection
                            .padding(.bottom, MemoraSpacing.xl)

                        // Calendar Event (if any)
                        calendarEventSection
                            .padding(.bottom, MemoraSpacing.lg)

                        // Content based on generation state
                        contentSection(vm: vm)
                    }
                    .padding(.horizontal, 33)
                    .padding(.top, MemoraSpacing.md)
                    .padding(.bottom, 180)
                }
                .onChange(of: vm.generationState) { _, newState in
                    let available = FileDetailTab.availableTabs(for: newState)
                    if !available.contains(selectedTab) {
                        selectedTab = available.first ?? .transcript
                    }
                }
            }

            // MARK: Generation Sheet (PR-A3: overlay → .sheet に統一)

            // Ask Anything Overlay (floating)
            askAnythingOverlay

            .sheet(isPresented: $vm.showGenerationFlow) {
                ZStack {
                    if showTemplateSheet {
                        TemplateSelectSheet(
                            isPresented: $showTemplateSheet,
                            showModelSheet: $showModelSheet,
                            selectedTemplate: $selectedTemplate,
                            selectedModel: $selectedModel,
                            onStartGeneration: { config in
                                vm.startSummarization(with: config)
                                showModelSheet = false
                                showTemplateSheet = false
                            }
                        )
                    } else if showModelSheet {
                        AIModelSelectSheet(
                            isPresented: $showModelSheet,
                            selectedModel: $selectedModel,
                            onStartGeneration: { config in
                                vm.startSummarization(with: config)
                                showModelSheet = false
                            }
                        )
                    } else {
                        GenerationModeSheet(
                            isPresented: $vm.showGenerationFlow,
                            showTemplateSheet: $showTemplateSheet,
                            onStartGeneration: { config in
                                vm.startSummarization(with: config)
                            }
                        )
                    }
                }
            }

            // Loading Skeleton Overlay
            if vm.isSummarizing {
                generationLoadingSkeleton
                    .zIndex(5)
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

    // MARK: - Custom Top Bar

    private func topBar(vm: FileDetailViewModel) -> some View {
        HStack(spacing: 0) {
            // Left: Back button (Liquid Glass circle)
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle()
                            .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
                    )
                    .shadow(color: MemoraColor.shadowMedium, radius: 8, x: 0, y: 2)
            }
            .accessibilityLabel("戻る")

            Spacer()

            // Center: Play button (Liquid Glass pill)
            Button {
                vm.togglePlayback()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(width: 80, height: 44)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule()
                            .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
                    )
                    .shadow(color: MemoraColor.shadowMedium, radius: 8, x: 0, y: 2)
            }
            .accessibilityLabel(vm.isPlaying ? "一時停止" : "再生")

            Spacer()

            // Right: Share + More buttons (both Liquid Glass circles)
            HStack(spacing: MemoraSpacing.sm) {
                Button {
                    vm.showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle()
                                .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
                        )
                        .shadow(color: MemoraColor.shadowMedium, radius: 8, x: 0, y: 2)
                }
                .accessibilityLabel("共有")

                Button {
                    vm.showDeleteAlert = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle()
                                .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
                        )
                        .shadow(color: MemoraColor.shadowMedium, radius: 8, x: 0, y: 2)
                }
                .accessibilityLabel("その他")
            }
        }
        .padding(.horizontal, 33)
        .padding(.top, 8)
        .padding(.bottom, MemoraSpacing.sm)
    }

    // MARK: - Tab Bar

    private func tabBar(vm: FileDetailViewModel) -> some View {
        let availableTabs = FileDetailTab.availableTabs(for: vm.generationState)

        return HStack(spacing: MemoraSpacing.xs) {
            ForEach(availableTabs, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(isSelected ? .accentColor : .secondary)
            }
        }
    }

    // MARK: - Title & Metadata

    private func titleMetadataSection(vm: FileDetailViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
            // Title
            if vm.isEditingTitle {
                TextField("タイトル", text: $vm.titleDraft)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .submitLabel(.done)
                    .onSubmit { vm.saveTitle() }
            } else {
                Button {
                    vm.beginEditTitle()
                } label: {
                    Text(audioFile.title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(MemoraColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("タップしてタイトルを編集")
            }

            // Date / Duration metadata
            HStack(spacing: MemoraSpacing.sm) {
                Text(vm.formatDate(audioFile.createdAt))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "58585A"))

                if audioFile.duration > 0 {
                    Circle()
                        .fill(Color(hex: "58585A"))
                        .frame(width: 3, height: 3)

                    Text(vm.formatDuration(audioFile.duration))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "58585A"))
                }

                if let projectTitle = cachedProjectTitle {
                    Circle()
                        .fill(Color(hex: "58585A"))
                        .frame(width: 3, height: 3)

                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "58585A"))
                        Text(projectTitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: "58585A"))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Image Upload Section

    private var imageUploadSection: some View {
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(MemoraColor.divider, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.3))
                    )

                VStack(spacing: MemoraSpacing.xs) {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(MemoraColor.textSecondary)
                    Text("Upload image")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)
                }
            }
            .frame(height: 150)
        }
    }

    // MARK: - Calendar Event Section

    @ViewBuilder
    private var calendarEventSection: some View {
        if let link = calendarEventLink {
            HStack(spacing: MemoraSpacing.sm) {
                Rectangle()
                    .fill(MemoraColor.accentBlue)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(MemoraColor.accentBlue)
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MemoraColor.textPrimary)
                    Text("\(FileDetailHelpers.formatEventDate(link.startAt)) - \(FileDetailHelpers.formatEventTime(link.endAt))")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {
                    unlinkCalendarEvent()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(MemoraColor.textTertiary)
                        .font(.system(size: 13))
                }
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 0.5)
            )
        } else if let suggested = suggestedEvent {
            HStack(spacing: MemoraSpacing.sm) {
                Rectangle()
                    .fill(MemoraColor.accentBlue.opacity(0.4))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(MemoraColor.accentBlue)
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggested.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MemoraColor.textPrimary)
                    Text(FileDetailHelpers.formatEventDate(suggested.startDate))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {
                    linkSuggestedEvent(suggested)
                } label: {
                    if isLinkingEvent {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("紐付")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MemoraColor.interactivePrimaryLabel)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MemoraColor.interactivePrimary)
                            .clipShape(Capsule())
                    }
                }
                .disabled(isLinkingEvent)
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Content Section (by generation state)

    @ViewBuilder
    private func contentSection(@Bindable vm: FileDetailViewModel) -> some View {
        switch vm.generationState {
        case .notGenerated, .choosingMode, .choosingTemplate, .choosingModel:
            preGenerationContent(vm: vm)

        case .loading:
            loadingContent(vm: vm)

        case .generated:
            // Existing tab content (SummaryTab / TranscriptTab / MemoTab)
            generatedTabContent(vm: vm)
        }
    }

    // MARK: - Pre-Generation Content

    @ViewBuilder
    private func preGenerationContent(vm: FileDetailViewModel) -> some View {
        VStack(spacing: MemoraSpacing.xxl) {
            // Dotted concentric circles with icons
            dottedCirclesView
                .padding(.top, MemoraSpacing.lg)

            // Title
            Text("文字起こし・要約を生成する")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MemoraColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Subtitle
            Text("音声の内容を把握し重要ポイント・決定事項・タスクを自動抽出します。")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "58585A"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, MemoraSpacing.lg)

            // Generate button
            Button {
                vm.showGenerationFlow = true
            } label: {
                Text("生成")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(MemoraColor.interactivePrimary)
                    )
                    .shadow(color: MemoraColor.shadowMedium, radius: 12, x: 0, y: 4)
            }
            .padding(.horizontal, 29)
            .padding(.top, MemoraSpacing.sm)
        }
    }

    // MARK: - Dotted Circles

    private var dottedCirclesView: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color(hex: "D9D9D9"))
                .frame(width: 200, height: 200)

            // Middle ring
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color(hex: "D9D9D9"))
                .frame(width: 144, height: 144)

            // Inner ring
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color(hex: "D9D9D9"))
                .frame(width: 88, height: 88)

            // Icon circles
            HStack(spacing: MemoraSpacing.lg) {
                // Left: waveform icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                }

                // Center: arrow
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                }

                // Right: document icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    // MARK: - Loading Content (Skeleton)

    @ViewBuilder
    private func loadingContent(vm: FileDetailViewModel) -> some View {
        VStack(spacing: MemoraSpacing.lg) {
            // Large skeleton card
            RoundedRectangle(cornerRadius: MemoraRadius.lg)
                .fill(Color(hex: "D9D9D9"))
                .frame(height: 180)

            // Horizontal skeleton bars
            VStack(spacing: MemoraSpacing.sm) {
                skeletonBar(widthRatio: 0.9)
                skeletonBar(widthRatio: 0.75)
                skeletonBar(widthRatio: 0.85)
                skeletonBar(widthRatio: 0.6)
            }

            // Generate button (visible during loading)
            Button {
                vm.showGenerationFlow = true
            } label: {
                Text("生成")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(MemoraColor.interactivePrimary)
                    )
                    .shadow(color: MemoraColor.shadowMedium, radius: 12, x: 0, y: 4)
            }
            .padding(.horizontal, 29)
            .padding(.top, MemoraSpacing.sm)
        }
    }

    private func skeletonBar(widthRatio: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(hex: "D9D9D9"))
            .frame(height: 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: UIScreen.main.bounds.width * widthRatio - 66)
    }

    // MARK: - Generated Tab Content

    @ViewBuilder
    private func generatedTabContent(@Bindable vm: FileDetailViewModel) -> some View {
        // Keep the existing tab switching pointing at SummaryTab / TranscriptTab / MemoTab
        // with their full implementations unchanged.
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

    // MARK: - Ask Anything Overlay

    private var askAnythingOverlay: some View {
        VStack {
            Spacer()
            AskAnythingFloatingBar(
                modelLabel: currentProvider.rawValue,
                showAskAI: $showAskAI,
                onSend: { message in
                    askAIInitialMessage = message
                    showAskAI = true
                }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 34)
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

    // MARK: - Loading Skeleton

    /// 生成中ローディングスケルトン — タイトル + 大きなカード + 横長バー
    private var generationLoadingSkeleton: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                // Title skeleton bars
                skeletonBar(width: 200, height: 21)
                skeletonBar(width: 140, height: 14)

                // Large content skeleton card
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "D9D9D9"))
                    .frame(height: 180)

                // Horizontal skeleton bars
                skeletonBar(width: nil, height: 14)
                skeletonBar(width: nil, height: 14)
                skeletonBar(width: 260, height: 14)
            }
            .padding(MemoraSpacing.lg)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.bottom, 180)
        }
    }

    private func skeletonBar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color(hex: "D9D9D9"))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

// MARK: - Ask Anything Floating Bar

struct AskAnythingFloatingBar: View {
    let modelLabel: String
    let showAskAI: Binding<Bool>
    var onSend: ((String) -> Void)? = nil
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: MemoraSpacing.sm) {
                // Clip icon
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MemoraColor.textTertiary)

                // Text input
                TextField("Ask Anything", text: $inputText, axis: .vertical)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .onSubmit { send() }

                Spacer()

                // Model selector
                HStack(spacing: 4) {
                    Text(modelLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MemoraColor.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                // Send button
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? MemoraColor.textTertiary
                                : MemoraColor.interactivePrimary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: MemoraColor.shadowMedium, radius: 16, x: 0, y: 4)
        }
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        isFocused = false
        onSend?(trimmed)
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
