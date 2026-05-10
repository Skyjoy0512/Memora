import Foundation

// MARK: - Bot Server API DTOs

struct BotMeetingScheduleRequest: Codable {
    let meetingID: String
    let platform: String
    let meetingURL: String
    let meetingTitle: String
    let scheduledTime: String
    let durationMinutes: Int
    let webhookURL: String?
}

struct BotMeetingScheduleResponse: Codable {
    let jobID: String
    let status: String
    let scheduledTime: String
}

struct BotMeetingStatusResponse: Codable {
    let jobID: String
    let status: String
    let audioURL: String?
    let transcript: String?
    let summary: String?
    let error: String?
}

// MARK: - Bot Meeting Service

@MainActor
final class BotMeetingService {
    private var serverURL: String = ""
    private var apiKey: String = ""
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func configure(serverURL: String, apiKey: String) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty
    }

    // MARK: - Schedule Meeting

    func scheduleMeeting(_ meeting: ScheduledBotMeeting) async throws -> BotMeetingScheduleResponse {
        guard isConfigured else { throw BotMeetingError.notConfigured }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let body = BotMeetingScheduleRequest(
            meetingID: meeting.id.uuidString,
            platform: meeting.platform,
            meetingURL: meeting.meetingURL,
            meetingTitle: meeting.meetingTitle,
            scheduledTime: formatter.string(from: meeting.scheduledTime),
            durationMinutes: meeting.durationMinutes,
            webhookURL: nil
        )

        let url = try buildURL(path: "/meetings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BotMeetingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(BotMeetingScheduleResponse.self, from: data)
        case 401:
            throw BotMeetingError.unauthorized
        case 400:
            throw BotMeetingError.badRequest(String(data: data, encoding: .utf8) ?? "Bad request")
        default:
            throw BotMeetingError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Get Status

    func getMeetingStatus(jobID: String) async throws -> BotMeetingStatusResponse {
        guard isConfigured else { throw BotMeetingError.notConfigured }

        let url = try buildURL(path: "/meetings/\(jobID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BotMeetingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(BotMeetingStatusResponse.self, from: data)
        case 401:
            throw BotMeetingError.unauthorized
        case 404:
            throw BotMeetingError.notFound
        default:
            throw BotMeetingError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Cancel Meeting

    func cancelMeeting(jobID: String) async throws {
        guard isConfigured else { throw BotMeetingError.notConfigured }

        let url = try buildURL(path: "/meetings/\(jobID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BotMeetingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw BotMeetingError.unauthorized
        case 404:
            throw BotMeetingError.notFound
        default:
            throw BotMeetingError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        guard isConfigured else { throw BotMeetingError.notConfigured }

        let url = try buildURL(path: "/health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BotMeetingError.invalidResponse
        }
        return httpResponse.statusCode == 200
    }

    // MARK: - Helpers

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: "\(serverURL)\(path)") else {
            throw BotMeetingError.invalidURL
        }
        return url
    }
}

// MARK: - Bot Meeting Error

enum BotMeetingError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case badRequest(String)
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "サーバーが設定されていません"
        case .invalidURL: return "URLが無効です"
        case .invalidResponse: return "サーバーからの応答が無効です"
        case .unauthorized: return "認証に失敗しました。APIキーを確認してください"
        case .badRequest(let msg): return "リクエストが不正です: \(msg)"
        case .notFound: return "会議が見つかりません"
        case .serverError(let code): return "サーバーエラー (\(code))"
        }
    }
}
