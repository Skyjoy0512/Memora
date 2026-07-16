import Foundation

public enum CoreError: LocalizedError, Equatable, Sendable {
    case notFound(type: String, id: UUID)
    case repositoryError(String)
    case validationError(String)
    case pipelineError(PipelineError)
    case transcriptionError(TranscriptionError)
    case llmError(LLMError)
    case audioError(AudioError)
    case summaryError(SummaryError)
    case dependencyNotSet(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let type, let id): return "\(type) not found: \(id.uuidString)"
        case .repositoryError(let message): return "Repository error: \(message)"
        case .validationError(let message): return "Validation error: \(message)"
        case .pipelineError(let error): return "Pipeline error: \(error.localizedDescription)"
        case .transcriptionError(let error): return "Transcription error: \(error.localizedDescription)"
        case .llmError(let error): return "LLM error: \(error.localizedDescription)"
        case .audioError(let error): return "Audio error: \(error.localizedDescription)"
        case .summaryError(let error): return "Summary error: \(error.localizedDescription)"
        case .dependencyNotSet(let name): return "Dependency not set: \(name)"
        }
    }
}

public enum PipelineError: LocalizedError, Equatable, Sendable {
    case audioFileNotFound, chunkingFailed, mergingTranscriptsFailed, metadataExtractionFailed, finalizationFailed
    case transcriptionFailed(String), summaryGenerationFailed(String), todoExtractionFailed(String)
    case jobNotFound(UUID), jobAlreadyInProgress(UUID)

    public var errorDescription: String? {
        switch self {
        case .audioFileNotFound: return "Audio file not found"
        case .chunkingFailed: return "Audio chunking failed"
        case .transcriptionFailed(let message): return "Transcription failed: \(message)"
        case .mergingTranscriptsFailed: return "Failed to merge transcripts"
        case .metadataExtractionFailed: return "Metadata extraction failed"
        case .summaryGenerationFailed(let message): return "Summary generation failed: \(message)"
        case .todoExtractionFailed(let message): return "Todo extraction failed: \(message)"
        case .finalizationFailed: return "Finalization failed"
        case .jobNotFound(let id): return "Job not found: \(id.uuidString)"
        case .jobAlreadyInProgress(let id): return "Job already in progress: \(id.uuidString)"
        }
    }
}

public enum TranscriptionError: LocalizedError, Equatable, Sendable {
    case audioFileInvalid, audioFormatNotSupported, transcriptionInProgress, engineNotAvailable
    case languageNotSupported(String), transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .audioFileInvalid: return "Audio file is invalid"
        case .audioFormatNotSupported: return "Audio format not supported"
        case .languageNotSupported(let language): return "Language not supported: \(language)"
        case .transcriptionInProgress: return "Transcription already in progress"
        case .transcriptionFailed(let message): return "Transcription failed: \(message)"
        case .engineNotAvailable: return "Transcription engine not available"
        }
    }
}

public enum SummaryError: LocalizedError, Equatable, Sendable {
    case transcriptionNotAvailable, emptyTranscript
    case saveFailed(String), loadFailed(String), generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .transcriptionNotAvailable: return "文字起こしデータがありません"
        case .saveFailed(let message): return "要約の保存に失敗しました: \(message)"
        case .loadFailed(let message): return "要約の読み込みに失敗しました: \(message)"
        case .emptyTranscript: return "文字起こしが空です"
        case .generationFailed(let message): return "要約の生成に失敗しました: \(message)"
        }
    }
}

public enum AudioError: LocalizedError, Equatable, Sendable {
    case noActiveRecording, microphonePermissionDenied
    case audioSessionFailed(String), recordingFailed(String?), playbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noActiveRecording: return "録音が開始されていません"
        case .microphonePermissionDenied: return "マイクへのアクセスが許可されていません"
        case .audioSessionFailed(let message): return "オーディオセッションの設定に失敗しました: \(message)"
        case .recordingFailed(let message): return message.map { "録音に失敗しました: \($0)" } ?? "録音に失敗しました"
        case .playbackFailed(let message): return "音声ファイルの読み込みに失敗しました: \(message)"
        }
    }
}

public enum LLMError: LocalizedError, Equatable, Sendable {
    case networkError(String), apiError(statusCode: Int?, message: String), modelNotAvailable(String), parsingFailed(String)
    case rateLimitExceeded, quotaExceeded, authenticationFailed, invalidResponse, configurationNotSet

    public var errorDescription: String? {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .apiError(let code, let message): return code.map { "API error (\($0)): \(message)" } ?? "API error: \(message)"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .quotaExceeded: return "Quota exceeded"
        case .authenticationFailed: return "Authentication failed"
        case .modelNotAvailable(let model): return "Model not available: \(model)"
        case .parsingFailed(let message): return "Parsing failed: \(message)"
        case .invalidResponse: return "Invalid response from LLM"
        case .configurationNotSet: return "LLM configuration not set"
        }
    }
}
