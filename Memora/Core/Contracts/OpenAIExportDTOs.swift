//
//  OpenAIExportDTOs.swift
//  Memora
//
//  Core 契約: OpenAI エクスポート DTO 定義
//

import Foundation

// MARK: - Export Format

/// OpenAI ファイルアップロード時のフォーマット
enum OpenAIExportFormat: String, CaseIterable, Sendable {
    case json
    case markdown
}

// MARK: - File Purpose

/// OpenAI Files API の purpose パラメータ
enum OpenAIFilePurpose: String, Sendable {
    case assistants
    case userData = "user_data"
}

// MARK: - Upload Result

/// OpenAI Files API のアップロード結果
struct OpenAIFileUploadResult: Sendable, Equatable {
    let fileId: String
    let filename: String
    let bytes: Int
    let purpose: String
    let createdAt: Date
}

// MARK: - Export Error

enum OpenAIExportError: LocalizedError, Equatable, Sendable {
    case apiKeyMissing
    case noDataToExport
    case fileTooLarge(maxBytes: Int)
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case invalidResponse
    case encodingFailed
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API キーが設定されていません"
        case .noDataToExport:
            return "エクスポートするデータがありません"
        case .fileTooLarge(let maxBytes):
            return "ファイルサイズが制限(\(maxBytes / 1_000_000)MB)を超えています"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .apiError(let code, let message):
            return "OpenAI API エラー (\(code)): \(message)"
        case .invalidResponse:
            return "OpenAI API から無効なレスポンスが返されました"
        case .encodingFailed:
            return "ファイルのエンコードに失敗しました"
        case .rateLimitExceeded:
            return "OpenAI API のレート制限に達しました"
        }
    }
}
