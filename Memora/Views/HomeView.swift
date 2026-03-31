import SwiftUI

struct HomeView: View {
    @Environment(\.repositoryFactory) private var repoFactory
    @State private var audioFiles: [AudioFile] = []
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?
    @State private var showImportPicker = false
    @Binding var showRecordingFromFAB: Bool

    // 検索・フィルタリング用
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var filterTranscribed: Bool? = nil // nil=すべて, true=済み, false=未済み
    @State private var filterSummarized: Bool? = nil // nil=すべて, true=済み, false=未済み
    @State private var filterLifeLog: Bool? = nil // nil=すべて, true=ライフログのみ
    @State private var selectedTag: String? = nil // タグフィルタ
    // 名前変更
    @State private var showRenameAlert = false
    @State private var renameFileId: AudioFile?
    @State private var renamedTitle = ""
    @State private var showDeleteAlert = false
    @State private var deleteFileId: AudioFile?
    @State private var sortOption: SortOption = .dateDesc
    @State private var viewMode: ViewMode = .list // 表示モード

    enum SortOption: String, CaseIterable {
        case dateDesc = "日付（新しい順）"
        case dateAsc = "日付（古い順）"
        case titleAsc = "タイトル（昇順）"
        case titleDesc = "タイトル（降順）"
    }

    enum ViewMode: String, CaseIterable {
        case list = "リスト"
        case timeline = "タイムライン"
        case calendar = "カレンダー"
    }

    init(showRecordingFromFAB: Binding<Bool> = .constant(false)) {
        self._showRecordingFromFAB = showRecordingFromFAB
    }

    // フィルタリング・ソート後のファイル一覧
    var filteredFiles: [AudioFile] {
        var files = audioFiles

        // 検索
        if !searchText.isEmpty {
            files = files.filter { file in
                file.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 文字起こしステータスでフィルタ
        if let transcribed = filterTranscribed {
            files = files.filter { $0.isTranscribed == transcribed }
        }

        // 要約ステータスでフィルタ
        if let summarized = filterSummarized {
            files = files.filter { $0.isSummarized == summarized }
        }

        // ライフログでフィルタ
        if let lifeLog = filterLifeLog {
            files = files.filter { $0.isLifeLog == lifeLog }
        }

        // タグでフィルタ
        if let tag = selectedTag, !tag.isEmpty {
            files = files.filter { $0.lifeLogTags.contains(tag) }
        }

        // ソート
        switch sortOption {
        case .dateDesc:
            files.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:
            files.sort { $0.createdAt < $1.createdAt }
        case .titleAsc:
            files.sort { $0.title < $1.title }
        case .titleDesc:
            files.sort { $0.title > $1.title }
        }

        return files
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if audioFiles.isEmpty {
                    EmptyStateView(
                        icon: "waveform",
                        title: "Memora",
                        description: recordingHint
                    )
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
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showImportPicker = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }

                    Button {
                        selectedAudioFile = nil
                    } label: {
                        Image(systemName: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showImportPicker) {
                ImportView(isPresented: $showImportPicker) { url in
                    if let factory = repoFactory {
                        let service = ImportService()
                        if let _ = service.importFile(from: url, repoFactory: factory) {
                            audioFiles = (try? factory.audioFileRepo.fetchAll()) ?? []
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showRecordingView) {
                RecordingView()
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
            .onChange(of: showRecordingFromFAB) { _, newValue in
                if newValue {
                    showRecordingView = true
                    showRecordingFromFAB = false
                }
            }
            .task {
                if let factory = repoFactory {
                    audioFiles = (try? factory.audioFileRepo.fetchAll()) ?? []
                }
            }
        }
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = filteredFiles[index]
            try? repoFactory?.audioFileRepo.delete(file)
        }
        // Refresh list
        audioFiles = (try? repoFactory?.audioFileRepo.fetchAll()) ?? []
    }

    private var recordingHint: String {
        "右下の追加ボタンから録音を開始"
    }
}

struct AudioFileRow: View {
    let audioFile: AudioFile
    var onRename: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: MemoraSpacing.lg) {
            Image(systemName: "waveform")
                .font(MemoraTypography.title2)
                .foregroundStyle(MemoraColor.textSecondary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(audioFile.title)
                    .font(MemoraTypography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(formatDate(audioFile.createdAt))
                    Text("·")
                    Text(formatDuration(audioFile.duration))
                }
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)

                if let summary = audioFile.summary, !summary.isEmpty {
                    Text(summary)
                        .font(MemoraTypography.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if audioFile.isSummarized {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(MemoraColor.accentBlue)
            } else if audioFile.isTranscribed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(MemoraColor.accentGreen)
            }
        }
        .padding(.vertical, MemoraSpacing.xs)
        .contextMenu {
            Button { onRename?() } label: {
                Label("名前を変更", systemImage: "pencil")
            }
            Button { } label: {
                Label("Projectに追加", systemImage: "folder.badge.plus")
            }
            ShareLink(item: audioFile.title) {
                Label("共有", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button(role: .destructive) { onDelete?() } label: {
                Label("削除", systemImage: "trash")
            }
        }
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
}
