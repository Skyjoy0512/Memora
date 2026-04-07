import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?
    @Binding var showRecordingFromFAB: Bool
    @Binding var pendingOpenedAudioFileID: UUID?

    // 検索・フィルタリング用
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var showAskAI = false
    @State private var filterTranscribed: Bool? = nil // nil=すべて, true=済み, false=未済み
    @State private var filterSummarized: Bool? = nil // nil=すべて, true=済み, false=未済み
    @State private var filterLifeLog: Bool? = nil // nil=すべて, true=ライフログのみ
    @State private var selectedTag: String? = nil // タグフィルタ
    @State private var sortOption: SortOption = .dateDesc
    @State private var viewMode: ViewMode = .list // 表示モード

    enum ViewMode: String, CaseIterable {
        case list = "リスト"
        case timeline = "タイムライン"
        case calendar = "カレンダー"
    }

    private typealias SortOption = HomeViewModel.SortOption

    init(
        showRecordingFromFAB: Binding<Bool> = .constant(false),
        pendingOpenedAudioFileID: Binding<UUID?> = .constant(nil)
    ) {
        self._showRecordingFromFAB = showRecordingFromFAB
        self._pendingOpenedAudioFileID = pendingOpenedAudioFileID
    }

    // フィルタリング・ソート後のファイル一覧
    var filteredFiles: [AudioFile] {
        viewModel.filteredFiles(
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
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAskAI = true
                    } label: {
                        Image(systemName: "sparkle")
                    }

                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
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
            .navigationDestination(item: $selectedAudioFile) { file in
                FileDetailView(audioFile: file)
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    filterTranscribed: $filterTranscribed,
                    filterSummarized: $filterSummarized
                )
            }
            .onAppear {
                viewModel.configure(audioFileRepository: AudioFileRepository(modelContext: modelContext))
                viewModel.loadAudioFiles()
                openPendingImportedAudioIfNeeded()
            }
            .onChange(of: showRecordingFromFAB) { _, newValue in
                if newValue {
                    showRecordingView = true
                    showRecordingFromFAB = false
                }
            }
            .onChange(of: showRecordingView) { _, isPresented in
                if !isPresented {
                    viewModel.loadAudioFiles()
                    openPendingImportedAudioIfNeeded()
                }
            }
            .onChange(of: pendingOpenedAudioFileID) { _, _ in
                viewModel.loadAudioFiles()
                openPendingImportedAudioIfNeeded()
            }
            .onChange(of: viewModel.audioFiles.count) { _, _ in
                openPendingImportedAudioIfNeeded()
            }
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

    private var fileListSection: some View {
        List {
            ForEach(filteredFiles) { file in
                AudioFileRow(audioFile: file)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAudioFile = file
                    }
            }
            .onDelete(perform: deleteAudioFiles)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        viewModel.deleteAudioFiles(at: offsets, from: filteredFiles)
    }

    private var recordingHint: String {
        "右下の追加ボタンから録音を開始"
    }

    private func openPendingImportedAudioIfNeeded() {
        guard let pendingOpenedAudioFileID else { return }
        guard let audioFile = viewModel.audioFile(id: pendingOpenedAudioFileID) else { return }
        selectedAudioFile = audioFile
        self.pendingOpenedAudioFileID = nil
    }
}

struct AudioFileRow: View {
    let audioFile: AudioFile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                Text(formatDate(audioFile.createdAt))
                    .font(MemoraTypography.caption1)
                    .tracking(-0.43)
                    .foregroundStyle(MemoraColor.textSecondary)

                Text(audioFile.title)
                    .font(MemoraTypography.body)
                    .tracking(-0.43)
                    .foregroundStyle(MemoraColor.textPrimary)

                if let summary = audioFile.summary, !summary.isEmpty {
                    Text(summary)
                        .font(MemoraTypography.caption1)
                        .tracking(-0.23)
                        .foregroundStyle(MemoraColor.textTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, MemoraSpacing.xs)

            Divider()
                .background(MemoraColor.divider)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
