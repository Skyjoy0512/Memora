import Foundation
import Speech

// UI 互換用の内部ラッパー。STT 境界の DTO は Core 契約の
// `TranscriptionResult` のみを使用する。

/// スピーカーセグメント（UI 表示用）
struct SpeakerSegment {
    let speakerLabel: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct TranscriptResult {
    let text: String
    let segments: [SpeakerSegment]
    let duration: TimeInterval

    init(text: String, segments: [SpeakerSegment], duration: TimeInterval) {
        self.text = text
        self.segments = segments
        self.duration = duration
    }

    init(coreResult: TranscriptionResult, duration: TimeInterval) {
        self.text = coreResult.fullText
        self.segments = coreResult.segments.map {
            SpeakerSegment(
                speakerLabel: $0.speakerLabel,
                startTime: $0.startSec,
                endTime: $0.endSec,
                text: $0.text
            )
        }
        self.duration = duration
    }

    var coreResult: TranscriptionResult {
        TranscriptionResult(
            fullText: text,
            language: "ja",
            segments: segments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: "segment-\(index)",
                    speakerLabel: segment.speakerLabel,
                    startSec: segment.startTime,
                    endSec: segment.endTime,
                    text: segment.text
                )
            }
        )
    }
}

struct STTExecutionConfiguration: Sendable {
    let apiKey: String
    let provider: AIProvider
    let transcriptionMode: TranscriptionMode

    static let localDefault = STTExecutionConfiguration(
        apiKey: "",
        provider: .openai,
        transcriptionMode: .local
    )
}

enum STTLanguageNormalizer {
    static func baseLanguageCode(for rawLanguage: String) -> String {
        rawLanguage
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init)?
            .lowercased() ?? rawLanguage.lowercased()
    }
}

enum STTErrorMapper {
    static func mapToCoreError(_ error: Error) -> CoreError {
        if let coreError = error as? CoreError {
            return coreError
        }

        if let transcriptionError = error as? TranscriptionError {
            return .transcriptionError(transcriptionError)
        }

        if let chunkerError = error as? AudioChunkerError {
            return .pipelineError(.transcriptionFailed(chunkerError.localizedDescription))
        }

        if let aiError = error as? AIError {
            return .transcriptionError(.transcriptionFailed(aiError.localizedDescription))
        }

        if let openAIError = error as? OpenAIError {
            return .transcriptionError(.transcriptionFailed(openAIError.localizedDescription))
        }

        return .transcriptionError(.transcriptionFailed(error.localizedDescription))
    }
}

enum LocalSTTBackend: String, Sendable {
    case speechAnalyzer = "SpeechAnalyzer"
    case speechRecognizer = "SFSpeechRecognizer"
    case api = "API"
}

enum SpeechAnalyzerFallbackReason: String, Sendable, Equatable {
    case osTooOld
    case localeUnavailable
    case assetUnavailable
    case prepareFailed
    case runtimeFailure
}

enum SpeechAnalyzerSupportStatus: Sendable, Equatable {
    case available
    case localeUnavailable
    case assetUnavailable
}

enum LocalSTTBackendSelection: Sendable, Equatable {
    case speechAnalyzer
    case speechRecognizer(reason: SpeechAnalyzerFallbackReason)
}

enum LocalSTTBackendResolver {
    static func resolve(
        osSupportsSpeechAnalyzer: Bool,
        supportStatus: SpeechAnalyzerSupportStatus?
    ) -> LocalSTTBackendSelection {
        guard osSupportsSpeechAnalyzer else {
            return .speechRecognizer(reason: .osTooOld)
        }

        switch supportStatus {
        case .available:
            return .speechAnalyzer
        case .localeUnavailable:
            return .speechRecognizer(reason: .localeUnavailable)
        case .assetUnavailable:
            return .speechRecognizer(reason: .assetUnavailable)
        case nil:
            return .speechRecognizer(reason: .runtimeFailure)
        }
    }
}

enum STTChunkingPolicy {
    static func shouldPreChunk(transcriptionMode: TranscriptionMode) -> Bool {
        transcriptionMode == .api
    }
}

extension SpeechAnalyzerFallbackReason {
    var logDescription: String {
        switch self {
        case .osTooOld:
            return "osTooOld"
        case .localeUnavailable:
            return "localeUnavailable"
        case .assetUnavailable:
            return "assetUnavailable"
        case .prepareFailed:
            return "prepareFailed"
        case .runtimeFailure:
            return "runtimeFailure"
        }
    }
}
