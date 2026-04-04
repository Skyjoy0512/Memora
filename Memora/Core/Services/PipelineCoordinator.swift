import Foundation
import SwiftData

/// 文字起こし → 要約 → ToDo 抽出のパイプラインを統括するCoordinator。
/// 各ステップの進捗を AsyncStream<PipelineEvent> で通知する。
@MainActor
final class PipelineCoordinator {

    // MARK: - Types

    struct PipelineResult: Sendable {
        let transcriptResult: TranscriptResult?
        let summaryResult: SummaryResult?
        let createdTodoCount: Int
    }

    // MARK: - Dependencies

    private let transcriptionEngine: TranscriptionEngine
    private let summarizationEngine: SummarizationEngine
    private let modelContext: ModelContext
    private lazy var knowledgeIndexingService = KnowledgeIndexingService(modelContext: modelContext)

    // MARK: - Progress (read by FileDetailViewModel for UI polling)

    var currentTranscriptionProgress: Double { transcriptionEngine.progress }
    var currentSummarizationProgress: Double { summarizationEngine.progress }

    init(
        transcriptionEngine: TranscriptionEngine,
        summarizationEngine: SummarizationEngine,
        modelContext: ModelContext
    ) {
        self.transcriptionEngine = transcriptionEngine
        self.summarizationEngine = summarizationEngine
        self.modelContext = modelContext
    }

    // MARK: - Full Pipeline

    /// 文字起こし → 要約 → ToDo のフルパイプラインを実行。
    func runFullPipeline(
        audioURL: URL,
        audioFile: AudioFile,
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode,
        config: GenerationConfig
    ) -> AsyncStream<PipelineEvent> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let job = ProcessingJob(audioFileID: audioFile.id, jobType: "full")
                modelContext.insert(job)
                try? modelContext.save()

                do {
                    let transcriptResult = try await executeTranscription(
                        audioURL: audioURL,
                        audioFile: audioFile,
                        apiKey: apiKey,
                        provider: provider,
                        transcriptionMode: transcriptionMode,
                        continuation: continuation,
                        job: job
                    )

                    // --- Step 4: Summary ---
                    job.updateProgress(0.5, stage: PipelineStep.generatingSummary.rawValue)
                    continuation.yield(.stepStarted(.generatingSummary))

                    try await summarizationEngine.configure(apiKey: apiKey, provider: provider)

                    let summaryResult: SummaryResult
                    if config.includeSpeakers && !transcriptResult.segments.isEmpty {
                        summaryResult = try await summarizationEngine.summarizeWithSpeakers(
                            transcript: transcriptResult.text,
                            segments: transcriptResult.segments
                        )
                    } else {
                        summaryResult = try await summarizationEngine.summarize(
                            transcript: transcriptResult.text
                        )
                    }

                    continuation.yield(.stepCompleted(.generatingSummary))

                    // --- Step 5: Save Summary ---
                    job.updateProgress(0.7, stage: PipelineStep.extractingMetadata.rawValue)
                    continuation.yield(.stepStarted(.extractingMetadata))

                    audioFile.isSummarized = true
                    audioFile.summary = summaryResult.summary
                    audioFile.keyPoints = summaryResult.keyPointsText
                    audioFile.actionItems = summaryResult.actionItemsText
                    saveAudioFile(audioFile)
                    reindexKnowledge(for: audioFile)

                    continuation.yield(.stepCompleted(.extractingMetadata))

                    // --- Step 6: Extract Todos (AI Task Planner) ---
                    if config.autoCreateTodos {
                        job.updateProgress(0.8, stage: PipelineStep.extractingTodos.rawValue)
                        continuation.yield(.stepStarted(.extractingTodos))

                        let planner = TaskPlannerService()
                        do {
                            try await planner.configure(apiKey: apiKey, provider: provider)
                            let plannedTasks = try await planner.planTasks(
                                transcript: transcriptResult.text,
                                summary: summaryResult.summary
                            )
                            savePlannedTasks(plannedTasks, sourceFileId: audioFile.id, sourceFileTitle: audioFile.title)
                        } catch {
                            DebugLogger.shared.addLog("Pipeline", "TaskPlanner フォールバック: \(error.localizedDescription)", level: .warning)
                            summarizationEngine.createTodoItems(
                                from: summaryResult,
                                sourceFileId: audioFile.id,
                                sourceFileTitle: audioFile.title,
                                modelContext: modelContext
                            )
                        }

                        continuation.yield(.stepCompleted(.extractingTodos))
                    }

                    // --- Step 7: Finalize ---
                    job.updateProgress(0.95, stage: PipelineStep.finalizing.rawValue)
                    continuation.yield(.stepStarted(.finalizing))

                    // Webhook 送信
                    await sendWebhooks(
                        audioFile: audioFile,
                        transcriptResult: transcriptResult,
                        summaryResult: summaryResult
                    )

                    continuation.yield(.stepCompleted(.finalizing))

                    job.markCompleted()
                    try? modelContext.save()
                    continuation.yield(.completed)

                } catch is CancellationError {
                    job.markFailed("Cancelled", stage: job.stage)
                    try? modelContext.save()
                } catch {
                    job.markFailed(error.localizedDescription, stage: job.stage)
                    try? modelContext.save()
                    continuation.yield(.failed(step: .transcribing, error: CoreError.transcriptionError(.transcriptionFailed(error.localizedDescription))))
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { @MainActor in
                    await self.transcriptionEngine.cancelActiveTranscription()
                }
            }
        }
    }

    // MARK: - Transcription-Only Pipeline

    /// 文字起こし + 保存 + Webhook までを実行。
    func runTranscriptionPipeline(
        audioURL: URL,
        audioFile: AudioFile,
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode
    ) -> AsyncStream<PipelineEvent> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let job = ProcessingJob(audioFileID: audioFile.id, jobType: "transcription")
                modelContext.insert(job)
                try? modelContext.save()

                do {
                    let transcriptResult = try await executeTranscription(
                        audioURL: audioURL,
                        audioFile: audioFile,
                        apiKey: apiKey,
                        provider: provider,
                        transcriptionMode: transcriptionMode,
                        continuation: continuation,
                        job: job
                    )

                    job.updateProgress(0.95, stage: PipelineStep.finalizing.rawValue)
                    continuation.yield(.stepStarted(.finalizing))

                    await sendWebhooks(
                        audioFile: audioFile,
                        transcriptResult: transcriptResult,
                        summaryResult: nil
                    )

                    continuation.yield(.stepCompleted(.finalizing))

                    job.markCompleted()
                    try? modelContext.save()
                    continuation.yield(.completed)
                } catch is CancellationError {
                    job.markFailed("Cancelled", stage: job.stage)
                    try? modelContext.save()
                } catch {
                    job.markFailed(error.localizedDescription, stage: job.stage)
                    try? modelContext.save()
                    continuation.yield(.failed(step: .transcribing, error: CoreError.transcriptionError(.transcriptionFailed(error.localizedDescription))))
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { @MainActor in
                    await self.transcriptionEngine.cancelActiveTranscription()
                }
            }
        }
    }

    // MARK: - Summary-Only Pipeline

    /// 文字起こし済みのファイルに対して要約 + ToDo 抽出のみ実行。
    func runSummaryPipeline(
        audioFile: AudioFile,
        transcriptText: String,
        segments: [SpeakerSegment],
        apiKey: String,
        provider: AIProvider,
        config: GenerationConfig
    ) -> AsyncStream<PipelineEvent> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let job = ProcessingJob(audioFileID: audioFile.id, jobType: "summary")
                job.markStarted(stage: PipelineStep.generatingSummary.rawValue)
                modelContext.insert(job)
                try? modelContext.save()

                do {
                    // Configure
                    try await summarizationEngine.configure(apiKey: apiKey, provider: provider)

                    // Summary
                    continuation.yield(.stepStarted(.generatingSummary))

                    let summaryResult: SummaryResult
                    if config.includeSpeakers && !segments.isEmpty {
                        summaryResult = try await summarizationEngine.summarizeWithSpeakers(
                            transcript: transcriptText,
                            segments: segments
                        )
                    } else {
                        summaryResult = try await summarizationEngine.summarize(
                            transcript: transcriptText
                        )
                    }

                    continuation.yield(.stepCompleted(.generatingSummary))

                    // Save
                    job.updateProgress(0.7, stage: PipelineStep.extractingMetadata.rawValue)
                    continuation.yield(.stepStarted(.extractingMetadata))

                    audioFile.isSummarized = true
                    audioFile.summary = summaryResult.summary
                    audioFile.keyPoints = summaryResult.keyPointsText
                    audioFile.actionItems = summaryResult.actionItemsText
                    saveAudioFile(audioFile)
                    reindexKnowledge(for: audioFile)

                    continuation.yield(.stepCompleted(.extractingMetadata))

                    // Todos
                    if config.autoCreateTodos {
                        job.updateProgress(0.85, stage: PipelineStep.extractingTodos.rawValue)
                        continuation.yield(.stepStarted(.extractingTodos))

                        summarizationEngine.createTodoItems(
                            from: summaryResult,
                            sourceFileId: audioFile.id,
                            sourceFileTitle: audioFile.title,
                            modelContext: modelContext
                        )

                        continuation.yield(.stepCompleted(.extractingTodos))
                    }

                    // Finalize
                    job.updateProgress(0.95, stage: PipelineStep.finalizing.rawValue)
                    continuation.yield(.stepStarted(.finalizing))

                    await sendWebhooks(
                        audioFile: audioFile,
                        transcriptResult: nil,
                        summaryResult: summaryResult
                    )

                    continuation.yield(.stepCompleted(.finalizing))

                    job.markCompleted()
                    try? modelContext.save()
                    continuation.yield(.completed)

                } catch is CancellationError {
                    job.markFailed("Cancelled", stage: job.stage)
                    try? modelContext.save()
                } catch {
                    job.markFailed(error.localizedDescription, stage: job.stage)
                    try? modelContext.save()
                    continuation.yield(.failed(step: .generatingSummary, error: CoreError.summaryError(.generationFailed(error.localizedDescription))))
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    private func executeTranscription(
        audioURL: URL,
        audioFile: AudioFile,
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode,
        continuation: AsyncStream<PipelineEvent>.Continuation,
        job: ProcessingJob
    ) async throws -> TranscriptResult {
        DebugLogger.shared.addLog("Pipeline", "executeTranscription 開始", level: .info)
        job.markStarted(stage: PipelineStep.loadingAudio.rawValue)
        continuation.yield(.stepStarted(.loadingAudio))

        try await transcriptionEngine.configure(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode
        )

        continuation.yield(.stepCompleted(.loadingAudio))

        job.updateProgress(0.1, stage: PipelineStep.transcribing.rawValue)
        continuation.yield(.stepStarted(.transcribing))
        DebugLogger.shared.addLog("Pipeline", "transcriptionEngine.transcribe 呼び出し", level: .info)
        let transcriptResult = try await transcriptionEngine.transcribe(audioURL: audioURL)
        DebugLogger.shared.addLog("Pipeline", "transcriptionEngine.transcribe 完了 — text length: \(transcriptResult.text.count)", level: .info)
        continuation.yield(.stepCompleted(.transcribing))

        job.updateProgress(0.6, stage: PipelineStep.mergingTranscripts.rawValue)
        continuation.yield(.stepStarted(.mergingTranscripts))

        let transcript = Transcript(audioFileID: audioFile.id, text: transcriptResult.text)
        DebugLogger.shared.addLog("Pipeline", "Transcript 保存開始", level: .info)
        saveTranscript(transcript)

        for segment in transcriptResult.segments {
            transcript.addSpeakerSegment(
                speakerLabel: segment.speakerLabel,
                startTime: segment.startTime,
                endTime: segment.endTime,
                text: segment.text
            )
        }
        try? modelContext.save()

        audioFile.isTranscribed = true
        saveAudioFile(audioFile)
        reindexKnowledge(for: audioFile)

        continuation.yield(.stepCompleted(.mergingTranscripts))
        return transcriptResult
    }

    private func saveTranscript(_ transcript: Transcript) {
        modelContext.insert(transcript)
        do {
            try modelContext.save()
        } catch {
            print("[PipelineCoordinator] Transcript save error: \(error)")
        }
    }

    private func saveAudioFile(_ audioFile: AudioFile) {
        do {
            try modelContext.save()
        } catch {
            print("[PipelineCoordinator] AudioFile save error: \(error)")
        }
    }

    private func reindexKnowledge(for audioFile: AudioFile) {
        do {
            try knowledgeIndexingService.rebuildIndex(for: audioFile)
        } catch {
            DebugLogger.shared.addLog(
                "Pipeline",
                "Knowledge index rebuild failed: \(error.localizedDescription)",
                level: .warning
            )
        }
    }

    private func savePlannedTasks(_ plannedTasks: [PlannedTask], sourceFileId: UUID, sourceFileTitle: String) {
        for planned in plannedTasks {
            let parent = TodoItem(
                title: planned.title,
                notes: planned.citation,
                assignee: planned.assignee,
                speaker: planned.assignee,
                priority: planned.priority.rawValue,
                relativeDueDate: planned.relativeDueDate?.rawValue
            )
            modelContext.insert(parent)

            for sub in planned.subtasks {
                let child = TodoItem(
                    title: sub.title,
                    notes: sub.citation,
                    parentID: parent.id
                )
                modelContext.insert(child)
            }
        }
        try? modelContext.save()
    }

    private func sendWebhooks(
        audioFile: AudioFile,
        transcriptResult: TranscriptResult?,
        summaryResult: SummaryResult?
    ) async {
        let webhookService = WebhookService()
        let settings: WebhookSettings?

        let descriptor = FetchDescriptor<WebhookSettings>()
        settings = try? modelContext.fetch(descriptor).first

        guard let settings else { return }

        if let transcriptResult {
            try? await webhookService.sendWebhook(
                eventType: .transcriptionCompleted,
                data: [
                    "audioFileId": audioFile.id.uuidString,
                    "title": audioFile.title,
                    "duration": audioFile.duration,
                    "transcript": transcriptResult.text,
                    "segments": transcriptResult.segments.count
                ],
                settings: settings
            )
        }

        if let summaryResult {
            try? await webhookService.sendWebhook(
                eventType: .summarizationCompleted,
                data: [
                    "audioFileId": audioFile.id.uuidString,
                    "title": audioFile.title,
                    "summary": summaryResult.summary,
                    "keyPoints": summaryResult.keyPoints,
                    "actionItems": summaryResult.actionItems
                ],
                settings: settings
            )
        }
    }
}
