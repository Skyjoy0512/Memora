import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Home Segment

enum HomeSegment {
    case files
    case projects
}

// MARK: - Floating Tab

enum FloatingTab: Int, CaseIterable {
    case home = 0
    case todo = 2
    case askAI = 3
    case settings = 4

    var icon: String {
        switch self {
        case .home: return "house"
        case .todo: return "checkmark.circle"
        case .askAI: return "sparkle"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .todo: return "ToDo"
        case .askAI: return "AskAI"
        case .settings: return "Setting"
        }
    }
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
    @Binding var selectedTab: Int
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
    @State private var isFABExpanded = false
    @State private var showDeviceDetails = false
    @State private var showCreateProject = false
    @State private var showMeetingCapture = false

    private typealias SortOption = HomeViewModel.SortOption

    private var importContentTypes: [UTType] {
        [.mpeg4Audio, .wav, .mp3, .aiff, .json, .plainText].compactMap { $0 }
    }

    init(pendingOpenedAudioFileID: Binding<UUID?> = .constant(nil), isTabBarHidden: Binding<Bool> = .constant(false), triggerRecording: Binding<Bool> = .constant(false), triggerFileImport: Binding<Bool> = .constant(false), selectedTab: Binding<Int> = .constant(0)) {
        self._pendingOpenedAudioFileID = pendingOpenedAudioFileID
        self._isTabBarHidden = isTabBarHidden
        self._triggerRecording = triggerRecording
        self._triggerFileImport = triggerFileImport
        self._selectedTab = selectedTab
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
            ZStack(alignment: .bottom) {
                Color(hex: "ECECEC").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 21) {
                        homeHeaderView
                        searchBarView
                        segmentPickerView
                        contentAreaView
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16.5)
                    .padding(.bottom, 190)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    isRefreshing = true
                    viewModel.loadAudioFiles()
                    updateFilteredFiles()
                    isRefreshing = false
                }

                // FAB + expanded menu (bottom right)
                fabAreaView

                // Floating Tab Bar (very bottom)
                floatingTabBarView
            }
            .toolbar(.hidden, for: .navigationBar)
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
            .sheet(isPresented: $showMeetingCapture) {
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

    // MARK: - Plaud Settings (for DeviceDetail)

    private var plaudSettings: PlaudSettings? {
        nil // Will be properly wired during integration
    }

    // MARK: - Home Header

    private var homeHeaderView: some View {
        HStack(spacing: 0) {
            // Left: PLUAD Note Pro pill
            Button {
                showDeviceDetails = true
            } label: {
                Text("PLAUD Note Pro")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .padding(.horizontal, 20)
                    .frame(height: 43)
            }
            .liquidGlass(cornerRadius: 21.5, opacity: 0.52, shadowRadius: 10)

            Spacer()

            // Right: AA button (menu trigger)
            Menu {
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

                Divider()

                Button {
                    isSelectMode = true
                    selectedFileIDs.removeAll()
                } label: {
                    Label("選択", systemImage: "checkmark.circle")
                }
            } label: {
                ZStack {
                    // Outer liquid glass circle 56pt
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 56, height: 56)

                    // Inner #B2B2B2 circle 44pt
                    Circle()
                        .fill(Color(hex: "B2B2B2"))
                        .frame(width: 44, height: 44)

                    // White text
                    Text("AA")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .aaButtonGlass
            .accessibilityLabel("ファイル表示オプション")
        }
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MemoraColor.textTertiary)

            TextField("Search", text: $searchText)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MemoraColor.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MemoraColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(hex: "DDDDDE"), in: Capsule())
    }

    // MARK: - Segment Picker

    private var segmentPickerView: some View {
        HStack(spacing: 8) {
            // Files button
            Button {
                MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                    selectedHomeSegment = .files
                }
            } label: {
                Text("ファイル")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(width: 91, height: 34)
                    .background(
                        selectedHomeSegment == .files
                            ? Color(hex: "D9D9D9")
                            : Color.clear,
                        in: Capsule()
                    )
            }

            // Projects button
            Button {
                MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                    selectedHomeSegment = .projects
                }
            } label: {
                Text("プロジェクト")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(width: 115, height: 34)
                    .background(
                        selectedHomeSegment == .projects
                            ? Color(hex: "D9D9D9")
                            : Color.clear,
                        in: Capsule()
                    )
            }
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentAreaView: some View {
        if isInitialLoading {
            skeletonView
        } else if selectedHomeSegment == .files {
            fileContentView
        } else {
            projectGridView
        }
    }

    // MARK: - File Content (List or Empty)

    @ViewBuilder
    private var fileContentView: some View {
        if viewModel.audioFiles.isEmpty && searchText.isEmpty && !hasActiveFilters {
            fileEmptyView
        } else {
            fileListView
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { _ in
                skeletonFileCard
            }
        }
    }

    private var skeletonFileCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(hex: "F3F3F3"))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 17, cornerRadius: 4)
                    .frame(maxWidth: 200)
                SkeletonView(height: 11, cornerRadius: 4)
                    .frame(maxWidth: 140)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - File Empty

    private var fileEmptyView: some View {
        VStack(spacing: 34) {
            Spacer().frame(height: 80)

            EmptyStateView(
                icon: "waveform",
                title: "録音ファイル一覧",
                description: recordingHint
            )

            Spacer()
        }
    }

    // MARK: - File List

    private var fileListView: some View {
        VStack(spacing: 10) {
            if hasActiveFilters {
                filterChipsView
            }

            if isSelectMode && !selectedFileIDs.isEmpty {
                selectModeToolbarView
            }

            LazyVStack(spacing: 10) {
                ForEach(filteredFiles) { file in
                    fileCardView(for: file)
                        .onAppear { loadMoreAudioFilesIfNeeded(currentFile: file) }
                }

                if viewModel.hasMoreAudioFiles {
                    loadMoreRowView
                }
            }
        }
    }

    // MARK: - Individual File Card

    @ViewBuilder
    private func fileCardView(for file: AudioFile) -> some View {
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Left: circle icon
                    if isSelectMode {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "F3F3F3"))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selectedFileIDs.contains(file.id) ? MemoraColor.accentNothing : MemoraColor.textTertiary)
                        }
                    } else {
                        iconCircle(for: file)
                    }

                    // Title + subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                file.isProcessing ? Color(hex: "C8C8C8") : MemoraColor.textPrimary
                            )
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(formatDate(file.createdAt))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color(hex: "58585A"))

                            if file.duration > 0 {
                                Text(formatDuration(file.duration))
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(Color(hex: "58585A"))
                            }
                        }
                    }

                    Spacer()

                    // Ellipsis menu (not in select mode)
                    if !isSelectMode {
                        Menu {
                            Button {
                                isSelectMode = true
                                selectedFileIDs.insert(file.id)
                            } label: {
                                Label("選択", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MemoraColor.textSecondary)
                                .frame(width: 32, height: 32)
                        }
                    }
                }

                // Processing indicator
                if file.isProcessing {
                    processingIndicator
                }

                // Summary preview
                if let summary = file.summary, !summary.isEmpty && !file.isProcessing {
                    summaryPreview(text: summary)
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelectMode {
                Button {
                    isSelectMode = true
                    selectedFileIDs.insert(file.id)
                } label: {
                    Label("選択", systemImage: "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    deleteSingleFile(file)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        }
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

    private func iconCircle(for file: AudioFile) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "F3F3F3"))
                .frame(width: 44, height: 44)

            if file.isProcessing {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color(hex: "C8C8C8"))
            } else {
                Image(systemName: file.isTranscribed ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
    }

    private var processingIndicator: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: 0.3)
                .tint(.black)
                .frame(height: 4)

            Text("処理中")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(hex: "58585A"))
        }
        .padding(.top, 12)
    }

    private func summaryPreview(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(MemoraColor.textSecondary)
            .lineLimit(2)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "F4F4F4"), in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 12)
    }

    // MARK: - Filter Chips

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
        }
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

    // MARK: - Project Grid

    private var projectGridView: some View {
        VStack(spacing: 16) {
            if projects.isEmpty {
                VStack(spacing: 34) {
                    Spacer().frame(height: 80)
                    EmptyStateView(
                        icon: "folder",
                        title: "プロジェクト",
                        description: "プロジェクトを作成して録音を整理しましょう"
                    )
                    Spacer()
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(projects) { project in
                        homeProjectCard(project)
                    }
                }
            }

            // "+ プロジェクト作成" button
            HStack {
                Spacer()
                Button {
                    showCreateProject = true
                } label: {
                    Label("プロジェクト作成", systemImage: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                        .padding(.horizontal, 20)
                        .frame(height: 43)
                }
                .liquidGlass(cornerRadius: 21.5, opacity: 0.52, shadowRadius: 10)
                Spacer()
            }
        }
    }

    private func homeProjectCard(_ project: Project) -> some View {
        Button {
            // Navigate to project detail - handled by parent
            let projectID = project.id
            selectedTab = 1 // Projects tab
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // Small icon circle
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MemoraColor.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "F3F3F3"), in: Circle())

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MemoraColor.textPrimary)
                        .lineLimit(2)

                    Text("\(projectFileCount(project)) Files")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "58585A"))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func projectFileCount(_ project: Project) -> Int {
        viewModel.audioFiles.filter { $0.projectID == project.id }.count
    }

    // MARK: - FAB Area

    private var fabAreaView: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isFABExpanded {
                fabExpandedMenu
                    .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
            }

            fabButtonView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16.5)
        .padding(.bottom, 120)
    }

    private var fabButtonView: some View {
        Button {
            MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.35, dampingFraction: 0.7)) {
                isFABExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 72, height: 72)

                Image(systemName: isFABExpanded ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
            }
        }
        .fabGlassStyle
    }

    private var fabExpandedMenu: some View {
        VStack(spacing: 12) {
            // 録音開始
            fabMenuItem(
                icon: "mic.fill",
                label: "録音開始",
                action: {
                    MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.3, dampingFraction: 0.8)) {
                        isFABExpanded = false
                    }
                    showRecordingView = true
                }
            )

            // インポート
            fabMenuItem(
                icon: "square.and.arrow.down",
                label: "インポート",
                action: {
                    MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.3, dampingFraction: 0.8)) {
                        isFABExpanded = false
                    }
                    showFileImporter = true
                }
            )

            // 会議キャプチャ
            fabMenuItem(
                icon: "person.2.waveform",
                label: "会議キャプチャ",
                action: {
                    MemoraAnimation.animate(reduceMotion, using: .spring(response: 0.3, dampingFraction: 0.8)) {
                        isFABExpanded = false
                    }
                    showMeetingCapture = true
                }
            )
        }
    }

    private func fabMenuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(width: 32)

                Text(label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(width: 330, height: 80)
        }
        .fabMenuItemGlass
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBarView: some View {
        HStack(spacing: 0) {
            ForEach(FloatingTab.allCases, id: \.self) { tab in
                Button {
                    MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                        selectedTab = tab.rawValue
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(MemoraColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab.rawValue
                            ? Color(hex: "D9D9D9")
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .frame(height: 96)
        .liquidGlass(cornerRadius: 30, opacity: 0.72, shadowRadius: 12)
        .padding(.horizontal, 40)
        .padding(.bottom, 34)
    }

    // MARK: - Helpers

    private var hasActiveFilters: Bool {
        filterTranscribed != nil || filterSummarized != nil || filterLifeLog != nil || selectedTag != nil || !searchText.isEmpty
    }

    private var recordingHint: String {
        "右下の AskAI またはツールバーの追加ボタンから利用"
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

// MARK: - Private View Modifiers (AA Button Glass, FAB Glass, FAB Menu Item Glass)

extension View {
    fileprivate var aaButtonGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                self
                    .glassEffect(.regular.interactive(), in: .circle)
            } else {
                self
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(0.52))
                            .blendMode(.overlay)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
        }
    }

    fileprivate var fabGlassStyle: some View {
        Group {
            if #available(iOS 26.0, *) {
                self
                    .glassEffect(.regular.interactive(), in: .circle)
            } else {
                self
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(0.72))
                            .blendMode(.overlay)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
        }
    }

    fileprivate var fabMenuItemGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                self
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            } else {
                self
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.72))
                            .blendMode(.overlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
        }
    }
}

// MARK: - AudioFile isProcessing helper

extension AudioFile {
    var isProcessing: Bool {
        processingJobs.contains(where: { $0.status == "pending" || $0.status == "running" })
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
