import SwiftUI
import SwiftData
import PhotosUI
import UIKit

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
    @State private var suggestedEvent: EventKitEventWrapper?
    @State private var isLinkingEvent = false

    /// EKEvent の軽量ラッパー（@State で保持するため）
    struct EventKitEventWrapper {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
    }

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
                        Button(action: { viewModel?.showGenerationFlow = true }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    Button(action: { viewModel?.showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel?.summaryResult == nil)

                case .transcript:
                    if viewModel?.transcriptResult != nil {
                        Button(action: { viewModel?.startTranscription() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel?.isTranscribing == true)
                    }
                    Button(action: { viewModel?.showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel?.transcriptResult == nil)

                case .memo:
                    Button(action: { viewModel?.saveMemo() }) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(viewModel?.memoHasUnsavedChanges != true)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    viewModel?.showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: MemoraSpacing.lg) {
                    headerSection(vm: vm)
                    playerControls(vm: vm)
                    tabPicker
                    tabContent(vm: vm)
                }
                .padding(.horizontal, MemoraSpacing.md)
                .padding(.top, MemoraSpacing.xxl)
                .padding(.bottom, 80)
            }

            askAICompactBar
        }
        .sheet(isPresented: Binding(
            get: { vm.showGenerationFlow },
            set: { vm.showGenerationFlow = $0 }
        )) {
            GenerationFlowSheet(isPresented: Binding(
                get: { vm.showGenerationFlow },
                set: { vm.showGenerationFlow = $0 }
            )) { config in
                vm.startSummarization(with: config)
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showShareSheet },
            set: { vm.showShareSheet = $0 }
        )) {
            ShareSheet(
                shareText: vm.transcriptResult?.text,
                shareURL: vm.audioURL,
                audioFile: audioFile
            )
        }
        .alert("ファイルを削除", isPresented: Binding(
            get: { vm.showDeleteAlert },
            set: { vm.showDeleteAlert = $0 }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                vm.deleteAudioFile()
                dismiss()
            }
        } message: {
            Text("この録音ファイルを削除しますか？")
        }
        .alert("エラー", isPresented: Binding(
            get: { vm.showErrorAlert },
            set: { vm.showErrorAlert = $0 }
        )) {
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
        .alert("完了", isPresented: Binding(
            get: { vm.showSuccessAlert },
            set: { vm.showSuccessAlert = $0 }
        )) {
            Button("OK", role: .cancel) {
                vm.successMessage = nil
            }
        } message: {
            if let message = vm.successMessage {
                Text(message)
            }
        }
    }

    @FocusState private var isTitleFieldFocused: Bool

    private func headerSection(vm: FileDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            if vm.isEditingTitle {
                TextField("タイトル", text: Binding(
                    get: { vm.titleDraft },
                    set: { vm.titleDraft = $0 }
                ))
                    .font(MemoraTypography.title2)
                    .fontWeight(.bold)
                    .focused($isTitleFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { vm.saveTitle() }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完了") { vm.saveTitle() }
                        }
                    }
            } else {
                HStack(spacing: MemoraSpacing.xs) {
                    Text(audioFile.title)
                        .font(MemoraTypography.title2)
                        .fontWeight(.bold)
                    Image(systemName: "pencil")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { vm.beginEditTitle() }
            }

            // メタ情報: 日時 / 長さ / ソース / プロジェクト
            HStack(spacing: MemoraSpacing.sm) {
                Text(vm.formatDate(audioFile.createdAt))
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)

                if audioFile.duration > 0 {
                    Text(vm.formatDuration(audioFile.duration))
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }

                sourceBadge

                if let projectTitle = resolvedProjectTitle {
                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                        Text(projectTitle)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            calendarEventCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// projectID からプロジェクト名を解決（キャッシュ付き）
    private var resolvedProjectTitle: String? {
        guard let projectID = audioFile.projectID else { return nil }
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { $0.id == projectID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first)?.title
    }

    @ViewBuilder
    private var sourceBadge: some View {
        let icon: String = {
            switch audioFile.sourceType {
            case .recording: return "mic.fill"
            case .import: return "square.and.arrow.down"
            case .plaud: return "waveform"
            case .google: return "video.fill"
            }
        }()
        Label({
            switch audioFile.sourceType {
            case .recording: return "録音"
            case .import: return "インポート"
            case .plaud: return "Plaud"
            case .google: return "Meet"
            }
        }(), systemImage: icon)
            .font(MemoraTypography.caption1)
            .foregroundStyle(.secondary)
    }

    // MARK: - Calendar Event Card

    @ViewBuilder
    private var calendarEventCard: some View {
        if let link = calendarEventLink {
            // 紐付済みイベント
            HStack(spacing: MemoraSpacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(MemoraColor.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.primary)
                    Text("\(formatEventDate(link.startAt)) - \(formatEventTime(link.endAt))")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {
                    unlinkCalendarEvent()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(MemoraColor.textSecondary)
                        .font(.caption)
                }
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.accentBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
        } else if let suggested = suggestedEvent {
            // 提案イベント
            HStack(spacing: MemoraSpacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(MemoraColor.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggested.title)
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.primary)
                    Text(formatEventDate(suggested.startDate))
                        .font(MemoraTypography.caption1)
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
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MemoraColor.accentBlue)
                            .clipShape(Capsule())
                    }
                }
                .disabled(isLinkingEvent)
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.accentBlue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
        }
    }

    // MARK: - Calendar Event Helpers

    private func loadCalendarEventLink() {
        let service = CalendarService()
        calendarEventLink = service.fetchLink(for: audioFile, modelContext: modelContext)

        // 紐付がなければ提案を探す
        if calendarEventLink == nil && service.isAuthorized {
            if let event = service.findMatchingEvent(for: audioFile) {
                suggestedEvent = EventKitEventWrapper(
                    id: event.calendarItemIdentifier,
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate
                )
            }
        }
    }

    private func linkSuggestedEvent(_ wrapper: EventKitEventWrapper) {
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
                    suggestedEvent = EventKitEventWrapper(
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

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Player Controls

    @ViewBuilder
    private func playerControls(vm: FileDetailViewModel) -> some View {
        HStack(spacing: MemoraSpacing.md) {
            // 再生ボタン
            Button(action: { vm.togglePlayback() }) {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
            }

            // プログレスバー
            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { vm.playbackPosition },
                        set: { newPosition in
                            vm.playbackPosition = newPosition
                        }
                    ),
                    in: 0...max(vm.audioDuration, 1),
                    onEditingChanged: { editing in
                        if !editing && vm.audioDuration > 0 {
                            vm.seek(to: vm.playbackPosition)
                        }
                    }
                )

                HStack {
                    Text(vm.formatTime(vm.playbackPosition))
                    Spacer()
                    Text(vm.formatTime(vm.audioDuration))
                }
                .font(MemoraTypography.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, MemoraSpacing.sm)
        .padding(.vertical, MemoraSpacing.xs)
    }

    private var tabPicker: some View {
        Picker("表示タブ", selection: $selectedTab) {
            ForEach(FileDetailTab.allCases) { tab in
                Label(tab.title, systemImage: tab.icon).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func tabContent(vm: FileDetailViewModel) -> some View {
        switch selectedTab {
        case .summary:
            summaryTab(vm: vm)
        case .transcript:
            transcriptTab(vm: vm)
        case .memo:
            memoTab(vm: vm)
        }
    }

    private func summaryTab(vm: FileDetailViewModel) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: MemoraSpacing.lg) {
                if vm.isSummarizing {
                    progressCard(
                        title: "要約を生成中",
                        progress: vm.summarizationProgress,
                        message: "要点とアクションアイテムを整理しています。"
                    )
                } else if let result = vm.summaryResult {
                    SummaryContentView(result: result)

                    // Summary タブの context-aware actions
                    HStack(spacing: MemoraSpacing.sm) {
                        Button {
                            vm.showGenerationFlow = true
                        } label: {
                            Label("再生成", systemImage: "arrow.clockwise")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Menu {
                            Button {
                                vm.showShareSheet = true
                            } label: {
                                Label("共有", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Label("エクスポート", systemImage: "square.and.arrow.up")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)
                    }
                } else if audioFile.isSummarized {
                    placeholderCard(
                        icon: "text.quote",
                        title: "要約を読み込めませんでした",
                        description: "保存済みデータの取得後に、このタブへ表示されます。"
                    )
                } else if vm.transcriptResult != nil || audioFile.isTranscribed {
                    placeholderCard(
                        icon: "sparkles.rectangle.stack",
                        title: "要約をまだ作成していません",
                        description: "文字起こしから要約を生成すると、ここに本文と重要ポイントが表示されます。"
                    )
                } else {
                    placeholderCard(
                        icon: "text.quote",
                        title: "先に文字起こしが必要です",
                        description: "要約タブは文字起こし結果をもとに作成されます。まず Transcript タブで文字起こしを実行してください。"
                    )
                }
            }
            .padding(.bottom, 72)

            // 下部全幅「要約を生成」ボタン
            if !vm.isSummarizing && vm.summaryResult == nil && !audioFile.isSummarized && (vm.transcriptResult != nil || audioFile.isTranscribed) {
                Button {
                    vm.showGenerationFlow = true
                } label: {
                    Text("要約を生成")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MemoraSpacing.md)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                }
                .padding(.horizontal, MemoraSpacing.md)
                .padding(.bottom, MemoraSpacing.md)
            }
        }
    }

    private func transcriptTab(vm: FileDetailViewModel) -> some View {
        VStack(spacing: MemoraSpacing.lg) {
            if vm.isTranscribing {
                progressCard(
                    title: "文字起こしを実行中",
                    progress: vm.transcriptionProgress,
                    message: "音声を解析して、話者ごとのテキストを整えています。"
                )
            } else if let result = vm.transcriptResult {
                if vm.isEditingTranscript {
                    ScrollView {
                        TextEditor(text: Binding(
                            get: { vm.transcriptDraft },
                            set: { vm.transcriptDraft = $0 }
                        ))
                            .font(MemoraTypography.body)
                            .frame(minHeight: 400)
                            .padding(MemoraSpacing.sm)
                    }

                    HStack(spacing: MemoraSpacing.sm) {
                        Button {
                            vm.saveTranscriptEdit()
                        } label: {
                            Label("保存", systemImage: "checkmark")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            vm.cancelEditTranscript()
                        } label: {
                            Label("キャンセル", systemImage: "xmark")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                } else {
                    TranscriptContentView(
                        result: result,
                        currentPlaybackTime: vm.playbackPosition
                    ) { segment in
                        vm.seekToTime(segment.startTime)
                    }

                    // Transcript タブの context-aware actions
                    HStack(spacing: MemoraSpacing.sm) {
                        Button {
                            vm.startTranscription()
                        } label: {
                            Label("再文字起こし", systemImage: "arrow.clockwise")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isTranscribing)

                        Button {
                            vm.beginEditTranscript()
                        } label: {
                            Label("編集", systemImage: "pencil")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)

                        if result.segments.count > 1 {
                            Button {
                                vm.registerPrimarySpeakerSample()
                            } label: {
                                Label("話者登録", systemImage: "person.crop.circle.badge.plus")
                                    .font(MemoraTypography.caption1)
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()
                    }
                }

                if let reason = vm.fallbackReason, !reason.isEmpty {
                    detailCard {
                        HStack(spacing: MemoraSpacing.sm) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(MemoraColor.accentBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("バックエンド: \(vm.activeBackend ?? "不明")")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.primary)
                                Text(reason)
                                    .font(MemoraTypography.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if audioFile.isTranscribed {
                placeholderCard(
                    icon: "text.alignleft",
                    title: "文字起こしを読み込めませんでした",
                    description: "保存済みデータの取得後に、このタブへ全文を表示します。"
                )
            } else {
                placeholderCard(
                    icon: "waveform.badge.magnifyingglass",
                    title: "文字起こしはまだありません",
                    description: "録音を文字起こしすると、全文と話者セグメントをこのタブで確認できます。",
                    buttonTitle: "文字起こしを開始",
                    buttonAction: { vm.startTranscription() }
                )
            }

            if let referenceTranscript = audioFile.referenceTranscript, !referenceTranscript.isEmpty {
                detailCard {
                    VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                        Label("参照文字起こし（Plaud）", systemImage: "doc.text")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(MemoraColor.accentBlue)

                        Text(referenceTranscript)
                            .font(MemoraTypography.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(6)

                        Text("Plaud 側で生成された文字起こしです。Memora の文字起こしとは独立しています。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 話者登録（Transcript タブ内）
            speakerRegistrationCard(vm: vm)
        }
    }

    private func memoTab(vm: FileDetailViewModel) -> some View {
        VStack(spacing: MemoraSpacing.lg) {
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    // メモヘッダー
                    HStack(alignment: .top) {
                        Label("Markdown メモ", systemImage: "square.and.pencil")
                            .font(MemoraTypography.headline)

                        Spacer()

                        Button("保存") {
                            vm.saveMemo()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.memoHasUnsavedChanges)
                    }

                    TextEditor(text: Binding(
                        get: { vm.memoDraft },
                        set: { vm.updateMemoDraft($0) }
                    ))
                    .font(MemoraTypography.body)
                    .frame(minHeight: 220)
                    .padding(MemoraSpacing.sm)
                    .background(MemoraColor.divider.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                    .scrollContentBackground(.hidden)

                    HStack(spacing: MemoraSpacing.xs) {
                        Circle()
                            .fill(vm.memoHasUnsavedChanges ? MemoraColor.accentRed : MemoraColor.accentGreen)
                            .frame(width: 8, height: 8)

                        Text(memoStatusText(vm: vm))
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 写真セクション（Memo 文脈に溶け込ませる）
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    HStack {
                        Label("写真", systemImage: "photo.on.rectangle")
                            .font(MemoraTypography.headline)

                        Spacer()

                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            Label("追加", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    if vm.isImportingPhotos {
                        ProgressView("写真を取り込み中...")
                            .font(MemoraTypography.caption1)
                    }

                    if vm.photoAttachments.isEmpty {
                        Text("写真を追加するとメモと一緒に確認できます")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, MemoraSpacing.sm)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: MemoraSpacing.sm) {
                                ForEach(vm.photoAttachments, id: \.id) { attachment in
                                    Button {
                                        previewPhotoID = attachment.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                                            memoThumbnail(for: attachment)
                                                .frame(width: 132, height: 98)
                                                .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))

                                            Text(attachment.caption ?? "キャプションなし")
                                                .font(MemoraTypography.caption1)
                                                .foregroundStyle(MemoraColor.textPrimary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 132, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, MemoraSpacing.xxs)
                        }
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { previewPhotoID != nil },
                set: { if !$0 { previewPhotoID = nil } }
            )
        ) {
            if let attachment = selectedPreviewAttachment(in: vm) {
                PhotoAttachmentPreviewSheet(
                    attachment: attachment,
                    image: fullSizeImage(for: attachment),
                    canMoveLeading: vm.canMovePhotoAttachment(attachment, towardLeading: true),
                    canMoveTrailing: vm.canMovePhotoAttachment(attachment, towardLeading: false),
                    onSaveCaption: { caption in
                        vm.updatePhotoCaption(attachment, caption: caption)
                    },
                    onMoveLeading: {
                        vm.movePhotoAttachment(attachment, towardLeading: true)
                    },
                    onMoveTrailing: {
                        vm.movePhotoAttachment(attachment, towardLeading: false)
                    },
                    onDelete: {
                        vm.deletePhotoAttachment(attachment)
                        previewPhotoID = nil
                    }
                )
            }
        }
    }

    private func speakerRegistrationCard(vm: FileDetailViewModel) -> some View {
        Group {
            if vm.audioURL != nil {
                detailCard {
                    Button(action: { vm.registerPrimarySpeakerSample() }) {
                        VStack(spacing: 6) {
                            Label("この録音を自分の声サンプルに登録", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity)
                            Text("1人だけが話している録音を使うと精度が安定します")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private func progressCard(title: String, progress: Double, message: String) -> some View {
        detailCard {
            VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                Text(title)
                    .font(MemoraTypography.headline)

                ProgressView(value: progress)
                    .tint(MemoraColor.textSecondary)

                Text("\(Int(progress * 100))%  \(message)")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func placeholderCard(
        icon: String,
        title: String,
        description: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) -> some View {
        detailCard {
            EmptyStateView(
                icon: icon,
                title: title,
                description: description,
                buttonTitle: buttonTitle,
                buttonAction: buttonAction
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - AskAI Compact Bar

    private var askAICompactBar: some View {
        Button {
            showAskAI = true
        } label: {
            HStack(spacing: MemoraSpacing.sm) {
                Text(currentProvider.rawValue)
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentBlue)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 2)
                    .background(MemoraColor.accentBlue.opacity(0.12))
                    .clipShape(Capsule())

                Text("Ask AI...")
                    .font(MemoraTypography.body)
                    .foregroundStyle(.tertiary)

                Spacer()

                Image(systemName: "sparkle")
                    .foregroundStyle(MemoraColor.accentBlue)
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .liquidGlass(cornerRadius: 24, shadowRadius: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(MemoraSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MemoraColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))
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

private extension FileDetailView {
    func memoStatusText(vm: FileDetailViewModel) -> String {
        if vm.memoHasUnsavedChanges {
            return "未保存の変更があります"
        }

        if let updatedAt = vm.memoUpdatedAt {
            return "最終保存: \(vm.formatDate(updatedAt))"
        }

        return "まだメモは保存されていません"
    }

    func selectedPreviewAttachment(in vm: FileDetailViewModel) -> PhotoAttachment? {
        guard let previewPhotoID else { return nil }
        return vm.photoAttachments.first { $0.id == previewPhotoID }
    }

    @ViewBuilder
    func memoThumbnail(for attachment: PhotoAttachment) -> some View {
        if let image = thumbnailImage(for: attachment) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: MemoraRadius.md)
                    .fill(MemoraColor.divider.opacity(0.16))
                Image(systemName: "photo")
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
    }

    func thumbnailImage(for attachment: PhotoAttachment) -> UIImage? {
        if let thumbnailPath = attachment.thumbnailPath,
           let image = UIImage(contentsOfFile: thumbnailPath) {
            return image
        }

        return UIImage(contentsOfFile: attachment.localPath)
    }

    func fullSizeImage(for attachment: PhotoAttachment) -> UIImage? {
        UIImage(contentsOfFile: attachment.localPath)
    }
}

struct PhotoAttachmentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let attachment: PhotoAttachment
    let image: UIImage?
    let canMoveLeading: Bool
    let canMoveTrailing: Bool
    let onSaveCaption: (String) -> Void
    let onMoveLeading: () -> Void
    let onMoveTrailing: () -> Void
    let onDelete: () -> Void

    @State private var captionText: String

    init(
        attachment: PhotoAttachment,
        image: UIImage?,
        canMoveLeading: Bool = false,
        canMoveTrailing: Bool = false,
        onSaveCaption: @escaping (String) -> Void,
        onMoveLeading: @escaping () -> Void = {},
        onMoveTrailing: @escaping () -> Void = {},
        onDelete: @escaping () -> Void
    ) {
        self.attachment = attachment
        self.image = image
        self.canMoveLeading = canMoveLeading
        self.canMoveTrailing = canMoveTrailing
        self.onSaveCaption = onSaveCaption
        self.onMoveLeading = onMoveLeading
        self.onMoveTrailing = onMoveTrailing
        self.onDelete = onDelete
        _captionText = State(initialValue: attachment.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MemoraSpacing.lg) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            RoundedRectangle(cornerRadius: MemoraRadius.lg)
                                .fill(MemoraColor.divider.opacity(0.16))
                                .frame(height: 240)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundStyle(MemoraColor.textSecondary)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))

                    VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                        Text("キャプション")
                            .font(MemoraTypography.headline)

                        TextField("写真の内容をメモ", text: $captionText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)

                        Text("追加日: \(formattedDate(attachment.createdAt))")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(MemoraSpacing.lg)
            }
            .navigationTitle("写真プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSaveCaption(captionText)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            onMoveLeading()
                        } label: {
                            Label("前へ", systemImage: "arrow.left")
                        }
                        .disabled(!canMoveLeading)

                        Button {
                            onMoveTrailing()
                        } label: {
                            Label("次へ", systemImage: "arrow.right")
                        }
                        .disabled(!canMoveTrailing)

                        Spacer()

                        Button("削除", role: .destructive) {
                            onDelete()
                        }
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}

private enum FileDetailTab: String, CaseIterable, Identifiable {
    case summary
    case transcript
    case memo

    var id: Self { self }

    var title: String {
        switch self {
        case .summary:
            return "Summary"
        case .transcript:
            return "Transcript"
        case .memo:
            return "Memo"
        }
    }

    var icon: String {
        switch self {
        case .summary:
            return "text.quote"
        case .transcript:
            return "text.alignleft"
        case .memo:
            return "square.and.pencil"
        }
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
