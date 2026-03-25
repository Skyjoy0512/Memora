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
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var successMessage: String?
    @State private var showSuccessAlert = false

    // Webhook
    @Query private var webhookSettingsList: [WebhookSettings]
    private var webhookSettings: WebhookSettings? { webhookSettingsList.first }
    private let webhookService = WebhookService()
    private let speakerProfileStore = SpeakerProfileStore.shared

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
                VStack(spacing: 13) {
                    if transcriptionEngine.isTranscribing {
                        // 文字起こし中
                        VStack(spacing: 13) {
                            ProgressView(value: transcriptionEngine.progress)
                                .tint(.gray)
                            Text("文字起こし中... \(Int(transcriptionEngine.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(13)
                    } else if let result = transcriptResult {
                        // 文字起こし完了 - 結果表示ボタン
                        Button(action: { showTranscriptView = true }) {
                            Label("文字起こし結果を表示", systemImage: "text.alignleft")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(13)
                        }
                        .foregroundStyle(.primary)
                    } else if audioFile.isTranscribed {
                        // 既に文字起こし済み
                        Button(action: { showTranscriptView = true }) {
                            Label("文字起こし結果を表示", systemImage: "text.alignleft")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(13)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        // 文字起こし開始ボタン
                        Button(action: startTranscription) {
                            Label("文字起こし", systemImage: "text.alignleft")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(13)
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
                    } else if audioFile.isSummarized {
                        // 既に要約済み - 結果表示ボタン
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

                    if audioURL != nil {
                        Button(action: registerPrimarySpeakerSample) {
                            VStack(spacing: 6) {
                                Label("この録音を自分の声サンプルに登録", systemImage: "person.crop.circle.badge.plus")
                                    .frame(maxWidth: .infinity)
                                Text("1人だけが話している録音を使うと精度が安定します")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(13)
                        }
                        .foregroundStyle(.primary)
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
            loadSavedTranscript()
            loadSavedSummary()
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
                shareURL: audioURL,
                audioFile: audioFile
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
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                errorMessage = nil
                showErrorAlert = false
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .alert("完了", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                successMessage = nil
                showSuccessAlert = false
            }
        } message: {
            if let successMessage = successMessage {
                Text(successMessage)
            }
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
        // 文字起こしエンジンを設定
        do {
            try await transcriptionEngine.configure(
                apiKey: currentAPIKey,
                provider: currentProvider,
                transcriptionMode: currentTranscriptionMode
            )
        } catch {
            await MainActor.run {
                errorMessage = "文字起こしエンジン設定エラー: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }

        // 要約エンジンは API キーが必要
        if !currentAPIKey.isEmpty {
            do {
                try await summarizationEngine.configure(apiKey: currentAPIKey, provider: currentProvider)
            } catch {
                await MainActor.run {
                    errorMessage = "要約エンジン設定エラー: \(error.localizedDescription)"
                    showErrorAlert = true
                }
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
            errorMessage = "音声URLがありません"
            showErrorAlert = true
            return
        }

        Task {
            do {
                // トランスクリプションエンジンを設定
                try await transcriptionEngine.configure(
                    apiKey: currentAPIKey,
                    provider: currentProvider,
                    transcriptionMode: currentTranscriptionMode
                )

                let result = try await transcriptionEngine.transcribe(audioURL: url)
                await MainActor.run {
                    // Transcript を保存
                    let transcript = Transcript(audioFileID: audioFile.id, text: result.text)
                    modelContext.insert(transcript)
                    try? modelContext.save()

                    // スピーカーセグメントを保存
                    print("保存するセグメント数: \(result.segments.count)")
                    for (index, segment) in result.segments.enumerated() {
                        transcript.addSpeakerSegment(
                            speakerLabel: segment.speakerLabel,
                            startTime: segment.startTime,
                            endTime: segment.endTime,
                            text: segment.text
                        )
                        print("セグメント \(index): \(segment.speakerLabel) - \(segment.text)")
                    }
                    print("保存後の speakerLabels 配列サイズ: \(transcript.speakerLabels.count)")
                    try? modelContext.save()

                    // audioFile のフラグを更新
                    audioFile.isTranscribed = true
                    try? modelContext.save()

                    transcriptResult = result
                }

                // Webhook 送信
                await sendWebhook(event: .transcriptionCompleted, data: [
                    "audioFileId": audioFile.id.uuidString,
                    "title": audioFile.title,
                    "duration": audioFile.duration,
                    "transcript": result.text,
                    "segments": result.segments.count
                ])
            } catch {
                await MainActor.run {
                    errorMessage = "文字起こしエラー: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }

    private func startSummarization() {
        // API キーが設定されているか確認
        guard !currentAPIKey.isEmpty else {
            errorMessage = "API キーが設定されていません。設定画面から API キーを入力してください。"
            showErrorAlert = true
            return
        }

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
            errorMessage = "文字起こしデータがありません"
            showErrorAlert = true
            return
        }

        Task {
            do {
                // 要約エンジンを設定（API キーが設定されている場合）
                try await summarizationEngine.configure(apiKey: currentAPIKey, provider: currentProvider)

                let result = try await summarizationEngine.summarize(transcript: transcriptText)
                await MainActor.run {
                    summaryResult = result
                    // 要約を AudioFile に保存
                    audioFile.isSummarized = true
                    audioFile.summary = result.summary
                    audioFile.keyPoints = result.keyPoints.joined(separator: "\n")
                    audioFile.actionItems = result.actionItems.joined(separator: "\n")
                    try? modelContext.save()

                    // Webhook 送信
                    Task {
                        await sendWebhook(event: .summarizationCompleted, data: [
                            "audioFileId": audioFile.id.uuidString,
                            "title": audioFile.title,
                            "summary": result.summary,
                            "keyPoints": result.keyPoints,
                            "actionItems": result.actionItems
                        ])
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "要約エラー: \(error.localizedDescription)"
                    showErrorAlert = true
                }
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

    private func registerPrimarySpeakerSample() {
        guard let url = audioURL else {
            errorMessage = "音声URLがありません"
            showErrorAlert = true
            return
        }

        Task {
            do {
                let profile = try speakerProfileStore.registerPrimaryUserProfile(audioURL: url)
                await MainActor.run {
                    successMessage = "「\(profile.displayName)」の声サンプルを登録しました。次回の話者分離から優先的にラベル付けします。"
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "声サンプル登録エラー: \(error.localizedDescription)"
                    showErrorAlert = true
                }
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

    private func sendWebhook(event: WebhookEventType, data: [String: Any]) async {
        guard let settings = webhookSettings else { return }

        do {
            try await webhookService.sendWebhook(
                eventType: event,
                data: data,
                settings: settings
            )
        } catch {
            print("Webhook 送信エラー: \(error.localizedDescription)")
        }
    }

    private func loadSavedSummary() {
        guard audioFile.isSummarized,
              let summary = audioFile.summary,
              let keyPoints = audioFile.keyPoints,
              let actionItems = audioFile.actionItems else {
            return
        }
        summaryResult = SummaryResult(
            summary: summary,
            keyPoints: keyPoints.split(separator: "\n", omittingEmptySubsequences: true).map(String.init),
            actionItems: actionItems.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        )
    }

    private func loadSavedTranscript() {
        guard audioFile.isTranscribed else { return }

        let descriptor = FetchDescriptor<Transcript>()
        guard let transcripts = try? modelContext.fetch(descriptor),
              let transcript = transcripts.first(where: { $0.audioFileID == audioFile.id }) else {
            print("Transcript が見つかりません。audioFileID: \(audioFile.id)")
            return
        }

        print("読み込んだ Transcript - speakerLabels 配列サイズ: \(transcript.speakerLabels.count)")

        // スピーカーセグメントを構築
        var segments: [SpeakerSegment] = []
        for i in 0..<transcript.speakerLabels.count {
            if i < transcript.segmentStartTimes.count &&
               i < transcript.segmentEndTimes.count &&
               i < transcript.segmentTexts.count {
                segments.append(SpeakerSegment(
                    speakerLabel: transcript.speakerLabels[i],
                    startTime: transcript.segmentStartTimes[i],
                    endTime: transcript.segmentEndTimes[i],
                    text: transcript.segmentTexts[i]
                ))
            }
        }

        print("構築したセグメント数: \(segments.count)")

        transcriptResult = TranscriptResult(
            text: transcript.text,
            segments: segments,
            duration: audioFile.duration
        )
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
