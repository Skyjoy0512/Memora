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
            ZStack {
                if viewModel.audioFiles.isEmpty {
                    // 空の状態 - 下部の浮遊ボタンから録音導線を誘導
                    VStack(spacing: MemoraSpacing.xxl) {
                        Spacer()

                        Image(systemName: "waveform")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(MemoraColor.textSecondary)

                        Text("Memora")
                            .font(MemoraTypography.largeTitle)

                        Text("録音ファイル一覧")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(.secondary)

                        Text(recordingHint)
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)

                        Spacer()
                    }
                    .padding(.bottom, 110)
                } else {
                    // ファイル一覧
                    VStack(spacing: 0) {
                        // 表示モード選択
                        Picker("表示モード", selection: $viewMode) {
                            Text("リスト").tag(ViewMode.list)
                            Text("タイムライン").tag(ViewMode.timeline)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // 検索バー
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField("検索", text: $searchText)
                                .textFieldStyle(.plain)

                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, MemoraSpacing.lg)
                        .padding(.vertical, MemoraSpacing.xs)
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.sm)
                        .padding(.horizontal)

                        // フィルター・ソートバー
                        HStack(spacing: 8) {
                            // フィルターボタン
                            Button(action: { showFilterSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text("フィルター")
                                }
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, MemoraSpacing.lg)
                                .padding(.vertical, 6)
                                .background(MemoraColor.divider.opacity(0.1))
                                .cornerRadius(MemoraRadius.sm)
                            }

                            Spacer()

                            // ソート選択
                            Picker("", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(MemoraTypography.caption1)
                        }
                        .padding(.horizontal)

                        Divider()

                        // ファイル一覧
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
                    }
                }
            }
            .safeAreaPadding(.bottom, 116)
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAskAI = true
                    } label: {
                        Image(systemName: "sparkles")
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
        HStack(spacing: MemoraSpacing.lg) {
            // アイコン
            Image(systemName: "waveform")
                .font(MemoraTypography.title2)
                .foregroundStyle(MemoraColor.textSecondary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(audioFile.title)
                    .font(MemoraTypography.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 5) {
                    Text(formatDate(audioFile.createdAt))
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(formatDuration(audioFile.duration))
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if audioFile.isPlaudImport {
                Text("Plaud")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(MemoraColor.accentBlue.opacity(0.1))
                    .cornerRadius(4)
            }

            if audioFile.isTranscribed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MemoraColor.textSecondary)
            }
        }
        .padding(.vertical, MemoraSpacing.xs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
