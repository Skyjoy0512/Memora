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
    private let modelContext: ModelContext
    private let pipelineCoordinator: PipelineCoordinator
    private let audioPlayer = AudioPlayer()
    private let speakerProfileStore = SpeakerProfileStore.shared

    // Settings (passed from View's @AppStorage)
    private var currentProvider: AIProvider
    private var currentTranscriptionMode: TranscriptionMode
    private var currentAPIKey: String

    // Timers
    private var playbackTimer: Timer?
    private var progressTimer: Timer?
    private var pipelineObservationTask: Task<Void, Never>?

    init(
        audioFile: AudioFile,
        modelContext: ModelContext,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode,
        apiKey: String
    ) {
        self.audioFile = audioFile
        self.modelContext = modelContext
        self.currentProvider = provider
        self.currentTranscriptionMode = transcriptionMode
        self.currentAPIKey = apiKey
        self.pipelineCoordinator = PipelineCoordinator(
            transcriptionEngine: TranscriptionEngine(),
            summarizationEngine: SummarizationEngine(),
            modelContext: modelContext
        )
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
        pipelineObservationTask?.cancel()
        pipelineObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let events = self.pipelineCoordinator.runTranscriptionPipeline(
                audioURL: url,
                audioFile: self.audioFile,
                apiKey: self.currentAPIKey,
                provider: self.currentProvider,
                transcriptionMode: self.currentTranscriptionMode
            )

            for await event in events {
                self.handleTranscriptionPipelineEvent(event)
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
            // modelContext から取得
            let transcript: Transcript?
            let targetID = audioFile.id
            var descriptor = FetchDescriptor<Transcript>(
                predicate: #Predicate { $0.audioFileID == targetID }
            )
            descriptor.fetchLimit = 1
            transcript = try? modelContext.fetch(descriptor).first
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
        pipelineObservationTask?.cancel()
        pipelineObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let events = self.pipelineCoordinator.runSummaryPipeline(
                audioFile: self.audioFile,
                transcriptText: transcriptText,
                segments: segments,
                apiKey: self.currentAPIKey,
                provider: self.currentProvider,
                config: config
            )

            for await event in events {
                self.handleSummarizationPipelineEvent(event)
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
        modelContext.delete(audioFile)
        do {
            try modelContext.save()
        } catch {
            print("[FileDetailVM] Delete error: \(error)")
        }
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
        pipelineObservationTask?.cancel()
        pipelineObservationTask = nil
        stopPlayback()
        stopProgressTracking()
    }

    // MARK: - Private Helpers

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
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
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.transcriptionProgress = self.pipelineCoordinator.currentTranscriptionProgress
            }
        }
    }

    private func startSummarizationProgressTracking() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.summarizationProgress = self.pipelineCoordinator.currentSummarizationProgress
            }
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func loadSavedTranscript() {
        guard audioFile.isTranscribed else { return }

        let transcript: Transcript?
            let targetID = audioFile.id
            var descriptor = FetchDescriptor<Transcript>(
                predicate: #Predicate { $0.audioFileID == targetID }
            )
            descriptor.fetchLimit = 1
            transcript = try? modelContext.fetch(descriptor).first

        guard let transcript else { return }

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

    private func handleTranscriptionPipelineEvent(_ event: PipelineEvent) {
        switch event {
        case .stepCompleted(.transcribing):
            stopProgressTracking()
            transcriptionProgress = max(transcriptionProgress, 0.95)
        case .stepStarted(.mergingTranscripts):
            transcriptionProgress = max(transcriptionProgress, 0.97)
        case .stepStarted(.finalizing):
            transcriptionProgress = max(transcriptionProgress, 0.99)
        case .completed:
            stopProgressTracking()
            isTranscribing = false
            transcriptionProgress = 1.0
            loadSavedTranscript()
            pipelineObservationTask = nil
        case .failed(_, let error):
            stopProgressTracking()
            isTranscribing = false
            errorMessage = userFacingTranscriptionErrorMessage(for: error)
            showErrorAlert = true
            pipelineObservationTask = nil
        case .stepStarted,
             .stepCompleted,
             .chunkProgress:
            break
        }
    }

    private func handleSummarizationPipelineEvent(_ event: PipelineEvent) {
        switch event {
        case .stepCompleted(.generatingSummary):
            stopProgressTracking()
            summarizationProgress = max(summarizationProgress, 0.9)
        case .stepStarted(.extractingMetadata):
            summarizationProgress = max(summarizationProgress, 0.94)
        case .stepStarted(.extractingTodos):
            summarizationProgress = max(summarizationProgress, 0.97)
        case .stepStarted(.finalizing):
            summarizationProgress = max(summarizationProgress, 0.99)
        case .completed:
            stopProgressTracking()
            isSummarizing = false
            summarizationProgress = 1.0
            loadSavedSummary()
            successMessage = "生成完了"
            showSuccessAlert = true
            pipelineObservationTask = nil
        case .failed(_, let error):
            stopProgressTracking()
            isSummarizing = false
            errorMessage = "要約エラー: \(error.localizedDescription)"
            showErrorAlert = true
            pipelineObservationTask = nil
        case .stepStarted,
             .stepCompleted,
             .chunkProgress:
            break
        }
    }

    private func userFacingTranscriptionErrorMessage(for error: Error) -> String {
        if let timeoutError = error as? OnDeviceTranscriptionTimeoutError {
            return timeoutError.localizedDescription
        }

        if case let CoreError.transcriptionError(transcriptionError) = error,
           case let .transcriptionFailed(message) = transcriptionError,
           message == OnDeviceTranscriptionTimeoutError.message {
            return message
        }

        return "文字起こしエラー: \(error.localizedDescription)"
    }
}
