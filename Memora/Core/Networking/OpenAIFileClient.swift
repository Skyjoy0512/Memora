//
//  OpenAIFileClient.swift
//  Memora
//
//  OpenAI Files API 低レベル HTTP クライアント
//

import Foundation

final class OpenAIFileClient {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let networkClient: NetworkClient

    init(apiKey: String, networkClient: NetworkClient = .init()) {
        self.apiKey = apiKey
        self.networkClient = networkClient
    }

    // MARK: - Upload

    func uploadFile(
        data: Data,
        filename: String,
        purpose: OpenAIFilePurpose
    ) async throws -> OpenAIFileUploadResult {
        let url = URL(string: "\(baseURL)/files")!

        var formData = NetworkClient.MultipartFormData()
        formData.add(name: "purpose", value: purpose.rawValue)
        formData.add(name: "file", filename: filename, mimeType: "application/octet-stream", data: data)

        do {
            return try await networkClient.postMultipart(
                url: url,
                headers: ["Authorization": "Bearer \(apiKey)"],
                formData: formData,
                responseType: OpenAIFileObjectResponse.self
            ).toUploadResult()
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        }
    }

    // MARK: - List

    func listFiles(purpose: OpenAIFilePurpose? = nil) async throws -> [OpenAIFileUploadResult] {
        var urlStr = "\(baseURL)/files"
        if let purpose = purpose {
            urlStr += "?purpose=\(purpose.rawValue)"
        }

        guard let url = URL(string: urlStr) else {
            throw OpenAIExportError.invalidResponse
        }

        do {
            let listResponse: OpenAIFileListResponse = try await networkClient.get(
                url: url,
                headers: ["Authorization": "Bearer \(apiKey)"],
                responseType: OpenAIFileListResponse.self
            )
            return listResponse.data.map { $0.toUploadResult() }
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        }
    }

    // MARK: - Retrieve

    func retrieveFile(fileId: String) async throws -> OpenAIFileUploadResult {
        let url = URL(string: "\(baseURL)/files/\(fileId)")!

        do {
            let fileResponse: OpenAIFileObjectResponse = try await networkClient.get(
                url: url,
                headers: ["Authorization": "Bearer \(apiKey)"],
                responseType: OpenAIFileObjectResponse.self
            )
            return fileResponse.toUploadResult()
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        }
    }

    // MARK: - Delete

    func deleteFile(fileId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/files/\(fileId)")!

        do {
            let deleteResponse: OpenAIFileDeleteResponse = try await networkClient.post(
                url: url,
                headers: ["Authorization": "Bearer \(apiKey)"],
                body: nil,
                responseType: OpenAIFileDeleteResponse.self
            )
            return deleteResponse.deleted
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        }
    }

    // MARK: - Error Handling

    private func mapNetworkError(_ error: NetworkError) -> OpenAIExportError {
        switch error {
        case .httpError(let code, _):
            switch code {
            case 401:
                return .apiKeyMissing
            case 429:
                return .rateLimitExceeded
            default:
                let message = "HTTP error: \(code)"
                return .apiError(statusCode: code, message: message)
            }
        case .noConnection, .timedOut:
            return .apiError(statusCode: -1, message: error.localizedDescription ?? "Network error")
        default:
            return .apiError(statusCode: -1, message: error.localizedDescription ?? "Unknown error")
        }
    }
}

// MARK: - Response Models

private struct OpenAIFileObjectResponse: Codable {
    let id: String
    let object: String
    let bytes: Int
    let created_at: Int
    let filename: String
    let purpose: String
    let status: String?

    func toUploadResult() -> OpenAIFileUploadResult {
        OpenAIFileUploadResult(
            fileId: id,
            filename: filename,
            bytes: bytes,
            purpose: purpose,
            createdAt: Date(timeIntervalSince1970: TimeInterval(created_at))
        )
    }
}

private struct OpenAIFileListResponse: Codable {
    let data: [OpenAIFileObjectResponse]
}

private struct OpenAIFileDeleteResponse: Codable {
    let id: String
    let deleted: Bool
}
