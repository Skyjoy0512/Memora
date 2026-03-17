import Foundation

protocol TranscriptionEngineProtocol {
    var isTranscribing: Bool { get }
    var progress: Double { get }

    func transcribe(audioURL: URL) async throws -> TranscriptResult
}

struct TranscriptResult {
    let text: String
    let segments: [SpeakerSegment]
    let duration: TimeInterval
}

final class TranscriptionEngine: TranscriptionEngineProtocol, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private var currentTask: Task<Void, Never>?

    func transcribe(audioURL: URL) async throws -> TranscriptResult {
        isTranscribing = true
        progress = 0

        return try await withTaskCancellationHandler {
            try await simulateTranscription(for: audioURL)
        } onCancel: {
            currentTask?.cancel()
            isTranscribing = false
        }
    }

    private func simulateTranscription(for url: URL) async throws -> TranscriptResult {
        // TODO: 実際の API を呼び出す
        // ここではシミュレーション

        let totalDuration: TimeInterval = 5 // 5秒のシミュレーション
        let steps = 100
        let stepDuration = totalDuration / Double(steps)

        for i in 0...steps {
            try Task.checkCancellation()
            progress = Double(i) / Double(steps)
            try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }

        isTranscribing = false

        // サンプル結果
        let text = """
        これはテスト用の文字起こし結果です。

        Speaker 1: 今日はプロジェクトの進捗について議論します。
        Speaker 2: 了解しました。まず現状から確認しましょう。
        Speaker 1: 現在、UIの実装が80%ほど完了しています。
        Speaker 2: 次は文字起こし機能の実装ですね。
        Speaker 1: その通りです。音声からテキストに変換する必要があります。
        """

        let segments = [
            SpeakerSegment(
                speakerLabel: "Speaker 1",
                startTime: 0,
                endTime: 5,
                text: "今日はプロジェクトの進捗について議論します。"
            ),
            SpeakerSegment(
                speakerLabel: "Speaker 2",
                startTime: 5,
                endTime: 10,
                text: "了解しました。まず現状から確認しましょう。"
            ),
            SpeakerSegment(
                speakerLabel: "Speaker 1",
                startTime: 10,
                endTime: 15,
                text: "現在、UIの実装が80%ほど完了しています。"
            )
        ]

        return TranscriptResult(
            text: text,
            segments: segments,
            duration: audioFileDuration(for: url)
        )
    }

    private func audioFileDuration(for url: URL) -> TimeInterval {
        // TODO: 実際の音声ファイルの長さを取得
        return 60 // 1分と仮定
    }
}

