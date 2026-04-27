import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = HomeViewModel()
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?
    @State private var shouldAutoTranscribe = false
    @Binding var pendingOpenedAudioFileID: UUID?
    @Binding var isTabBarHidden: Bool
    @Binding var triggerRecording: Bool
    @Binding var triggerFileImport: Bool
    @Query private var googleSettingsList: [GoogleMeetSettings]
    @Query private var projects: [Project]

    // インポート・Meet
    @State private var showFileImporter = false
    @State private var showGoogleMeetImport = false
    @State private var importErrorMessage: String?

    // 検索・フィルタリング用
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var filterTranscribed: Bool? = nil
    @State private var filterSummarized: Bool? = nil
    @State private var filterLifeLog: Bool? = nil
    @State private var selectedTag: String? = nil
    @State private var sortOption: SortOption = .dateDesc
    @State private var viewMode: ViewMode = .list

    // フィルタリング結果キャッシュ（body 再評価時の再計算を防止）
    @State private var cachedFilteredFiles: [AudioFile] = []
    @State private var isRefreshing = false
    @State private var isSelectMode = false
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showMoveToProjectSheet = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var isInitialLoading = true

    enum ViewMode: String, CaseIterable {
        case list = "リスト"
        case timeline = "タイムライン"
        case calendar = "カレンダー"
    }

    private typealias SortOption = HomeViewModel.SortOption

    private var importContentTypes: [UTType] {
        [.mpeg4Audio, .wav, .mp3, .aiff, .json, .plainText].compactMap { $0 }
    }

    init(pendingOpenedAudioFileID: Binding<UUID?> = .constant(nil), isTabBarHidden: Binding<Bool> = .constant(false), triggerRecording: Binding<Bool> = .constant(false), triggerFileImport: Binding<Bool> = .constant(false)) {
        self._pendingOpenedAudioFileID = pendingOpenedAudioFileID
        self._isTabBarHidden = isTabBarHidden
        self._triggerRecording = triggerRecording
        self._triggerFileImport = triggerFileImport
    }

    // フィルタリング・ソート後のファイル一覧（キャッシュ参照）
    var filteredFiles: [AudioFile] {
        cachedFilteredFiles
    }

    private func updateFilteredFiles() {
        cachedFilteredFiles = viewModel.filteredFiles(
            searchText: searchText,
            filterTranscribed: filterTranscribed,
            filterSummarized: filterSummarized,
            filterLifeLog: filterLifeLog,
            selectedTag: selectedTag,
            sortOption: sortOption
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoading {
                    skeletonListView
                } else if viewModel.audioFiles.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else {
                    fileListSection
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "ファイルを検索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectMode {
                        Button("キャンセル") {
                            isSelectMode = false
                            selectedFileIDs.removeAll()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectMode {
                        selectModeMenu
                    }
                }
                if hasActiveFilters && !isSelectMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("フィルタをクリア") {
                            clearFilters()
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showRecordingView) {
                RecordingView { savedAudioFile in
                    viewModel.loadAudioFiles()
                    selectedAudioFile = viewModel.audioFile(id: savedAudioFile.id)
                    shouldAutoTranscribe = true
                }
                .toolbar(.hidden, for: .tabBar)
                .onAppear { isTabBarHidden = true }
                .onDisappear { isTabBarHidden = false }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    filterTranscribed: $filterTranscribed,
                    filterSummarized: $filterSummarized
                )
            }
            .navigationDestination(item: $selectedAudioFile) { file in
                FileDetailView(audioFile: file, autoStartTranscription: shouldAutoTranscribe)
                    .toolbar(.hidden, for: .tabBar)
                    .onAppear { isTabBarHidden = true }
                    .onDisappear { isTabBarHidden = false; shouldAutoTranscribe = false }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: importContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImportResult(result)
            }
            .sheet(isPresented: $showGoogleMeetImport) {
                GoogleMeetImportView()
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
            .sheet(isPresented: $showMoveToProjectSheet) {
                moveToProjectSheet
            }
            .task {
                viewModel.configure(audioFileRepository: AudioFileRepository(modelContext: modelContext))
                viewModel.loadAudioFiles()
                updateFilteredFiles()
                updateProjectLookup()
                openPendingImportedAudioIfNeeded()
                isInitialLoading = false
            }
            .onChange(of: showRecordingView) { _, isPresented in
                if !isPresented {
                    viewModel.loadAudioFiles()
                    updateFilteredFiles()
                    openPendingImportedAudioIfNeeded()
                }
            }
            .onChange(of: pendingOpenedAudioFileID) { _, _ in
                viewModel.loadAudioFiles()
                updateFilteredFiles()
                openPendingImportedAudioIfNeeded()
            }
            .onChange(of: viewModel.audioFiles) { _, _ in
                updateFilteredFiles()
                updateProjectLookup()
                openPendingImportedAudioIfNeeded()
            }
            .onChange(of: triggerRecording) { _, newValue in
                guard newValue else { return }
                triggerRecording = false
                showRecordingView = true
            }
            .onChange(of: triggerFileImport) { _, newValue in
                guard newValue else { return }
                triggerFileImport = false
                showFileImporter = true
            }
            .onChange(of: searchText) { _, _ in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    updateFilteredFiles()
                }
            }
            .onChange(of: filterTranscribed) { _, _ in updateFilteredFiles() }
            .onChange(of: filterSummarized) { _, _ in updateFilteredFiles() }
            .onChange(of: sortOption) { _, _ in updateFilteredFiles() }
        }
    }

    // MARK: - Skeleton Loading

    private var skeletonListView: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonAudioFileRow()
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: MemoraSpacing.xxxl) {
            Spacer()

            EmptyStateView(
                icon: "waveform",
                title: "録音ファイル一覧",
                description: recordingHint
            )

            Spacer()
        }
    }

    private var selectModeMenu: some View {
        Menu {
            Button {
                if selectedFileIDs.count == filteredFiles.count {
                    selectedFileIDs.removeAll()
                } else {
                    selectedFileIDs = Set(filteredFiles.map(\.id))
                }
            } label: {
                if selectedFileIDs.count == filteredFiles.count {
                    Label("全て解除", systemImage: "checkmark.circle")
                } else {
                    Label("全て選択", systemImage: "checkmark.circle.fill")
                }
            }
        } label: {
            Text("\(selectedFileIDs.count)")
                .font(MemoraTypography.chatLabel)
                .foregroundStyle(MemoraColor.interactivePrimaryLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MemoraColor.interactivePrimary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Content Section

    @State private var projectLookup: [UUID: String] = [:]

    private func updateProjectLookup() {
        projectLookup = Dictionary(uniqueKeysWithValues: projects.compactMap { p in
            p.title.isEmpty ? nil : (p.id, p.title)
        })
    }

    private var fileListSection: some View {
        List(selection: isSelectMode ? $selectedFileIDs : nil) {
            if hasActiveFilters {
                activeFilterChips
            }

            ForEach(filteredFiles) { file in
                if isSelectMode {
                    AudioFileRow(audioFile: file, projectName: nil, showActions: false)
                        .tag(file.id)
                        .onAppear { loadMoreAudioFilesIfNeeded(currentFile: file) }
                } else {
                    Button {
                        selectedAudioFile = file
                    } label: {
                        AudioFileRow(audioFile: file, projectName: nil, showActions: false)
                    }
                    .onAppear { loadMoreAudioFilesIfNeeded(currentFile: file) }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            isSelectMode = true
                            selectedFileIDs.insert(file.id)
                        } label: {
                            Label("選択", systemImage: "checkmark.circle")
                        }
                        .tint(MemoraColor.accentNothing)
                    }
                }
            }
            .onDelete(perform: deleteAudioFiles)

            if viewModel.hasMoreAudioFiles {
                loadMoreRow
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, .constant(isSelectMode ? .active : .inactive))
        .refreshable {
            isRefreshing = true
            viewModel.loadAudioFiles()
            updateFilteredFiles()
            isRefreshing = false
        }
        .overlay(alignment: .bottom) {
            if isSelectMode && !selectedFileIDs.isEmpty {
                selectModeToolbar
            }
        }
    }

    private var selectModeToolbar: some View {
        HStack(spacing: MemoraSpacing.lg) {
            Button {
                showMoveToProjectSheet = true
            } label: {
                Label("プロジェクト移動", systemImage: "folder")
                    .font(MemoraTypography.chatButton)
            }

            Spacer()

            Button(role: .destructive) {
                bulkDeleteSelected()
            } label: {
                Label("\(selectedFileIDs.count)件削除", systemImage: "trash")
                    .font(MemoraTypography.chatButton)
            }
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.vertical, MemoraSpacing.md)
        .glassCard(.default)
    }

    private var hasActiveFilters: Bool {
        filterTranscribed != nil || filterSummarized != nil || filterLifeLog != nil || selectedTag != nil || !searchText.isEmpty
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MemoraSpacing.xs) {
                if let transcribed = filterTranscribed {
                    NothingFilterChip(title: transcribed ? "文字起こし済" : "未文字起こし") {
                        filterTranscribed = nil
                    }
                }
                if let summarized = filterSummarized {
                    NothingFilterChip(title: summarized ? "要約済" : "未要約") {
                        filterSummarized = nil
                    }
                }
                if let lifeLog = filterLifeLog {
                    NothingFilterChip(title: lifeLog ? "LifeLog" : "非LifeLog") {
                        filterLifeLog = nil
                    }
                }
                if let tag = selectedTag {
                    NothingFilterChip(title: tag) {
                        selectedTag = nil
                    }
                }
            }
            .padding(.horizontal, MemoraSpacing.sm)
            .padding(.vertical, MemoraSpacing.xxxs)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        viewModel.deleteAudioFiles(at: offsets, from: filteredFiles)
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if viewModel.isLoadingMoreAudioFiles {
                ProgressView()
            } else {
                Button("さらに読み込む") {
                    loadMoreAudioFilesIfNeeded()
                }
                .font(MemoraTypography.chatButton)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
        .onAppear { loadMoreAudioFilesIfNeeded() }
    }

    private func loadMoreAudioFilesIfNeeded(currentFile: AudioFile? = nil) {
        viewModel.loadMoreAudioFilesIfNeeded(currentFile: currentFile)
        updateFilteredFiles()
    }

    private func bulkDeleteSelected() {
        let toDelete = filteredFiles.filter { selectedFileIDs.contains($0.id) }
        for file in toDelete {
            modelContext.delete(file)
        }
        try? modelContext.save()
        MemoraHaptics.warning()
        selectedFileIDs.removeAll()
        isSelectMode = false
        viewModel.loadAudioFiles()
        updateFilteredFiles()
    }

    private func moveSelectedToProject(_ projectID: UUID?) {
        let toMove = filteredFiles.filter { selectedFileIDs.contains($0.id) }
        for file in toMove {
            file.projectID = projectID
        }
        try? modelContext.save()
        selectedFileIDs.removeAll()
        isSelectMode = false
    }

    private func clearFilters() {
        filterTranscribed = nil
        filterSummarized = nil
        filterLifeLog = nil
        selectedTag = nil
        searchText = ""
    }

    private var recordingHint: String {
        "右下の AskAI またはツールバーの追加ボタンから利用"
    }

    private func openPendingImportedAudioIfNeeded() {
        guard let pendingOpenedAudioFileID else { return }
        guard let audioFile = viewModel.audioFile(id: pendingOpenedAudioFileID) else { return }
        selectedAudioFile = audioFile
        shouldAutoTranscribe = true
        self.pendingOpenedAudioFileID = nil
    }

    // MARK: - Import

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aiff", "aac"]
            let audioURLs = urls.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            let otherURLs = urls.filter { !audioExtensions.contains($0.pathExtension.lowercased()) }

            for url in audioURLs {
                importAudioFile(from: url)
            }
            if !otherURLs.isEmpty {
                importPlaudFiles(otherURLs)
            }
        case .failure(let error):
            print("[HomeView] File import failed: \(error.localizedDescription)")
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
            pendingOpenedAudioFileID = audioFile.id
        } catch {
            print("[HomeView] Audio file import failed: \(error.localizedDescription)")
            importErrorMessage = "音声ファイルのインポートに失敗しました。もう一度お試しください。"
        }
    }

    private func importPlaudFiles(_ urls: [URL]) {
        var lastImportedID: UUID?
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "json" {
                if let file = importPlaudJSON(url: url) { lastImportedID = file.id }
            } else {
                if let file = importPlaudText(url: url) { lastImportedID = file.id }
            }
        }
        if let lastImportedID { pendingOpenedAudioFileID = lastImportedID }
    }

    private func importPlaudJSON(url: URL) -> AudioFile? {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let export = try JSONDecoder().decode(PlaudExportFile.self, from: data)
            let title = export.title ?? url.deletingPathExtension().lastPathComponent
            let text = export.transcript?.isEmpty == false ? export.transcript! : (export.summary ?? "")
            let file = PlaudImportService.importTextOnly(title: title, textContent: text, modelContext: modelContext)
            if let summary = export.summary, !summary.isEmpty {
                file.summary = summary
                file.isSummarized = true
                try? modelContext.save()
            }
            return file
        } catch {
            print("[HomeView] Plaud JSON import failed: \(error.localizedDescription)")
            importErrorMessage = "Plaud ファイルのインポートに失敗しました。もう一度お試しください。"
            return nil
        }
    }

    private func importPlaudText(url: URL) -> AudioFile? {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let text = try String(contentsOf: url, encoding: .utf8)
            return PlaudImportService.importTextOnly(
                title: url.deletingPathExtension().lastPathComponent,
                textContent: text,
                modelContext: modelContext
            )
        } catch {
            print("[HomeView] Plaud text import failed: \(error.localizedDescription)")
            importErrorMessage = "Plaud ファイルのインポートに失敗しました。もう一度お試しください。"
            return nil
        }
    }

    // MARK: - Move to Project Sheet

    private var moveToProjectSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        moveSelectedToProject(nil)
                        showMoveToProjectSheet = false
                    } label: {
                        Label("プロジェクトなし", systemImage: "tray")
                    }
                }

                Section("プロジェクト") {
                    ForEach(projects) { project in
                        Button {
                            moveSelectedToProject(project.id)
                            showMoveToProjectSheet = false
                        } label: {
                            Label(project.title, systemImage: "folder")
                        }
                    }
                }
            }
            .navigationTitle("プロジェクトに移動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showMoveToProjectSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Nothing Filter Chip

struct NothingFilterChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MemoraSpacing.xxxs) {
                Text(title)
                    .font(MemoraTypography.chatToken)
                    .fontWeight(.medium)
                    .foregroundStyle(MemoraColor.textPrimary)

                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(MemoraColor.textTertiary)
            }
            .padding(.horizontal, MemoraSpacing.sm)
            .padding(.vertical, 6)
            .background(Color.clear)
            .overlay {
                Capsule().stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
            }
            .clipShape(Capsule())
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
