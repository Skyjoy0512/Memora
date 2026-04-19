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
                do {
                    try modelContext.save()
                } catch {
                    DebugLogger.shared.addLog("Pipeline", "Failed to save job: \(error.localizedDescription)", level: .error)
                }

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
                            segments: transcriptResult.segments,
                            config: config
                        )
                    } else {
                        summaryResult = try await summarizationEngine.summarize(
                            transcript: transcriptResult.text,
                            config: config
                        )
                    }

                    continuation.yield(.stepCompleted(.generatingSummary))

                    // --- Step 5: Save Summary ---
                    job.updateProgress(0.7, stage: PipelineStep.extractingMetadata.rawValue)
                    continuation.yield(.stepStarted(.extractingMetadata))

                    audioFile.isSummarized = true
                    if let suggestedTitle = summaryResult.suggestedTitle, !suggestedTitle.isEmpty {
                        audioFile.title = suggestedTitle
                    }
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
                    do {
                        try modelContext.save()
                    } catch {
                        DebugLogger.shared.addLog("Pipeline", "Failed to save job after cancellation: \(error.localizedDescription)", level: .error)
                    }
                } catch {
                    job.markFailed(error.localizedDescription, stage: job.stage)
                    do {
                        try modelContext.save()
                    } catch {
                        DebugLogger.shared.addLog("Pipeline", "Failed to save job after error: \(error.localizedDescription)", level: .error)
                    }
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
                do {
                    try modelContext.save()
                } catch {
                    DebugLogger.shared.addLog("Pipeline", "Failed to save job: \(error.localizedDescription)", level: .error)
                }

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
                    do {
                        try modelContext.save()
                    } catch {
                        DebugLogger.shared.addLog("Pipeline", "Failed to save job after cancellation: \(error.localizedDescription)", level: .error)
                    }
                } catch {
                    job.markFailed(error.localizedDescription, stage: job.stage)
                    do {
                        try modelContext.save()
                    } catch {
                        DebugLogger.shared.addLog("Pipeline", "Failed to save job after error: \(error.localizedDescription)", level: .error)
                    }
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
                do {
                    try modelContext.save()
                } catch {
                    DebugLogger.shared.addLog("Pipeline", "Failed to save job: \(error.localizedDescription)", level: .error)
                }

                do {
                    // Configure
                    try await summarizationEngine.configure(apiKey: apiKey, provider: provider)

                    // Summary
                    continuation.yield(.stepStarted(.generatingSummary))

                    let summaryResult: SummaryResult
                    if config.includeSpeakers && !segments.isEmpty {
                        summaryResult = try await summarizationEngine.summarizeWithSpeakers(
                            transcript: transcriptText,
                            segments: segments,
                            config: config
                        )
                    } else {
                        summaryResult = try await summarizationEngine.summarize(
                            transcript: transcriptText,
                            config: config
                        )
                    }

                    continuation.yield(.stepCompleted(.generatingSummary))

                    // Save
                    job.updateProgress(0.7, stage: PipelineStep.extractingMetadata.rawValue)
                    continuation.yield(.stepStarted(.extractingMetadata))

                    audioFile.isSummarized = true
                    if let suggestedTitle = summaryResult.suggestedTitle, !suggestedTitle.isEmpty {
                        audioFile.title = suggestedTitle
                    }
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
                    do {
                        try modelContext.save()
                    } catch {
                        DebugLogger.shared.addLog("Pipeline", "Failed to save job after cancellation: \(error.localizedDescription)", level: .error)
                    }
                } catch {
                    job.markFailed(error.localizedDescription, stage: job.stage)
                    do {
                        try modelContext.save()
                    } catch {
                        DebugLogger.shared.addLog("Pipeline", "Failed to save job after error: \(error.localizedDescription)", level: .error)
                    }
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

        // 文字起こしステップ: 失敗時にリトライ（最大 maxRetries 回）
        job.updateProgress(0.1, stage: PipelineStep.transcribing.rawValue)
        continuation.yield(.stepStarted(.transcribing))

        var transcriptResult: TranscriptResult?
        var lastError: Error?

        // Plaid 参照データから話者数を取得（AudioFile → docs/ 自動検索の順）
        let effectiveSpeakerCount = audioFile.referenceSpeakerCount
            ?? Self.loadReferenceFromDocs(audioFileName: audioFile.title).flatMap { Self.extractSpeakerCount(from: $0) }

        while job.canRetry || transcriptResult != nil {
            do {
                DebugLogger.shared.addLog("Pipeline", "transcriptionEngine.transcribe 呼び出し (attempt \(job.retryCount + 1))", level: .info)
                transcriptResult = try await transcriptionEngine.transcribe(audioURL: audioURL, language: nil, referenceSpeakerCount: effectiveSpeakerCount)
                break
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                DebugLogger.shared.addLog("Pipeline", "文字起こし失敗: \(error.localizedDescription) (retry \(job.retryCount)/\(job.maxRetries))", level: .warning)
                if job.canRetry {
                    job.incrementRetry()
                    job.markStarted(stage: PipelineStep.transcribing.rawValue)
                    continuation.yield(.stepStarted(.transcribing))
                } else {
                    break
                }
            }
        }

        guard let transcriptResult else {
            let errorMessage = lastError?.localizedDescription ?? "Transcription failed"
            throw CoreError.transcriptionError(.transcriptionFailed(errorMessage))
        }

        DebugLogger.shared.addLog("Pipeline", "transcriptionEngine.transcribe 完了 — text length: \(transcriptResult.text.count)", level: .info)
        let segmentLabels = Set(transcriptResult.segments.map(\.speakerLabel)).sorted()
        DebugLogger.shared.addLog("Pipeline", "★ 診断: segments=\(transcriptResult.segments.count), speakers=\(segmentLabels) (\(segmentLabels.count)人)", level: .info)
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
        do {
            try modelContext.save()
        } catch {
            DebugLogger.shared.addLog("Pipeline", "Failed to save transcript: \(error.localizedDescription)", level: .error)
        }

        audioFile.isTranscribed = true
        saveAudioFile(audioFile)
        reindexKnowledge(for: audioFile)

        // PlaudNote 参照データとの比較ログ出力
        // 1. AudioFile に referenceTranscript が設定されていれば使用
        // 2. 未設定なら docs/ からファイル名マッチで自動検索（DEBUG のみ）
        let referenceText = audioFile.referenceTranscript
            ?? Self.loadReferenceFromDocs(audioFileName: audioFile.title)
        if let reference = referenceText, !reference.isEmpty {
            logDiarizationComparison(
                reference: reference,
                memoraResult: transcriptResult,
                audioFileName: audioFile.title
            )
        }

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

    // MARK: - Reference Data Auto-Loading

    /// 参照テキストを検索: バンドルリソース → docs/ パス（Mac のみ）
    private static func loadReferenceFromDocs(audioFileName: String) -> String? {
        // 1. アプリバンドルから "reference-transcript" リソースを検索
        if let url = Bundle.main.url(forResource: "reference-transcript", withExtension: "txt") {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                print("[Pipeline] 参照データ検出: Bundle resource")
                return content
            }
        }

        #if DEBUG
        // 2. Mac の docs/ パス（シミュレータ or Mac アプリ向け）
        let docsPath = "/Users/hashimotokenichi/Desktop/Memora/docs/reference-diarization/plaud"
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: docsPath) else {
            return nil
        }

        let normalizedAudio = audioFileName.lowercased()
        for file in files {
            guard file.hasSuffix("-transcript.txt") || file.hasSuffix(".txt") else { continue }
            let normalizedFile = file.lowercased()
            if normalizedAudio.count >= 5 {
                let prefix = String(normalizedAudio.prefix(5))
                if normalizedFile.contains(prefix) {
                    let fullPath = docsPath + "/" + file
                    if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                        print("[Pipeline] 参照データ検出: \(file)")
                        return content
                    }
                }
            }
        }
        #endif
        return nil
    }

    /// テキストから話者数を抽出（"Speaker N" パターン）
    private static func extractSpeakerCount(from text: String) -> Int? {
        var speakers = Set<String>()
        for line in text.components(separatedBy: .newlines) {
            if let range = line.range(of: "Speaker \\d+", options: .regularExpression) {
                speakers.insert(String(line[range]))
            }
        }
        return speakers.isEmpty ? nil : speakers.count
    }

    // MARK: - Diarization Comparison Logging

    /// PlaudNote 参照データと Memora の話者分離結果を比較し、コンソールログに出力する。
    private func logDiarizationComparison(
        reference: String,
        memoraResult: TranscriptResult,
        audioFileName: String
    ) {
        let refSpeakers = extractSpeakerSet(from: reference)
        let memoraSpeakers = Set(memoraResult.segments.map(\.speakerLabel))

        print("═══════════════════════════════════════════")
        print("[Diarization Comparison] \(audioFileName)")
        print("  Plaud speakers: \(refSpeakers.sorted()) (\(refSpeakers.count)人)")
        print("  Memora speakers: \(memoraSpeakers.sorted()) (\(memoraSpeakers.count)人)")
        print("  Memora segments count: \(memoraResult.segments.count)")
        if let first = memoraResult.segments.first {
            print("  First segment label: \(first.speakerLabel), text prefix: \(String(first.text.prefix(30)))")
        }
        print("───────────────────────────────────────────")

        // Plaud 側: 話者ごとの発話行数
        print("  [Plaud] 話者別発話行数:")
        let refLines = reference.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var refCounts: [String: Int] = [:]
        for line in refLines {
            if let speaker = extractSpeakerFromLine(line) {
                refCounts[speaker, default: 0] += 1
            }
        }
        for (speaker, count) in refCounts.sorted(by: { $0.key < $1.key }) {
            print("    \(speaker): \(count)行")
        }

        // Memora 側: 話者ごとのセグメント数・テキスト長
        print("  [Memora] 話者別セグメント:")
        var memoraCounts: [String: (segments: Int, chars: Int)] = [:]
        for seg in memoraResult.segments {
            let entry = memoraCounts[seg.speakerLabel, default: (0, 0)]
            memoraCounts[seg.speakerLabel] = (entry.segments + 1, entry.chars + seg.text.count)
        }
        for (speaker, info) in memoraCounts.sorted(by: { $0.key < $1.key }) {
            print("    \(speaker): \(info.segments)セグメント, \(info.chars)文字")
        }

        // 差分サマリー
        let speakerDiff = refSpeakers.count - memoraSpeakers.count
        if speakerDiff > 0 {
            print("  ⚠️ Memora が \(speakerDiff)人少なく検出")
        } else if speakerDiff < 0 {
            print("  ⚠️ Memora が \(-speakerDiff)人多く検出")
        } else {
            print("  ✓ 話者数一致")
        }
        print("═══════════════════════════════════════════")

        DebugLogger.shared.addLog("Pipeline", "Diarization比較: Plaud \(refSpeakers.count)人 vs Memora \(memoraSpeakers.count)人", level: .info)
    }

    /// PlaudNote テキストから話者セットを抽出。
    /// 対応形式: "Speaker 1:", "00:00:00 Speaker 1", "Speaker 1"
    private func extractSpeakerSet(from text: String) -> Set<String> {
        var speakers = Set<String>()
        for line in text.components(separatedBy: .newlines) {
            // "Speaker N" または "Speaker N:" を含む行
            if let range = line.range(of: "Speaker \\d+", options: .regularExpression) {
                speakers.insert(String(line[range]))
            }
        }
        return speakers
    }

    /// 1行から話者ラベルを抽出
    private func extractSpeakerFromLine(_ line: String) -> String? {
        if let range = line.range(of: "Speaker \\d+", options: .regularExpression) {
            return String(line[range])
        }
        return nil
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
        do {
            try modelContext.save()
        } catch {
            DebugLogger.shared.addLog("Pipeline", "Failed to save planned tasks: \(error.localizedDescription)", level: .error)
        }
    }

    private func sendWebhooks(
        audioFile: AudioFile,
        transcriptResult: TranscriptResult?,
        summaryResult: SummaryResult?
    ) async {
        let webhookService = WebhookService()
        let settings: WebhookSettings?

        let descriptor = FetchDescriptor<WebhookSettings>()
        do {
            settings = try modelContext.fetch(descriptor).first
        } catch {
            DebugLogger.shared.addLog("Pipeline", "Failed to fetch webhook settings: \(error.localizedDescription)", level: .warning)
            return
        }

        guard let settings else { return }

        if let transcriptResult {
            do {
                try await webhookService.sendWebhook(
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
            } catch {
                DebugLogger.shared.addLog("Pipeline", "Failed to send transcription webhook: \(error.localizedDescription)", level: .warning)
            }
        }

        if let summaryResult {
            do {
                try await webhookService.sendWebhook(
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
            } catch {
                DebugLogger.shared.addLog("Pipeline", "Failed to send summary webhook: \(error.localizedDescription)", level: .warning)
            }
        }
    }
}
