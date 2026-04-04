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

        let finalResult = try await withTaskCancellationHandler {
            var finalResult: TranscriptionResult?

            for await event in events {
                switch event {
                case .transcriptionStarted:
                    progress = max(progress, 0.02)
                case .transcriptionProgress(_, let value):
                    progress = value
                case .transcriptionCompleted(_, let result):
                    progress = 1.0
                    finalResult = result
                case .transcriptionFailed(_, let error):
                    throw error
                case .transcriptionCancelled:
                    throw CancellationError()
                case .transcriptionPartialResult,
                     .audioChunkStarted,
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
