import Foundation
@preconcurrency import AVFoundation

// Core transcription path. Do not modify without an explicit STT task.

@MainActor
private protocol TranscriptionEngineProtocol: Sendable {
    var isTranscribing: Bool { get }
    var progress: Double { get }

    func configure(
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode
    ) async throws

    func transcribe(audioURL: URL) async throws -> TranscriptResult
    func transcribe(audioURL: URL, language: String?) async throws -> TranscriptResult
    func cancelActiveTranscription() async
}

@MainActor
final class TranscriptionEngine: TranscriptionEngineProtocol, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private let sttService: STTServiceProtocol = STTService()

    /// progress 更新の最小差分。これ未満の変動は SwiftUI 再描画をスキップする。
    private static let progressThreshold: Double = 0.005

    func configure(
        apiKey: String,
        provider: AIProvider = .openai,
        transcriptionMode: TranscriptionMode = .local
    ) async throws {
        if transcriptionMode == .api && apiKey.isEmpty {
            throw CoreError.transcriptionError(.transcriptionFailed("API key is missing"))
        }

        (sttService as? STTService)?.updateConfiguration(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode
        )
    }

    func transcribe(audioURL: URL) async throws -> TranscriptResult {
        try await transcribe(audioURL: audioURL, language: nil)
    }

    func transcribe(audioURL: URL, language: String?) async throws -> TranscriptResult {
        DebugLogger.shared.addLog("TranscriptionEngine", "transcribe 開始 — url: \(audioURL.path)", level: .info)
        isTranscribing = true
        progress = 0

        defer {
            isTranscribing = false
            progress = 0
        }

        DebugLogger.shared.addLog("TranscriptionEngine", "sttService.startTranscription 呼び出し", level: .info)
        let (rawHandle, events) = try await sttService.startTranscription(audioURL: audioURL, language: language)
        guard let handle = rawHandle as? STTTaskHandle else {
            throw CoreError.transcriptionError(.transcriptionFailed("Invalid task handle type"))
        }
        DebugLogger.shared.addLog("TranscriptionEngine", "startTranscription 戻り — handle.taskId: \(handle.taskId), progress 監視開始", level: .info)

        // イベントストリームは progress 更新のみに使用。
        // 最終結果は handle.result() から直接取得する。
        // これによりイベントストリームの早期終了（MainActor 競合等）に影響されない。
        let progressTask = Task { @MainActor [weak self] in
            for await event in events {
                guard let self else { return }
                switch event {
                case .transcriptionStarted:
                    self.updateProgress(max(self.progress, 0.02))
                case .transcriptionProgress(_, let value):
                    self.updateProgress(value)
                case .transcriptionCompleted:
                    self.progress = 1.0
                case .transcriptionFailed(_, let error):
                    DebugLogger.shared.addLog("TranscriptionEngine", "progress 監視: .transcriptionFailed — \(error.localizedDescription)", level: .warning)
                case .transcriptionCancelled:
                    DebugLogger.shared.addLog("TranscriptionEngine", "progress 監視: .transcriptionCancelled", level: .warning)
                case .transcriptionPartialResult, .audioChunkStarted, .audioChunkProgress, .audioChunkCompleted:
                    break
                }
            }
            DebugLogger.shared.addLog("TranscriptionEngine", "progress 監視終了", level: .info)
        }

        // handle.result() で直接結果を取得（イベントストリームに依存しない）
        let result: TranscriptionResult
        do {
            result = try await handle.result()
        } catch {
            progressTask.cancel()
            DebugLogger.shared.addLog("TranscriptionEngine", "handle.result() 失敗: \(error.localizedDescription)", level: .error)
            throw error
        }

        progressTask.cancel()
        DebugLogger.shared.addLog("TranscriptionEngine", "handle.result() 成功 — \(result.fullText.count)文字", level: .info)

        return TranscriptResult(
            coreResult: result,
            duration: await audioFileDuration(for: audioURL)
        )
    }

    /// threshold を超える変動のみ @Published に反映する。
    private func updateProgress(_ value: Double) {
        guard abs(value - progress) >= Self.progressThreshold else { return }
        progress = value
    }

    func cancelActiveTranscription() async {
        await sttService.cancelAllTasks()
    }

    private func audioFileDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }
}
