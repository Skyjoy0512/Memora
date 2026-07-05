import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Home Segment

enum HomeSegment: Hashable {
    case files
    case projects
}

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

    // フィルタリング結果キャッシュ（body 再評価時の再計算を防止）
    @State private var cachedFilteredFiles: [AudioFile] = []
    @State private var isRefreshing = false
    @State private var isSelectMode = false
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showMoveToProjectSheet = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var isInitialLoading = true

    // New states for redesigned Home
    @State private var selectedHomeSegment: HomeSegment = .files
    @State private var showDeviceDetails = false
    @State private var showCreateProject = false
    @State private var isFABExpanded = false
    @State private var selectedProject: Project?

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

    private var availableLifeLogTags: [String] {
        Array(Set(viewModel.audioFiles.flatMap(\.lifeLogTags))).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                homeList

                if !isSelectMode {
                    FABMenu(isExpanded: $isFABExpanded, items: fabItems)
                        .padding(.trailing, MemoraSpacing.lg)
                        .padding(.bottom, MemoraSpacing.lg)
                }
            }
                .navigationTitle("ホーム")
                .searchable(text: $searchText, prompt: "検索")
                .toolbar { homeToolbar }
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
                    filterSummarized: $filterSummarized,
                    filterLifeLog: $filterLifeLog,
                    selectedTag: $selectedTag,
                    availableTags: availableLifeLogTags
                )
            }
            .navigationDestination(item: $selectedAudioFile) { file in
                FileDetailView(audioFile: file, autoStartTranscription: shouldAutoTranscribe)
                    .toolbar(.hidden, for: .tabBar)
                    .onAppear { isTabBarHidden = true }
                    .onDisappear { isTabBarHidden = false; shouldAutoTranscribe = false }
            }
            .navigationDestination(item: $selectedProject) { project in
                ProjectDetailView(project: project)
                    .toolbar(.hidden, for: .tabBar)
                    .onAppear { isTabBarHidden = true }
                    .onDisappear { isTabBarHidden = false }
            }
            .navigationDestination(isPresented: $showDeviceDetails) {
                DeviceDetailView(plaudSettings: plaudSettings)
                    .toolbar(.hidden, for: .tabBar)
            }
            .sheet(isPresented: $showCreateProject) {
                CreateProjectView {
                    updateProjectLookup()
                }
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
            .onChange(of: filterLifeLog) { _, _ in updateFilteredFiles() }
            .onChange(of: selectedTag) { _, _ in updateFilteredFiles() }
            .onChange(of: sortOption) { _, _ in updateFilteredFiles() }
            .onChange(of: selectedHomeSegment) { _, _ in updateFilteredFiles() }
        }
    }

    // MARK: - Standard Home Layout

    private var homeList: some View {
        List {
            deviceSection
            segmentSection
            activeFilterSection

            switch selectedHomeSegment {
            case .files:
                filesSection
            case .projects:
                projectsSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable {
            isRefreshing = true
            viewModel.loadAudioFiles()
            updateFilteredFiles()
            updateProjectLookup()
            isRefreshing = false
        }
    }

    private var fabItems: [FABMenu.FABItem] {
        [
            .init(icon: "mic.fill", label: "録音を開始") {
                MemoraHaptics.medium()
                showRecordingView = true
            },
            .init(icon: "square.and.arrow.down", label: "ファイルを読み込む") {
                showFileImporter = true
            },
            .init(icon: "waveform", label: "PLAUD から同期") {
                showDeviceDetails = true
            },
            .init(icon: "person.2.waveform", label: "会議を取り込む") {
                showGoogleMeetImport = true
            }
        ]
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showCreateProject = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("プロジェクトを作成")
        }

        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button {
                    showDeviceDetails = true
                } label: {
                    Label("PLAUD Note Pro", systemImage: "waveform")
                }

                Button {
                    showFilterSheet = true
                } label: {
                    Label("フィルター", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }

                Picker("並び替え", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }

                if selectedHomeSegment == .files {
                    Button {
                        isSelectMode = true
                        selectedFileIDs.removeAll()
                    } label: {
                        Label("選択", systemImage: "checkmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("表示オプション")
        }
    }

    private var deviceSection: some View {
        Section {
            Button {
                showDeviceDetails = true
            } label: {
                HStack {
                    Label("PLAUD Note Pro", systemImage: "waveform")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 2)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.clear)
                    .liquidGlass(cornerRadius: 12, opacity: 0.35, shadowRadius: 4)
            )
        }
    }

    private var segmentSection: some View {
        Section {
            Picker("表示", selection: $selectedHomeSegment) {
                Text("ファイル").tag(HomeSegment.files)
                Text("プロジェクト").tag(HomeSegment.projects)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var activeFilterSection: some View {
        if hasActiveFilters {
            Section {
                Button {
                    clearFilters()
                } label: {
                    Label("検索条件をクリア", systemImage: "xmark.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        if isInitialLoading {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else if filteredFiles.isEmpty {
            Section {
                ContentUnavailableView(
                    searchText.isEmpty && !hasActiveFilters ? "録音ファイルはまだありません" : "一致するファイルがありません",
                    systemImage: "waveform",
                    description: Text(searchText.isEmpty && !hasActiveFilters ? "右上の追加ボタンから録音または読み込みを開始できます。" : "検索語句やフィルターを変更してください。")
                )
            }
        } else {
            Section {
                if isSelectMode && !selectedFileIDs.isEmpty {
                    selectModeToolbarView
                }

                ForEach(filteredFiles) { file in
                    fileRow(for: file)
                        .onAppear { loadMoreAudioFilesIfNeeded(currentFile: file) }
                }

                if viewModel.hasMoreAudioFiles {
                    loadMoreRowView
                }
            }
        }
    }

    @ViewBuilder
    private var projectsSection: some View {
        if projects.isEmpty {
            Section {
                ContentUnavailableView(
                    "プロジェクトはまだありません",
                    systemImage: "folder",
                    description: Text("プロジェクトを作成して録音を整理できます。"),
                    actions: {
                        Button("プロジェクトを作成") {
                            showCreateProject = true
                        }
                    }
                )
            }
        } else {
            Section {
                ForEach(projects) { project in
                    Button {
                        selectedProject = project
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title)
                                    .foregroundStyle(.primary)
                                Text("\(projectFileCount(project))件のファイル")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func fileRow(for file: AudioFile) -> some View {
        Button {
            if isSelectMode {
                if selectedFileIDs.contains(file.id) {
                    selectedFileIDs.remove(file.id)
                } else {
                    selectedFileIDs.insert(file.id)
                }
            } else {
                selectedAudioFile = file
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: fileRowIcon(for: file))
                    .foregroundStyle(file.isProcessing ? .secondary : .primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.title)
                        .foregroundStyle(file.isProcessing ? .secondary : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(formatDate(file.createdAt))
                        if file.duration > 0 {
                            Text(formatDuration(file.duration))
                        }
                        if let projectName = projectName(for: file) {
                            Text(projectName)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if file.isProcessing {
                        ProgressView(value: 0.3)
                    } else if let summary = file.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if isSelectMode {
                    Image(systemName: selectedFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedFileIDs.contains(file.id) ? .tint : .secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteSingleFile(file)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func fileRowIcon(for file: AudioFile) -> String {
        if file.isProcessing {
            return "arrow.up.circle"
        }
        return file.isTranscribed ? "waveform.circle.fill" : "waveform.circle"
    }

    // MARK: - Plaud Settings (for DeviceDetail)

    private var plaudSettings: PlaudSettings? {
        nil // Will be properly wired during integration
    }

    // MARK: - Select Mode Toolbar

    private var selectModeToolbarView: some View {
        HStack(spacing: 16) {
            Button {
                showMoveToProjectSheet = true
            } label: {
                Label("プロジェクト移動", systemImage: "folder")
                    .font(MemoraTypography.chatButton)
                    .foregroundStyle(MemoraColor.textPrimary)
            }

            Spacer()

            Button(role: .destructive) {
                bulkDeleteSelected()
            } label: {
                Label("\(selectedFileIDs.count)件削除", systemImage: "trash")
                    .font(MemoraTypography.chatButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MemoraColor.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Load More

    private var loadMoreRowView: some View {
        HStack {
            Spacer()
            if viewModel.isLoadingMoreAudioFiles {
                ProgressView()
            } else {
                Button("さらに読み込む") {
                    loadMoreAudioFilesIfNeeded()
                }
                .font(MemoraTypography.chatButton)
                .foregroundStyle(MemoraColor.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .onAppear { loadMoreAudioFilesIfNeeded() }
    }

    private func projectFileCount(_ project: Project) -> Int {
        viewModel.audioFiles.filter { $0.projectID == project.id }.count
    }

    // MARK: - Helpers

    private var hasActiveFilters: Bool {
        filterTranscribed != nil || filterSummarized != nil || filterLifeLog != nil || selectedTag != nil || !searchText.isEmpty
    }

    @State private var projectLookup: [UUID: String] = [:]

    private func updateProjectLookup() {
        projectLookup = Dictionary(uniqueKeysWithValues: projects.compactMap { p in
            p.title.isEmpty ? nil : (p.id, p.title)
        })
    }

    private func loadMoreAudioFilesIfNeeded(currentFile: AudioFile? = nil) {
        viewModel.loadMoreAudioFilesIfNeeded(currentFile: currentFile)
        updateFilteredFiles()
    }

    private func projectName(for file: AudioFile) -> String? {
        guard let projectID = file.projectID else { return nil }
        return projectLookup[projectID]
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

    private func deleteSingleFile(_ file: AudioFile) {
        modelContext.delete(file)
        try? modelContext.save()
        MemoraHaptics.warning()
        viewModel.loadAudioFiles()
        updateFilteredFiles()
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        viewModel.deleteAudioFiles(at: offsets, from: filteredFiles)
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

    // MARK: - Formatting Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else {
            return "\(totalSeconds % 60)s"
        }
    }
}


// MARK: - AudioFile isProcessing helper

extension AudioFile {
    var isProcessing: Bool {
        processingJobs.contains(where: { $0.status == "pending" || $0.status == "running" })
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
