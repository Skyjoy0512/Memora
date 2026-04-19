import Foundation
import SwiftData
import Observation
import UIKit

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
    var memoDraft = ""
    var memoUpdatedAt: Date?
    var memoHasUnsavedChanges = false
    var photoAttachments: [PhotoAttachment] = []
    var isImportingPhotos = false

    // MARK: - Title Editing
    var isEditingTitle = false
    var titleDraft = ""

    // MARK: - Transcript Editing
    var isEditingTranscript = false
    var transcriptDraft = ""

    // MARK: - Alerts
    var errorMessage: String?
    var showErrorAlert = false
    var recoveryAction: String?
    var successMessage: String?
    var showSuccessAlert = false

    // MARK: - Navigation
    var showShareSheet = false
    var showGenerationFlow = false
    var showDeleteAlert = false

    // MARK: - Dependencies
    let audioFile: AudioFile
    private let modelContext: ModelContext
    @ObservationIgnored
    private let pipelineCoordinator: PipelineCoordinator
    @ObservationIgnored
    private let knowledgeIndexingService: KnowledgeIndexingService
    @ObservationIgnored
    private let ocrService = OCRService()
    @ObservationIgnored
    private let audioPlayer = AudioPlayer()
    @ObservationIgnored
    private let speakerProfileStore = SpeakerProfileStore.shared

    // Settings (passed from View's @AppStorage)
    private var currentProvider: AIProvider
    private var currentTranscriptionMode: TranscriptionMode
    private var currentAPIKey: String

    // MARK: - STT Backend Diagnostics
    var activeBackend: String?
    var fallbackReason: String?

    // MARK: - Retry State
    @ObservationIgnored
    private(set) var lastFailedJob: ProcessingJob?

    // Timers
    private var playbackTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
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
        self.knowledgeIndexingService = KnowledgeIndexingService(modelContext: modelContext)
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
        loadSavedMemo()
        loadPhotoAttachments()
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

    func seekToTime(_ time: TimeInterval) {
        seek(to: time)
        if !isPlaying, let url = audioURL {
            do {
                try audioPlayer.play(url: url)
                isPlaying = true
                startPlaybackTimer()
            } catch {
                errorMessage = "再生に失敗しました: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    // MARK: - Transcription

    func startTranscription() {
        DebugLogger.shared.addLog("FileDetailVM", "startTranscription 開始 — audioURL: \(audioURL?.path ?? "nil")", level: .info)

        guard let url = audioURL else {
            errorMessage = "音声URLがありません"
            showErrorAlert = true
            return
        }

        isTranscribing = true
        transcriptionProgress = 0
        activeBackend = nil
        fallbackReason = nil
        startTranscriptionProgressTracking()
        pipelineObservationTask?.cancel()
        DebugLogger.shared.addLog("FileDetailVM", "パイプラインタスク作成 — mode: \(currentTranscriptionMode.rawValue), provider: \(currentProvider.rawValue)", level: .info)
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
        let memo = existingMeetingMemo()
        let transcripts = savedTranscripts()
        let filePathsToDelete = photoAttachments.flatMap { [$0.localPath, $0.thumbnailPath] }

        do {
            for transcript in transcripts {
                try knowledgeIndexingService.removeChunks(sourceType: .transcript, sourceID: transcript.id, autosave: false)
                modelContext.delete(transcript)
            }

            if let memo {
                try knowledgeIndexingService.removeChunks(sourceType: .memo, sourceID: memo.id, autosave: false)
                modelContext.delete(memo)
            }

            for attachment in photoAttachments {
                try knowledgeIndexingService.removeChunks(sourceType: .photoOCR, sourceID: attachment.id, autosave: false)
                modelContext.delete(attachment)
            }

            try knowledgeIndexingService.removeChunks(sourceType: .summary, sourceID: audioFile.id, autosave: false)
            try knowledgeIndexingService.removeChunks(sourceType: .referenceTranscript, sourceID: audioFile.id, autosave: false)
            modelContext.delete(audioFile)
            try modelContext.save()
            for path in filePathsToDelete {
                removeFileIfNeeded(at: path)
            }
        } catch {
            errorMessage = "ファイルの削除に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    // MARK: - Format Helpers

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f
    }()

    func formatDate(_ date: Date) -> String {
        Self.fileDateFormatter.string(from: date)
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
        persistPendingMemoIfNeeded()
        // pipelineObservationTask はキャンセルしない。
        // タブ切替・アプリ切替で文字起こしが継続するようにする。
        // 進捗は isTranscribing フラグで保持され、画面に戻った時に反映される。
        stopPlayback()
        stopProgressTracking()
    }

    // MARK: - AI Task Decomposition

    func decomposeTodo(_ item: TodoItem) {
        guard !currentAPIKey.isEmpty else { return }

        let context = transcriptResult?.text ?? ""

        Task { @MainActor [weak self] in
            guard let self else { return }
            let planner = TaskPlannerService()
            do {
                try await planner.configure(apiKey: self.currentAPIKey, provider: self.currentProvider)
                let subtasks = try await planner.decomposeTask(
                    taskTitle: item.title,
                    taskNotes: item.notes,
                    context: context
                )
                self.saveSubtasks(subtasks, parentID: item.id)
            } catch {
                DebugLogger.shared.addLog("TaskPlanner", "分解スキップ: \(error.localizedDescription)", level: .warning)
            }
        }
    }

    private func saveSubtasks(_ subtasks: [PlannedSubtask], parentID: UUID) {
        for sub in subtasks {
            let child = TodoItem(
                title: sub.title,
                notes: sub.citation,
                parentID: parentID
            )
            modelContext.insert(child)
        }
        try? modelContext.save()
    }

    // MARK: - Title Editing

    func beginEditTitle() {
        titleDraft = audioFile.title
        isEditingTitle = true
    }

    func saveTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { isEditingTitle = false; return }
        audioFile.title = trimmed
        try? modelContext.save()
        isEditingTitle = false
    }

    func cancelEditTitle() {
        isEditingTitle = false
    }

    // MARK: - Transcript Editing

    func beginEditTranscript() {
        transcriptDraft = transcriptResult?.text ?? ""
        isEditingTranscript = true
    }

    func saveTranscriptEdit() {
        let trimmed = transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { isEditingTranscript = false; return }

        let targetID = audioFile.id
        var descriptor = FetchDescriptor<Transcript>(
            predicate: #Predicate { $0.audioFileID == targetID }
        )
        descriptor.fetchLimit = 1
        if let transcript = try? modelContext.fetch(descriptor).first {
            transcript.text = trimmed
            try? modelContext.save()
        }

        // UI に即時反映
        if let result = transcriptResult {
            transcriptResult = TranscriptResult(
                text: trimmed,
                segments: result.segments,
                duration: result.duration
            )
        }
        isEditingTranscript = false
    }

    func cancelEditTranscript() {
        isEditingTranscript = false
    }

    // MARK: - Memo

    func updateMemoDraft(_ text: String) {
        memoDraft = text
        memoHasUnsavedChanges = text != storedMemoMarkdown()
    }

    func saveMemo(showFeedback: Bool = true) {
        let markdown = memoDraft
        let plainTextCache = plainText(from: markdown)
        let memo = existingMeetingMemo() ?? MeetingMemo(audioFileID: audioFile.id)

        memo.update(markdown: markdown, plainTextCache: plainTextCache)

        if existingMeetingMemo() == nil {
            modelContext.insert(memo)
        }

        do {
            try modelContext.save()
            memoUpdatedAt = memo.updatedAt
            memoHasUnsavedChanges = false
        } catch {
            errorMessage = "メモの保存に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }

        do {
            try knowledgeIndexingService.rebuildIndex(for: audioFile)
        } catch {
            errorMessage = "メモは保存しましたが、検索インデックス更新に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }

        if showFeedback {
            successMessage = "メモを保存しました"
            showSuccessAlert = true
        }
    }

    func persistPendingMemoIfNeeded() {
        guard memoHasUnsavedChanges else { return }
        saveMemo(showFeedback: false)
    }

    // MARK: - Photos

    func importPhoto(from data: Data) async {
        isImportingPhotos = true
        defer { isImportingPhotos = false }

        do {
            let attachment = try savePhotoAttachment(from: data)
            photoAttachments.insert(attachment, at: 0)
            normalizePhotoAttachmentOrder()
            let imageURL = URL(fileURLWithPath: attachment.localPath)
            let extractedText = await ocrService.extractText(from: imageURL)
            attachment.updateOCRText(extractedText)
            try modelContext.save()
        } catch {
            errorMessage = "写真の追加に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }

        do {
            try knowledgeIndexingService.rebuildIndex(for: audioFile)
        } catch {
            errorMessage = "写真は追加しましたが、検索インデックス更新に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    func updatePhotoCaption(_ attachment: PhotoAttachment, caption: String?) {
        attachment.updateCaption(normalizedOptionalString(caption))

        do {
            try modelContext.save()
        } catch {
            errorMessage = "キャプションの保存に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }

        do {
            try knowledgeIndexingService.rebuildIndex(for: audioFile)
        } catch {
            errorMessage = "キャプションは保存しましたが、検索インデックス更新に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    func deletePhotoAttachment(_ attachment: PhotoAttachment) {
        do {
            try knowledgeIndexingService.removeChunks(sourceType: .photoOCR, sourceID: attachment.id, autosave: false)
            modelContext.delete(attachment)
            photoAttachments.removeAll { $0.id == attachment.id }
            normalizePhotoAttachmentOrder()
            try modelContext.save()
            removeFileIfNeeded(at: attachment.localPath)
            removeFileIfNeeded(at: attachment.thumbnailPath)
        } catch {
            errorMessage = "写真の削除に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    func canMovePhotoAttachment(_ attachment: PhotoAttachment, towardLeading: Bool) -> Bool {
        guard let index = photoAttachments.firstIndex(where: { $0.id == attachment.id }) else {
            return false
        }
        return towardLeading ? index > 0 : index < photoAttachments.count - 1
    }

    func movePhotoAttachment(_ attachment: PhotoAttachment, towardLeading: Bool) {
        guard let index = photoAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }

        let targetIndex = towardLeading ? index - 1 : index + 1
        guard photoAttachments.indices.contains(targetIndex) else { return }

        photoAttachments.swapAt(index, targetIndex)
        normalizePhotoAttachmentOrder()

        do {
            try modelContext.save()
        } catch {
            errorMessage = "写真の並び替えに失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
            loadPhotoAttachments()
        }
    }

    // MARK: - Private Helpers

    private func startPlaybackTimer() {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.playbackPosition = self.audioPlayer.currentTime
                self.isPlaying = self.audioPlayer.isPlaying

                if !self.audioPlayer.isPlaying {
                    self.playbackPosition = 0
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func startTranscriptionProgressTracking() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.transcriptionProgress = self.pipelineCoordinator.currentTranscriptionProgress
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func startSummarizationProgressTracking() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.summarizationProgress = self.pipelineCoordinator.currentSummarizationProgress
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopProgressTracking() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func loadSavedMemo() {
        let memo = existingMeetingMemo()
        memoDraft = memo?.markdown ?? ""
        memoUpdatedAt = memo?.updatedAt
        memoHasUnsavedChanges = false
    }

    private func loadPhotoAttachments() {
        let ownerID = audioFile.id
        let ownerTypeRaw = "audioFile"
        var descriptor = FetchDescriptor<PhotoAttachment>(
            predicate: #Predicate {
                $0.ownerTypeRaw == ownerTypeRaw &&
                $0.ownerID == ownerID
            },
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        descriptor.fetchLimit = 100
        photoAttachments = (try? modelContext.fetch(descriptor)) ?? []
        normalizePhotoAttachmentOrder(autosave: false)
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
            DebugLogger.shared.addLog("FileDetailVM", "文字起こし完了 — 保存処理へ", level: .info)
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
            updateBackendDiagnostics()
            loadSavedTranscript()
            pipelineObservationTask = nil
        case .failed(_, let error):
            DebugLogger.shared.addLog("FileDetailVM", "文字起こしエラー: \(error.localizedDescription)", level: .error)
            stopProgressTracking()
            updateBackendDiagnostics()
            recordFailedJob(jobType: "transcription")
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
            extractMemoryCandidates()
        case .failed(_, let error):
            stopProgressTracking()
            isSummarizing = false
            recordFailedJob(jobType: "summary")
            errorMessage = "要約エラー: \(error.localizedDescription)"
            showErrorAlert = true
            pipelineObservationTask = nil
        case .stepStarted,
             .stepCompleted,
             .chunkProgress:
            break
        }
    }

    // MARK: - Retry

    func retryLastFailedJob() {
        guard let job = lastFailedJob, job.canRetry else { return }
        job.retryCount += 1
        try? modelContext.save()
        lastFailedJob = nil

        switch job.jobType {
        case "transcription":
            startTranscription()
        case "summary":
            startSummarization()
        default:
            break
        }
    }

    private func recordFailedJob(jobType: String) {
        let targetID = audioFile.id
        var descriptor = FetchDescriptor<ProcessingJob>(
            predicate: #Predicate { $0.audioFileID == targetID && $0.status == "failed" }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = 1
        lastFailedJob = try? modelContext.fetch(descriptor).first
    }

    private func updateBackendDiagnostics() {
        if let lastDiag = STTDiagnosticsLog.shared.lastEntry {
            activeBackend = lastDiag.backend.rawValue
            fallbackReason = lastDiag.fallbackReason
        }
    }

    private func userFacingTranscriptionErrorMessage(for error: Error) -> String {
        // 診断ログから失敗分類を取得
        let category = STTFailureCategory.classifyLastFailure()
        recoveryAction = category?.recoveryAction

        if let timeoutError = error as? OnDeviceTranscriptionTimeoutError {
            return timeoutError.localizedDescription
        }

        if case let CoreError.transcriptionError(transcriptionError) = error,
           case let .transcriptionFailed(message) = transcriptionError,
           message == OnDeviceTranscriptionTimeoutError.message {
            return message
        }

        // 分類されたカテゴリがあればそちらのタイトルを使う
        if let category, category != .other {
            return category.localizedTitle
        }

        return "文字起こしエラー: \(error.localizedDescription)"
    }

    private func existingMeetingMemo() -> MeetingMemo? {
        let targetID = audioFile.id
        var descriptor = FetchDescriptor<MeetingMemo>(
            predicate: #Predicate { $0.audioFileID == targetID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func savedTranscripts() -> [Transcript] {
        let targetID = audioFile.id
        var descriptor = FetchDescriptor<Transcript>(
            predicate: #Predicate { $0.audioFileID == targetID }
        )
        descriptor.fetchLimit = 20
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func storedMemoMarkdown() -> String {
        existingMeetingMemo()?.markdown ?? ""
    }

    private func plainText(from markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"(?m)^\s{0,3}#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*\*|__|`|>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func savePhotoAttachment(from data: Data) throws -> PhotoAttachment {
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let directory = try photoStorageDirectory()
        let identifier = UUID().uuidString
        let imageURL = directory.appendingPathComponent("\(identifier).jpg")
        let thumbnailURL = directory.appendingPathComponent("\(identifier)_thumb.jpg")

        guard let imageData = normalizedJPEGData(from: image, compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try imageData.write(to: imageURL, options: .atomic)

        let thumbnailData = thumbnailJPEGData(from: image)
        if let thumbnailData {
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
        }

        let attachment = PhotoAttachment(
            ownerType: .audioFile,
            ownerID: audioFile.id,
            sortOrder: photoAttachments.count,
            localPath: imageURL.path,
            thumbnailPath: thumbnailData == nil ? nil : thumbnailURL.path
        )
        modelContext.insert(attachment)
        return attachment
    }

    private func photoStorageDirectory() throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsDirectory
            .appendingPathComponent("MemoraPhotos", isDirectory: true)
            .appendingPathComponent(audioFile.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    private func normalizedJPEGData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        downsampledJPEGData(from: image, maxDimension: 2048, quality: compressionQuality)
    }

    private func thumbnailJPEGData(from image: UIImage, maxDimension: CGFloat = 320) -> Data? {
        downsampledJPEGData(from: image, maxDimension: maxDimension, quality: 0.72)
    }

    private func downsampledJPEGData(from image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > 0 else { return nil }

        let scale = min(1, maxDimension / longestEdge)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    private func removeFileIfNeeded(at path: String?) {
        guard let path, FileManager.default.fileExists(atPath: path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizePhotoAttachmentOrder(autosave: Bool = true) {
        for (index, attachment) in photoAttachments.enumerated() {
            if attachment.sortOrder != index {
                attachment.updateSortOrder(index)
            }
        }

        guard autosave else { return }
        try? modelContext.save()
    }

    // MARK: - Memory Extraction

    private func extractMemoryCandidates() {
        let privacyMode = UserDefaults.standard.string(forKey: "memoryPrivacyMode") ?? "standard"
        guard privacyMode != "off" else { return }
        guard !currentAPIKey.isEmpty else { return }

        let transcriptText = transcriptResult?.text ?? ""
        let summaryText = summaryResult?.summary

        guard !transcriptText.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = MemoryExtractionService()
            do {
                try await service.configure(apiKey: self.currentAPIKey, provider: self.currentProvider)
                let candidates = try await service.extractCandidates(
                    transcript: transcriptText,
                    summary: summaryText
                )
                self.saveMemoryCandidates(candidates)
            } catch {
                DebugLogger.shared.addLog("Memory", "記憶抽出スキップ: \(error.localizedDescription)", level: .warning)
            }
        }
    }

    private func saveMemoryCandidates(_ candidates: [MemoryCandidateDraft]) {
        guard !candidates.isEmpty else { return }

        let profile = ensureMemoryProfile()
        let existingKeys = fetchExistingMemoryFactKeys(profileID: profile.id)

        for candidate in candidates {
            guard !existingKeys.contains(candidate.key.lowercased()) else { continue }

            let fact = MemoryFact(
                profileID: profile.id,
                key: candidate.key,
                value: candidate.value,
                source: candidate.source,
                confidence: candidate.confidence
            )
            modelContext.insert(fact)
        }

        try? modelContext.save()
    }

    private func ensureMemoryProfile() -> MemoryProfile {
        let descriptor = FetchDescriptor<MemoryProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let profile = MemoryProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    private func fetchExistingMemoryFactKeys(profileID: UUID) -> Set<String> {
        let descriptor = FetchDescriptor<MemoryFact>(
            predicate: #Predicate { $0.profileID == profileID }
        )
        let facts = (try? modelContext.fetch(descriptor)) ?? []
        return Set(facts.map { $0.key.lowercased() })
    }
}
