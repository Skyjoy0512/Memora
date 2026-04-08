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
        let (_, events) = try await sttService.startTranscription(audioURL: audioURL, language: language)
        DebugLogger.shared.addLog("TranscriptionEngine", "sttService.startTranscription 戻り — イベント待機", level: .info)

        // イベントループは MainActor 上で実行されるが、`for await` で待機中は
        // MainActor は解放される。progress 更新は threshold で間引き、
        // SwiftUI の過剰再描画を防止する。
        let finalResult = try await withTaskCancellationHandler {
            var finalResult: TranscriptionResult?

            for await event in events {
                switch event {
                case .transcriptionStarted:
                    updateProgress(max(progress, 0.02))
                case .transcriptionProgress(_, let value):
                    updateProgress(value)
                case .transcriptionCompleted(_, let result):
                    progress = 1.0
                    finalResult = result
                case .transcriptionFailed(_, let error):
                    throw error
                case .transcriptionCancelled:
                    throw CancellationError()
                case .transcriptionPartialResult:
                    // volatile（中間結果）: UI には progress だけで十分
                    continue
                case .audioChunkStarted,
                     .audioChunkProgress,
                     .audioChunkCompleted:
                    continue
                }
            }

            guard let finalResult else {
                throw CoreError.transcriptionError(.transcriptionFailed("Transcription did not produce a result"))
            }

            return finalResult
        } onCancel: {
            Task {
                await self.sttService.cancelAllTasks()
            }
        }

        return TranscriptResult(
            coreResult: finalResult,
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
