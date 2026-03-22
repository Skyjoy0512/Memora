//
//  CoreErrors.swift
//  Memora
//
//  Core 契約: エラー定義
//  全エージェントで共有するエラー型
//

import Foundation

// MARK: - CoreError

/// Core レイヤーの基本エラー型
public enum CoreError: LocalizedError, Equatable, Sendable {
    case notFound(type: String, id: UUID)
    case repositoryError(String)
    case validationError(String)
    case pipelineError(PipelineError)
    case transcriptionError(TranscriptionError)
    case llmError(LLMError)
    case audioError(AudioError)
    case dependencyNotSet(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let type, let id):
            return "\(type) not found: \(id.uuidString)"
        case .repositoryError(let message):
            return "Repository error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .pipelineError(let error):
            return "Pipeline error: \(error.localizedDescription)"
        case .transcriptionError(let error):
            return "Transcription error: \(error.localizedDescription)"
        case .llmError(let error):
            return "LLM error: \(error.localizedDescription)"
        case .audioError(let error):
            return "Audio error: \(error.localizedDescription)"
        case .dependencyNotSet(let name):
            return "Dependency not set: \(name)"
        }
    }
}

// MARK: - PipelineError

public enum PipelineError: LocalizedError, Equatable, Sendable {
    case audioFileNotFound
    case chunkingFailed
    case transcriptionFailed(String)
    case mergingTranscriptsFailed
    case metadataExtractionFailed
    case summaryGenerationFailed(String)
    case todoExtractionFailed(String)
    case finalizationFailed
    case jobNotFound(UUID)
    case jobAlreadyInProgress(UUID)

    public var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "Audio file not found"
        case .chunkingFailed:
            return "Audio chunking failed"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .mergingTranscriptsFailed:
            return "Failed to merge transcripts"
        case .metadataExtractionFailed:
            return "Metadata extraction failed"
        case .summaryGenerationFailed(let message):
            return "Summary generation failed: \(message)"
        case .todoExtractionFailed(let message):
            return "Todo extraction failed: \(message)"
        case .finalizationFailed:
            return "Finalization failed"
        case .jobNotFound(let id):
            return "Job not found: \(id.uuidString)"
        case .jobAlreadyInProgress(let id):
            return "Job already in progress: \(id.uuidString)"
        }
    }
}

// MARK: - TranscriptionError

public enum TranscriptionError: LocalizedError, Equatable, Sendable {
    case audioFileInvalid
    case audioFormatNotSupported
    case languageNotSupported(String)
    case transcriptionInProgress
    case transcriptionFailed(String)
    case engineNotAvailable

    public var errorDescription: String? {
        switch self {
        case .audioFileInvalid:
            return "Audio file is invalid"
        case .audioFormatNotSupported:
            return "Audio format not supported"
        case .languageNotSupported(let language):
            return "Language not supported: \(language)"
        case .transcriptionInProgress:
            return "Transcription already in progress"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .engineNotAvailable:
            return "Transcription engine not available"
        }
    }
}

// MARK: - AudioError

public enum AudioError: LocalizedError, Equatable, Sendable {
    case noActiveRecording
    case microphonePermissionDenied
    case audioSessionFailed(String)
    case recordingFailed(String?)
    case playbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noActiveRecording:
            return "録音が開始されていません"
        case .microphonePermissionDenied:
            return "マイクへのアクセスが許可されていません"
        case .audioSessionFailed(let message):
            return "オーディオセッションの設定に失敗しました: \(message)"
        case .recordingFailed(let message):
            if let message {
                return "録音に失敗しました: \(message)"
            }
            return "録音に失敗しました"
        case .playbackFailed(let message):
            return "音声ファイルの読み込みに失敗しました: \(message)"
        }
    }
}

// MARK: - STTError

public enum STTError: LocalizedError, Equatable, Sendable {
    case transcriptionInProgress
    case transcriptionFailed(String, retryable: Bool = true)
    case networkError(String)
    case permissionDenied
    case serviceUnavailable
    case timeout

    public var errorDescription: String? {
        switch self {
        case .transcriptionInProgress:
            return "文字起こし中"
        case .transcriptionFailed(let message, let retryable):
            if retryable {
                return "文字起こしに失敗しました: \(message)"
            } else {
                return "文字起こしに失敗しました（再試行不可）: \(message)"
            }
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .permissionDenied:
            return "権限がありません"
        case .serviceUnavailable:
            return "サービスが利用できません"
        case .timeout:
            return "タイムアウトしました"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .transcriptionFailed(_, let retryable):
            return retryable
        case .networkError, .serviceUnavailable, .timeout:
            return true
        case .transcriptionInProgress, .permissionDenied:
            return false
        }
    }
}

// MARK: - LLMError

public enum LLMError: LocalizedError, Equatable, Sendable {
    case networkError(String)
    case apiError(statusCode: Int?, message: String)
    case rateLimitExceeded
    case quotaExceeded
    case authenticationFailed
    case modelNotAvailable(String)
    case parsingFailed(String)
    case invalidResponse
    case configurationNotSet

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let code, let message):
            if let code = code {
                return "API error (\(code)): \(message)"
            } else {
                return "API error: \(message)"
            }
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .quotaExceeded:
            return "Quota exceeded"
        case .authenticationFailed:
            return "Authentication failed"
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .configurationNotSet:
            return "LLM configuration not set"
        }
    }
}
