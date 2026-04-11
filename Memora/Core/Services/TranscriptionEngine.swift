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
        DebugLogger.shared.addLog("TranscriptionEngine", "sttService.startTranscription 戻り — イベント待機", level: .info)

        // handle.result() フォールバック用に具象型を保持
        let concreteHandle = rawHandle as? STTTaskHandle

        do {
            let finalResult = try await withTaskCancellationHandler {
                try await consumeEvents(events: events, audioURL: audioURL)
            } onCancel: {
                Task {
                    await self.sttService.cancelAllTasks()
                }
            }

            return TranscriptResult(
                coreResult: finalResult,
                duration: await audioFileDuration(for: audioURL)
            )
        } catch {
            // イベントストリームが途中で終了した場合、handle.result() で直接取得を試みる
            // runTask の Task はまだ実行中（話者分離など）→ 完了を待って結果を受け取る
            if let handle = concreteHandle, handle.isRunning {
                DebugLogger.shared.addLog("TranscriptionEngine", "イベントストリーム終了 — handle.result() でフォールバック取得: \(error.localizedDescription)", level: .warning)
                do {
                    let directResult = try await handle.result()
                    DebugLogger.shared.addLog("TranscriptionEngine", "handle.result() 成功 — \(directResult.fullText.count)文字", level: .info)
                    return TranscriptResult(
                        coreResult: directResult,
                        duration: await audioFileDuration(for: audioURL)
                    )
                } catch {
                    DebugLogger.shared.addLog("TranscriptionEngine", "handle.result() も失敗: \(error.localizedDescription)", level: .error)
                    throw error
                }
            }
            throw error
        }
    }

    /// 非同期イベントストリームを消費する。MainActor から分離して実行し、
    /// 背景スレッドからのイベントを確実に受け取る。
    @MainActor
    private func consumeEvents(events: AsyncStream<STTEvent>, audioURL: URL) async throws -> TranscriptionResult {
        print("[MemoraSTT] TranscriptionEngine: イベント消費開始")

        var finalResult: TranscriptionResult?

        for await event in events {
            switch event {
            case .transcriptionStarted:
                print("[MemoraSTT] TranscriptionEngine: .transcriptionStarted 受信")
                updateProgress(max(progress, 0.02))
            case .transcriptionProgress(_, let value):
                updateProgress(value)
            case .transcriptionCompleted(_, let result):
                print("[MemoraSTT] TranscriptionEngine: .transcriptionCompleted 受信 — \(result.fullText.count)文字")
                progress = 1.0
                finalResult = result
            case .transcriptionFailed(_, let error):
                print("[MemoraSTT] TranscriptionEngine: .transcriptionFailed 受信 — \(error)")
                throw error
            case .transcriptionCancelled:
                print("[MemoraSTT] TranscriptionEngine: .transcriptionCancelled 受信")
                throw CancellationError()
            case .transcriptionPartialResult:
                // volatile（中間結果）: UI には progress だけで十分
                continue
            case .audioChunkStarted(let index):
                print("[MemoraSTT] TranscriptionEngine: .audioChunkStarted 受信 — index: \(index)")
            case .audioChunkProgress(let index, let chunkProgress):
                // chunk progress はログのみ
                continue
            case .audioChunkCompleted(let index, let result):
                print("[MemoraSTT] TranscriptionEngine: .audioChunkCompleted 受信 — index: \(index), text: \(result.fullText.prefix(30))")
            }
        }

        print("[MemoraSTT] TranscriptionEngine: イベントループ終了 — finalResult is nil: \(finalResult == nil)")
        guard let finalResult else {
            throw CoreError.transcriptionError(.transcriptionFailed("Transcription did not produce a result"))
        }

        return finalResult
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
