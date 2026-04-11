import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?
    @Binding var pendingOpenedAudioFileID: UUID?
    @Query private var googleSettingsList: [GoogleMeetSettings]
    @Query private var projects: [Project]

    // インポート・Meet
    @State private var showFileImporter = false
    @State private var showGoogleMeetImport = false
    @State private var importErrorMessage: String?

    // 検索・フィルタリング用
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var showAskAI = false
    @State private var filterTranscribed: Bool? = nil
    @State private var filterSummarized: Bool? = nil
    @State private var filterLifeLog: Bool? = nil
    @State private var selectedTag: String? = nil
    @State private var sortOption: SortOption = .dateDesc
    @State private var viewMode: ViewMode = .list

    // フィルタリング結果キャッシュ（body 再評価時の再計算を防止）
    @State private var cachedFilteredFiles: [AudioFile] = []

    enum ViewMode: String, CaseIterable {
        case list = "リスト"
        case timeline = "タイムライン"
        case calendar = "カレンダー"
    }

    private typealias SortOption = HomeViewModel.SortOption

    private var importContentTypes: [UTType] {
        [.mpeg4Audio, .wav, .mp3, .aiff, .json, .plainText].compactMap { $0 }
    }

    init(pendingOpenedAudioFileID: Binding<UUID?> = .constant(nil)) {
        self._pendingOpenedAudioFileID = pendingOpenedAudioFileID
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
                if viewModel.audioFiles.isEmpty {
                    emptyStateView
                } else {
                    fileListSection
                }
            }
            .searchable(text: $searchText, prompt: "ファイルを検索")
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showRecordingView = true
                        } label: {
                            Label("録音", systemImage: "mic.fill")
                        }

                        Button {
                            showFileImporter = true
                        } label: {
                            Label("インポート", systemImage: "square.and.arrow.down")
                        }

                        if googleSettingsList.first?.isTokenValid == true {
                            Button {
                                showGoogleMeetImport = true
                            } label: {
                                Label("Google Meet", systemImage: "video.fill")
                            }
                        }
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }

                if hasActiveFilters {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("フィルタをクリア") {
                            clearFilters()
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                AskAIFloatingButton {
                    showAskAI = true
                }
            }
            .navigationDestination(isPresented: $showRecordingView) {
                RecordingView { savedAudioFile in
                    viewModel.loadAudioFiles()
                    selectedAudioFile = viewModel.audioFile(id: savedAudioFile.id)
                }
            }
            .sheet(isPresented: $showAskAI) {
                AskAIView(scope: .global)
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    filterTranscribed: $filterTranscribed,
                    filterSummarized: $filterSummarized
                )
            }
            .navigationDestination(item: $selectedAudioFile) { file in
                FileDetailView(audioFile: file)
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
            .onAppear {
                viewModel.configure(audioFileRepository: AudioFileRepository(modelContext: modelContext))
                viewModel.loadAudioFiles()
                updateFilteredFiles()
                openPendingImportedAudioIfNeeded()
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
                openPendingImportedAudioIfNeeded()
            }
            .onChange(of: searchText) { _, _ in updateFilteredFiles() }
            .onChange(of: filterTranscribed) { _, _ in updateFilteredFiles() }
            .onChange(of: filterSummarized) { _, _ in updateFilteredFiles() }
            .onChange(of: sortOption) { _, _ in updateFilteredFiles() }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "録音ファイル一覧",
            systemImage: "waveform",
            description: Text(recordingHint)
        )
    }

    // MARK: - Content Section

    private var projectLookup: [UUID: String] {
        Dictionary(uniqueKeysWithValues: projects.compactMap { p in
            p.title.isEmpty ? nil : (p.id, p.title)
        })
    }

    private var fileListSection: some View {
        List {
            if hasActiveFilters {
                activeFilterChips
            }

            ForEach(filteredFiles) { file in
                let projectName = file.projectID.flatMap { projectLookup[$0] }
                AudioFileRow(audioFile: file, projectName: projectName)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAudioFile = file
                    }
            }
            .onDelete(perform: deleteAudioFiles)
        }
        .listStyle(.insetGrouped)
    }

    private var hasActiveFilters: Bool {
        filterTranscribed != nil || filterSummarized != nil || filterLifeLog != nil || selectedTag != nil || !searchText.isEmpty
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MemoraSpacing.xs) {
                if let transcribed = filterTranscribed {
                    FilterChip(title: transcribed ? "文字起こし済" : "未文字起こし", isSelected: true) {
                        filterTranscribed = nil
                    }
                }
                if let summarized = filterSummarized {
                    FilterChip(title: summarized ? "要約済" : "未要約", isSelected: true) {
                        filterSummarized = nil
                    }
                }
                if let lifeLog = filterLifeLog {
                    FilterChip(title: lifeLog ? "LifeLog" : "非LifeLog", isSelected: true) {
                        filterLifeLog = nil
                    }
                }
                if let tag = selectedTag {
                    FilterChip(title: tag, isSelected: true) {
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
            importErrorMessage = "ファイルの選択に失敗しました\n\(error.localizedDescription)"
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
            importErrorMessage = "音声ファイルのインポートに失敗しました\n\(error.localizedDescription)"
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
            importErrorMessage = "Plaud ファイルのインポートに失敗しました\n\(error.localizedDescription)"
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
            importErrorMessage = "Plaud ファイルのインポートに失敗しました\n\(error.localizedDescription)"
            return nil
        }
    }
}

struct AudioFileRow: View {
    let audioFile: AudioFile
    let projectName: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
            // 1行目: タイトル（最も重要な情報を先頭に）
            Text(audioFile.title)
                .font(MemoraTypography.body)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(1)

            // 2行目: 日付 + duration + source
            HStack(spacing: MemoraSpacing.xs) {
                Text(formatDate(audioFile.createdAt))
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.textSecondary)

                if audioFile.duration > 0 {
                    Text(formatDuration(audioFile.duration))
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                sourceBadge

                Spacer()
            }

            // 3行目: project + status（ある場合のみ）
            HStack(spacing: MemoraSpacing.xxs) {
                if let projectName {
                    Label(projectName, systemImage: "folder")
                        .font(MemoraTypography.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if audioFile.isTranscribed {
                    StatusChip(title: "文字起こし済", color: MemoraColor.accentBlue)
                }
                if audioFile.isSummarized {
                    StatusChip(title: "要約済", color: MemoraColor.accentGreen)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MemoraSpacing.xs)
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
        Image(systemName: icon)
            .font(MemoraTypography.caption2)
            .foregroundStyle(MemoraColor.textSecondary)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct StatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(MemoraTypography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - AskAI Floating Button

private struct AskAIFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MemoraSpacing.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .medium))

                Text("Ask AI")
                    .font(MemoraTypography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .background(MemoraColor.accentBlue)
            .clipShape(Capsule())
        }
        .padding(.trailing, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.lg)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
