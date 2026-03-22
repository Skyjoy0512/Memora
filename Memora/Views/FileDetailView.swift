import SwiftUI
import SwiftData

struct FileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let audioFile: AudioFile
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var transcriptionEngine = TranscriptionEngine()
    @StateObject private var summarizationEngine = SummarizationEngine()
    @State private var audioURL: URL?
    @State private var isPlaying = false
    @State private var playbackPosition: TimeInterval = 0
    @State private var audioDuration: TimeInterval = 0
    @State private var showDeleteAlert = false
    @State private var showTranscriptView = false
    @State private var showSummaryView = false
    @State private var showShareSheet = false
    @State private var transcriptResult: TranscriptResult?
    @State private var summaryResult: SummaryResult?

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    var currentAPIKey: String {
        switch currentProvider {
        case .openai:
            return apiKeyOpenAI
        case .gemini:
            return apiKeyGemini
        case .deepseek:
            return apiKeyDeepSeek
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 21) {
                Spacer()
                    .frame(height: 21)

                // 音声波形イメージ
                Image(systemName: "waveform")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.gray)

                // タイトル
                Text(audioFile.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // メタデータ
                HStack(spacing: 21) {
                    Label(formatDate(audioFile.createdAt), systemImage: "calendar")
                    Label(formatDuration(audioFile.duration), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal)

                // プレイヤーコントロール
                VStack(spacing: 21) {
                    // プログレスバー
                    VStack(spacing: 5) {
                        Slider(
                            value: $playbackPosition,
                            in: 0...max(audioDuration, 1),
                            onEditingChanged: { editing in
                                if !editing && audioDuration > 0 {
                                    audioPlayer.seek(to: playbackPosition)
                                }
                            }
                        )
                        .accentColor(.gray)

                        HStack {
                            Text(formatTime(playbackPosition))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatTime(audioDuration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // 再生ボタン
                    Button(action: togglePlayback) {
                        ZStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)

                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.vertical, 21)

                Divider()
                    .padding(.horizontal)

                // アクションボタン
                VStack(spacing: 12) {
                    if transcriptionEngine.isTranscribing {
                        // 文字起こし中
                        VStack(spacing: 12) {
                            ProgressView(value: transcriptionEngine.progress)
                                .tint(.gray)
                            Text("文字起こし中... \(Int(transcriptionEngine.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else if let errorMessage = transcriptionEngine.errorMessage {
                        // エラー表示とリトライ
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .multilineTextAlignment(.leading)
                            .padding()

                            if transcriptionEngine.isRetryable {
                                Button(action: retryTranscription) {
                                    Label("リトライ", systemImage: "arrow.clockwise")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                                .foregroundStyle(.white)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    } else if let result = transcriptResult {
                        // 文字起こし完了 - 結果表示ボタン
                        Button(action: { showTranscriptView = true }) {
                            Label("文字起こし結果を表示", systemImage: "text.alignleft")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .foregroundStyle(.primary)
                    } else if audioFile.isTranscribed {
                        // 既に文字起こし済み
                        Button(action: { showTranscriptView = true }) {
                            Label("文字起こし結果を表示", systemImage: "text.alignleft")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        // 文字起こし開始ボタン
                        Button(action: startTranscription) {
                            Label("文字起こし", systemImage: "text.alignleft")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .foregroundStyle(.primary)
                    }

                    if summarizationEngine.isSummarizing {
                        // 要約中
                        VStack(spacing: 13) {
                            ProgressView(value: summarizationEngine.progress)
                                .tint(.gray)
                            Text("要約中... \(Int(summarizationEngine.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(13)
                    } else if let result = summaryResult {
                        // 要約完了 - 結果表示ボタン
                        Button(action: { showSummaryView = true }) {
                            Label("要約結果を表示", systemImage: "text.quote")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(13)
                        }
                        .foregroundStyle(.primary)
                    } else if transcriptResult != nil || audioFile.isTranscribed {
                        // 要約開始ボタン
                        Button(action: startSummarization) {
                            Label("要約", systemImage: "text.quote")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(13)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        // 文字起こし前は要約不可
                        Button(action: {}) {
                            Label("要約", systemImage: "text.quote")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(13)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    if audioPlayer.isPlaying {
                        audioPlayer.stop()
                    }
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(audioURL == nil && transcriptResult == nil)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onAppear {
            setupAudioPlayer()
        }
        .task {
            await setupEngines()
        }
        .onDisappear {
            audioPlayer.stop()
        }
        .navigationDestination(isPresented: $showTranscriptView) {
            if let result = transcriptResult {
                TranscriptView(result: result)
            } else {
                Text("文字起こしデータがありません")
            }
        }
        .navigationDestination(isPresented: $showSummaryView) {
            if let result = summaryResult {
                SummaryView(result: result)
            } else {
                Text("要約データがありません")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                shareText: transcriptResult?.text,
                shareURL: audioURL
            )
        }
        .alert("ファイルを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                modelContext.delete(audioFile)
                dismiss()
            }
        } message: {
            Text("この録音ファイルを削除しますか？")
        }
    }

    private func setupAudioPlayer() {
        let urlString = audioFile.audioURL

        guard !urlString.isEmpty else {
            print("音声ファイルのURLが空です")
            return
        }

        // URL がファイルパス形式の場合、file:// を追加
        if urlString.hasPrefix("/") {
            audioURL = URL(fileURLWithPath: urlString)
        } else if urlString.hasPrefix("file://") {
            audioURL = URL(string: urlString)
        } else {
            audioURL = URL(fileURLWithPath: urlString)
        }

        audioDuration = audioFile.duration
        playbackPosition = 0
    }

    private func setupEngines() async {
        if !currentAPIKey.isEmpty || currentTranscriptionMode == .local {
            do {
                try await transcriptionEngine.configure(
                    apiKey: currentAPIKey,
                    provider: currentProvider,
                    transcriptionMode: currentTranscriptionMode
                )
                try await summarizationEngine.configure(apiKey: currentAPIKey, provider: currentProvider)
            } catch {
                print("エンジン設定エラー: \(error)")
            }
        }
    }

    private func togglePlayback() {
        guard let url = audioURL else {
            print("音声URLがありません")
            return
        }

        if audioPlayer.isPlaying {
            audioPlayer.pause()
            isPlaying = false
        } else {
            do {
                try audioPlayer.play(url: url)
                isPlaying = true
                audioDuration = audioPlayer.duration
                startPlaybackTimer()
            } catch {
                print("再生エラー: \(error)")
            }
        }
    }

    private func startTranscription() {
        guard let url = audioURL else {
            print("音声URLがありません")
            return
        }

        Task {
            do {
                let result = try await transcriptionEngine.transcribe(audioURL: url)
                await MainActor.run {
                    transcriptResult = result
                    audioFile.isTranscribed = true

                    // Transcript を保存
                    let transcript = Transcript(audioFileID: audioFile.id, text: result.text)
                    modelContext.insert(transcript)
                }
            } catch {
                print("文字起こしエラー: \(error)")
            }
        }
    }

    private func retryTranscription() {
        Task {
            do {
                let result = try await transcriptionEngine.retryTranscription()
                await MainActor.run {
                    transcriptResult = result
                    audioFile.isTranscribed = true

                    // Transcript を保存
                    let transcript = Transcript(audioFileID: audioFile.id, text: result.text)
                    modelContext.insert(transcript)
                }
            } catch {
                print("リトライエラー: \(error)")
            }
        }
    }

    private func startSummarization() {
        let transcriptText: String
        if let result = transcriptResult {
            transcriptText = result.text
        } else {
            // SwiftData から既存の文字起こしを取得
            let descriptor = FetchDescriptor<Transcript>()
            let transcripts = try? modelContext.fetch(descriptor)
            if let transcript = transcripts?.first(where: { $0.audioFileID == audioFile.id }) {
                transcriptText = transcript.text
            } else {
                transcriptText = ""
            }
        }

        guard !transcriptText.isEmpty else {
            print("文字起こしデータがありません")
            return
        }

        Task {
            do {
                let result = try await summarizationEngine.summarize(transcript: transcriptText)
                await MainActor.run {
                    summaryResult = result
                }
            } catch {
                print("要約エラー: \(error)")
            }
        }
    }

    private func startPlaybackTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            playbackPosition = audioPlayer.currentTime
            isPlaying = audioPlayer.isPlaying

            if !audioPlayer.isPlaying {
                timer.invalidate()
                playbackPosition = 0
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AudioFile.self, configurations: config)

    let audioFile = AudioFile(title: "テスト録音", audioURL: "")
    audioFile.duration = 120

    container.mainContext.insert(audioFile)

    return NavigationStack {
        FileDetailView(audioFile: audioFile)
    }
    .modelContainer(container)
}
