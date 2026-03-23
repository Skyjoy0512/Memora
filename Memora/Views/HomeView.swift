import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AudioFile.createdAt, order: .reverse) private var audioFiles: [AudioFile]
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?

    // 検索・フィルタリング用
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var filterTranscribed: Bool? = nil // nil=すべて, true=済み, false=未済み
    @State private var filterSummarized: Bool? = nil // nil=すべて, true=済み, false=未済み
    @State private var filterLifeLog: Bool? = nil // nil=すべて, true=ライフログのみ
    @State private var selectedTag: String? = nil // タグフィルタ
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
                    // 空の状態
                    VStack(spacing: 21) {
                        Image(systemName: "waveform")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.gray)

                        Text("Memora")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("録音ファイル一覧")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: { showRecordingView = true }) {
                            Label("録音を開始", systemImage: "mic.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color.gray)
                                .cornerRadius(13)
                        }
                        .padding()

                        Text("まだ録音ファイルがありません")
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 34)
                    }
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
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)

                        // フィルター・ソートバー
                        HStack(spacing: 8) {
                            // フィルターボタン
                            Button(action: { showFilterSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text("フィルター")
                                }
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }

                            Spacer()

                            // ソート選択
                            Picker("", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
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
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
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
        }
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredFiles[index])
        }
        try? modelContext.save()
    }
}

struct AudioFileRow: View {
    let audioFile: AudioFile

    var body: some View {
        HStack(spacing: 13) {
            // アイコン
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.gray)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(audioFile.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 5) {
                    Text(formatDate(audioFile.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(formatDuration(audioFile.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if audioFile.isTranscribed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 8)
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
