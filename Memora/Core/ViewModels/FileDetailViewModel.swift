import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class FileDetailViewModel {

    // MARK: - Audio Playback State
    var isPlaying = false
    var playbackPosition: TimeInterval = 0
    var audioDuration: TimeInterval = 0
    var audioURL: URL?

    // MARK: - Transcription State
    var isTranscribing = false
    var transcriptionProgress = 0.0

    // MARK: - Summarization State
    var isSummarizing = false
    var summarizationProgress = 0.0

    // MARK: - Results
    var transcriptResult: TranscriptResult?
    var summaryResult: SummaryResult?

    // MARK: - Alerts
    var errorMessage: String?
    var showErrorAlert = false
    var successMessage: String?
    var showSuccessAlert = false

    // MARK: - Navigation
    var showTranscriptView = false
    var showSummaryView = false
    var showShareSheet = false
    var showGenerationFlow = false
    var showDeleteAlert = false

    // MARK: - Dependencies
    let audioFile: AudioFile
    private let repoFactory: RepositoryFactory
    private let transcriptionEngine = TranscriptionEngine()
    private let summarizationEngine = SummarizationEngine()
    private let audioPlayer = AudioPlayer()
    private let webhookService = WebhookService()
    private let speakerProfileStore = SpeakerProfileStore.shared

    // Settings (passed from View's @AppStorage)
    private var currentProvider: AIProvider
    private var currentTranscriptionMode: TranscriptionMode
    private var currentAPIKey: String

    // Timers
    private var playbackTimer: Timer?
    private var progressTimer: Timer?

    init(
        audioFile: AudioFile,
        repoFactory: RepositoryFactory,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode,
        apiKey: String
    ) {
        self.audioFile = audioFile
        self.repoFactory = repoFactory
        self.currentProvider = provider
        self.currentTranscriptionMode = transcriptionMode
        self.currentAPIKey = apiKey
    }

    // MARK: - Setup

    func setupAudioPlayer() {
        let urlString = audioFile.audioURL

        guard !urlString.isEmpty else { return }

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

    func setupEngines() async {
        do {
            try await transcriptionEngine.configure(
                apiKey: currentAPIKey,
                provider: currentProvider,
                transcriptionMode: currentTranscriptionMode
            )
        } catch {
            errorMessage = "文字起こしエンジン設定エラー: \(error.localizedDescription)"
            showErrorAlert = true
        }

        if !currentAPIKey.isEmpty {
            do {
                try await summarizationEngine.configure(
                    apiKey: currentAPIKey,
                    provider: currentProvider
                )
            } catch {
                errorMessage = "要約エンジン設定エラー: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    func loadSavedData() {
        loadSavedTranscript()
        loadSavedSummary()
    }

    // MARK: - Audio Playback

    func togglePlayback() {
        guard let url = audioURL else { return }

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

    func stopPlayback() {
        audioPlayer.stop()
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        playbackPosition = time
        if audioDuration > 0 {
            audioPlayer.seek(to: time)
        }
    }

    // MARK: - Transcription

    func startTranscription() {
        guard let url = audioURL else {
            errorMessage = "音声URLがありません"
            showErrorAlert = true
            return
        }

        isTranscribing = true
        transcriptionProgress = 0
        startTranscriptionProgressTracking()

        Task {
            do {
                try await transcriptionEngine.configure(
                    apiKey: currentAPIKey,
                    provider: currentProvider,
                    transcriptionMode: currentTranscriptionMode
                )

                let result = try await transcriptionEngine.transcribe(audioURL: url)

                stopProgressTracking()
                isTranscribing = false
                transcriptionProgress = 1.0

                // Transcript を保存
                let transcript = Transcript(audioFileID: audioFile.id, text: result.text)
                try? repoFactory.transcriptRepo.save(transcript)

                // スピーカーセグメントを保存
                for segment in result.segments {
                    transcript.addSpeakerSegment(
                        speakerLabel: segment.speakerLabel,
                        startTime: segment.startTime,
                        endTime: segment.endTime,
                        text: segment.text
                    )
                }
                try? repoFactory.transcriptRepo.save(transcript)

                // audioFile のフラグを更新
                audioFile.isTranscribed = true
                try? repoFactory.audioFileRepo.save(audioFile)

                transcriptResult = result

                // Webhook 送信
                await sendWebhook(event: .transcriptionCompleted, data: [
                    "audioFileId": audioFile.id.uuidString,
                    "title": audioFile.title,
                    "duration": audioFile.duration,
                    "transcript": result.text,
                    "segments": result.segments.count
                ])
            } catch {
                stopProgressTracking()
                isTranscribing = false
                errorMessage = "文字起こしエラー: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    // MARK: - Summarization

    func startSummarization(with config: GenerationConfig = GenerationConfig()) {
        guard !currentAPIKey.isEmpty else {
            errorMessage = "API キーが設定されていません。設定画面から API キーを入力してください。"
            showErrorAlert = true
            return
        }

        let transcriptText: String
        var segments: [SpeakerSegment] = []

        if let result = transcriptResult {
            transcriptText = result.text
            segments = result.segments
        } else {
            let transcript = try? repoFactory.transcriptRepo.fetch(audioFileId: audioFile.id)
            transcriptText = transcript?.text ?? ""
        }

        guard !transcriptText.isEmpty else {
            errorMessage = "文字起こしデータがありません"
            showErrorAlert = true
            return
        }

        isSummarizing = true
        summarizationProgress = 0
        startSummarizationProgressTracking()

        Task {
            do {
                try await summarizationEngine.configure(
                    apiKey: currentAPIKey,
                    provider: currentProvider
                )

                let result: SummaryResult
                if config.includeSpeakers && !segments.isEmpty {
                    result = try await summarizationEngine.summarizeWithSpeakers(
                        transcript: transcriptText,
                        segments: segments
                    )
                } else {
                    result = try await summarizationEngine.summarize(transcript: transcriptText)
                }

                stopProgressTracking()
                isSummarizing = false
                summarizationProgress = 1.0

                summaryResult = result
                audioFile.isSummarized = true
                audioFile.summary = result.summary
                audioFile.keyPoints = result.keyPointsText
                audioFile.actionItems = result.actionItemsText
                try? repoFactory.audioFileRepo.save(audioFile)

                // アクションアイテムからTodoItem自動生成
                if config.autoCreateTodos {
                    summarizationEngine.createTodoItems(
                        from: result,
                        sourceFileId: audioFile.id,
                        sourceFileTitle: audioFile.title,
                        todoRepo: repoFactory.todoItemRepo
                    )
                }

                // Webhook 送信
                await sendWebhook(event: .summarizationCompleted, data: [
                    "audioFileId": audioFile.id.uuidString,
                    "title": audioFile.title,
                    "summary": result.summary,
                    "keyPoints": result.keyPoints,
                    "actionItems": result.actionItems
                ])

                successMessage = "生成完了"
                showSuccessAlert = true
            } catch {
                stopProgressTracking()
                isSummarizing = false
                errorMessage = "要約エラー: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    // MARK: - Speaker Registration

    func registerPrimarySpeakerSample() {
        guard let url = audioURL else {
            errorMessage = "音声URLがありません"
            showErrorAlert = true
            return
        }

        Task {
            do {
                let profile = try speakerProfileStore.registerPrimaryUserProfile(audioURL: url)
                successMessage = "「\(profile.displayName)」の声サンプルを登録しました。次回の話者分離から優先的にラベル付けします。"
                showSuccessAlert = true
            } catch {
                errorMessage = "声サンプル登録エラー: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    // MARK: - Delete

    func deleteAudioFile() {
        try? repoFactory.audioFileRepo.delete(audioFile)
    }

    // MARK: - Format Helpers

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    func cleanup() {
        stopPlayback()
        stopProgressTracking()
    }

    // MARK: - Private Helpers

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.playbackPosition = self.audioPlayer.currentTime
                self.isPlaying = self.audioPlayer.isPlaying

                if !self.audioPlayer.isPlaying {
                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil
                    self.playbackPosition = 0
                }
            }
        }
    }

    private func startTranscriptionProgressTracking() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.transcriptionProgress = self.transcriptionEngine.progress
            }
        }
    }

    private func startSummarizationProgressTracking() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.summarizationProgress = self.summarizationEngine.progress
            }
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func loadSavedTranscript() {
        guard audioFile.isTranscribed else { return }

        guard let transcript = try? repoFactory.transcriptRepo.fetch(audioFileId: audioFile.id) else { return }

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

        transcriptResult = TranscriptResult(
            text: transcript.text,
            segments: segments,
            duration: audioFile.duration
        )
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

    private func sendWebhook(event: WebhookEventType, data: [String: Any]) async {
        guard let settings = try? repoFactory.webhookSettingsRepo.fetch() else { return }

        guard let settings else { return }

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
}
