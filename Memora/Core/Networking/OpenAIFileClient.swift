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
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Upload

    func uploadFile(
        data: Data,
        filename: String,
        purpose: OpenAIFilePurpose
    ) async throws -> OpenAIFileUploadResult {
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: "\(baseURL)/files")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // purpose パラメータ
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(purpose.rawValue)\r\n".data(using: .utf8)!)

        // file パラメータ
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        return try handleResponse(responseData, response)
    }

    // MARK: - List

    func listFiles(purpose: OpenAIFilePurpose? = nil) async throws -> [OpenAIFileUploadResult] {
        var urlStr = "\(baseURL)/files"
        if let purpose = purpose {
            urlStr += "?purpose=\(purpose.rawValue)"
        }

        var request = URLRequest(url: URL(string: urlStr)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIExportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapError(statusCode: httpResponse.statusCode, data: data)
        }

        let listResponse = try JSONDecoder().decode(OpenAIFileListResponse.self, from: data)
        return listResponse.data.map { $0.toUploadResult() }
    }

    // MARK: - Retrieve

    func retrieveFile(fileId: String) async throws -> OpenAIFileUploadResult {
        var request = URLRequest(url: URL(string: "\(baseURL)/files/\(fileId)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIExportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapError(statusCode: httpResponse.statusCode, data: data)
        }

        let fileResponse = try JSONDecoder().decode(OpenAIFileObjectResponse.self, from: data)
        return fileResponse.toUploadResult()
    }

    // MARK: - Delete

    func deleteFile(fileId: String) async throws -> Bool {
        var request = URLRequest(url: URL(string: "\(baseURL)/files/\(fileId)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIExportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapError(statusCode: httpResponse.statusCode, data: data)
        }

        let deleteResponse = try JSONDecoder().decode(OpenAIFileDeleteResponse.self, from: data)
        return deleteResponse.deleted
    }

    // MARK: - Error Handling

    private func handleResponse(_ data: Data, _ response: URLResponse) throws -> OpenAIFileUploadResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIExportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapError(statusCode: httpResponse.statusCode, data: data)
        }

        let fileResponse = try JSONDecoder().decode(OpenAIFileObjectResponse.self, from: data)
        return fileResponse.toUploadResult()
    }

    private func mapError(statusCode: Int, data: Data) -> OpenAIExportError {
        let message = if let str = String(data: data, encoding: .utf8) { str } else { "Unknown error" }

        switch statusCode {
        case 401:
            return .apiKeyMissing
        case 429:
            return .rateLimitExceeded
        default:
            return .apiError(statusCode: statusCode, message: message)
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
