import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AudioFile.createdAt, order: .reverse) private var audioFiles: [AudioFile]
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?

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
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.large)
                } else {
                    // ファイル一覧
                    VStack(spacing: 0) {
                        List {
                            ForEach(audioFiles) { file in
                                AudioFileRow(audioFile: file)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAudioFile = file
                                    }
                            }
                            .onDelete(perform: deleteAudioFiles)
                        }
                    }
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.large)
                }
            }
            .navigationDestination(isPresented: $showRecordingView) {
                RecordingView()
            }
            .navigationDestination(item: $selectedAudioFile) { file in
                FileDetailView(audioFile: file)
            }
        }
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(audioFiles[index])
        }
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
