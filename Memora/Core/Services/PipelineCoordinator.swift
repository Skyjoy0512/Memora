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
    private let repoFactory: RepositoryFactory?
    private let modelContext: ModelContext

    // MARK: - Progress (read by FileDetailViewModel for UI polling)

    var currentTranscriptionProgress: Double { transcriptionEngine.progress }
    var currentSummarizationProgress: Double { summarizationEngine.progress }

    init(
        transcriptionEngine: TranscriptionEngine,
        summarizationEngine: SummarizationEngine,
        repoFactory: RepositoryFactory?,
        modelContext: ModelContext
    ) {
        self.transcriptionEngine = transcriptionEngine
        self.summarizationEngine = summarizationEngine
        self.repoFactory = repoFactory
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
                do {
                    let transcriptResult = try await executeTranscription(
                        audioURL: audioURL,
                        audioFile: audioFile,
                        apiKey: apiKey,
                        provider: provider,
                        transcriptionMode: transcriptionMode,
                        continuation: continuation
                    )

                    // --- Step 4: Summary ---
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
                    continuation.yield(.stepStarted(.extractingMetadata))

                    audioFile.isSummarized = true
                    audioFile.summary = summaryResult.summary
                    audioFile.keyPoints = summaryResult.keyPointsText
                    audioFile.actionItems = summaryResult.actionItemsText
                    saveAudioFile(audioFile)

                    continuation.yield(.stepCompleted(.extractingMetadata))

                    // --- Step 6: Extract Todos ---
                    if config.autoCreateTodos {
                        continuation.yield(.stepStarted(.extractingTodos))

                        summarizationEngine.createTodoItems(
                            from: summaryResult,
                            sourceFileId: audioFile.id,
                            sourceFileTitle: audioFile.title,
                            modelContext: modelContext
                        )

                        continuation.yield(.stepCompleted(.extractingTodos))
                    }

                    // --- Step 7: Finalize ---
                    continuation.yield(.stepStarted(.finalizing))

                    // Webhook 送信
                    await sendWebhooks(
                        audioFile: audioFile,
                        transcriptResult: transcriptResult,
                        summaryResult: summaryResult
                    )

                    continuation.yield(.stepCompleted(.finalizing))
                    continuation.yield(.completed)

                } catch is CancellationError {
                } catch {
                    // 現在実行中のステップを特定してエラー通知
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
                do {
                    let transcriptResult = try await executeTranscription(
                        audioURL: audioURL,
                        audioFile: audioFile,
                        apiKey: apiKey,
                        provider: provider,
                        transcriptionMode: transcriptionMode,
                        continuation: continuation
                    )

                    continuation.yield(.stepStarted(.finalizing))

                    await sendWebhooks(
                        audioFile: audioFile,
                        transcriptResult: transcriptResult,
                        summaryResult: nil
                    )

                    continuation.yield(.stepCompleted(.finalizing))
                    continuation.yield(.completed)
                } catch is CancellationError {
                } catch {
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
                    continuation.yield(.stepStarted(.extractingMetadata))

                    audioFile.isSummarized = true
                    audioFile.summary = summaryResult.summary
                    audioFile.keyPoints = summaryResult.keyPointsText
                    audioFile.actionItems = summaryResult.actionItemsText
                    saveAudioFile(audioFile)

                    continuation.yield(.stepCompleted(.extractingMetadata))

                    // Todos
                    if config.autoCreateTodos {
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
                    continuation.yield(.stepStarted(.finalizing))

                    await sendWebhooks(
                        audioFile: audioFile,
                        transcriptResult: nil,
                        summaryResult: summaryResult
                    )

                    continuation.yield(.stepCompleted(.finalizing))
                    continuation.yield(.completed)

                } catch is CancellationError {
                } catch {
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
        continuation: AsyncStream<PipelineEvent>.Continuation
    ) async throws -> TranscriptResult {
        continuation.yield(.stepStarted(.loadingAudio))

        try await transcriptionEngine.configure(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode
        )

        continuation.yield(.stepCompleted(.loadingAudio))

        continuation.yield(.stepStarted(.transcribing))
        let transcriptResult = try await transcriptionEngine.transcribe(audioURL: audioURL)
        continuation.yield(.stepCompleted(.transcribing))

        continuation.yield(.stepStarted(.mergingTranscripts))

        let transcript = Transcript(audioFileID: audioFile.id, text: transcriptResult.text)
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

        continuation.yield(.stepCompleted(.mergingTranscripts))
        return transcriptResult
    }

    private func saveTranscript(_ transcript: Transcript) {
        if let factory = repoFactory {
            try? factory.transcriptRepo.save(transcript)
        } else {
            modelContext.insert(transcript)
            try? modelContext.save()
        }
    }

    private func saveAudioFile(_ audioFile: AudioFile) {
        if let factory = repoFactory {
            try? factory.audioFileRepo.save(audioFile)
        } else {
            try? modelContext.save()
        }
    }

    private func sendWebhooks(
        audioFile: AudioFile,
        transcriptResult: TranscriptResult?,
        summaryResult: SummaryResult?
    ) async {
        let webhookService = WebhookService()
        let settings: WebhookSettings?

        if let factory = repoFactory {
            settings = try? factory.webhookSettingsRepo.fetch()
        } else {
            let descriptor = FetchDescriptor<WebhookSettings>()
            settings = try? modelContext.fetch(descriptor).first
        }

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
