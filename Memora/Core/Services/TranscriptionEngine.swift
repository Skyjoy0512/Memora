import Foundation
import AVFoundation

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

    private var aiService: AIService?
    private var transcriptionMode: TranscriptionMode = .local

    func configure(apiKey: String, provider: AIProvider = .openai, transcriptionMode: TranscriptionMode = .local) async throws {
        self.transcriptionMode = transcriptionMode

        let service = AIService()
        service.setProvider(provider)
        service.setTranscriptionMode(transcriptionMode)

        // APIキー設定（ローカルモードでも要約用に必要）
        try await service.configure(apiKey: apiKey)

        self.aiService = service
    }

    func transcribe(audioURL: URL) async throws -> TranscriptResult {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        isTranscribing = true
        progress = 0

        do {
            let transcriptText = try await service.transcribe(audioURL: audioURL)
            progress = 1.0

            isTranscribing = false

            // 簡易的なセグメント作成（話者分離は次のフェーズで実装）
            let segments = createSimpleSegments(from: transcriptText)

            return TranscriptResult(
                text: transcriptText,
                segments: segments,
                duration: audioFileDuration(for: audioURL)
            )
        } catch {
            isTranscribing = false
            throw error
        }
    }

    private func createSimpleSegments(from text: String) -> [SpeakerSegment] {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var segments: [SpeakerSegment] = []
        var currentTime: TimeInterval = 0

        for (index, line) in lines.enumerated() {
            let segmentDuration = TimeInterval(line.count) * 0.3
            segments.append(SpeakerSegment(
                speakerLabel: "Speaker \((index % 2) + 1)",
                startTime: currentTime,
                endTime: currentTime + segmentDuration,
                text: line
            ))
            currentTime += segmentDuration
        }

        return segments
    }

    private func audioFileDuration(for url: URL) -> TimeInterval {
        let asset = AVAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}
