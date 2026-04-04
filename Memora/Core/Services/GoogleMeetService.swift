import Foundation
import SwiftData

/// Google Meet REST API クライアント。
/// conferenceRecords / transcripts / recordings の取得と AudioFile へのインポートを提供。
@MainActor
final class GoogleMeetService {

    // MARK: - Error

    enum MeetError: LocalizedError {
        case notConfigured
        case tokenExpired
        case networkError(Error)
        case decodingError(Error)
        case serverError(Int, String?)
        case noRecordingAvailable
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Google Meet 連携が設定されていません。"
            case .tokenExpired:
                return "アクセストークンが期限切れです。再認証してください。"
            case .networkError(let error):
                return "通信エラー: \(error.localizedDescription)"
            case .decodingError(let error):
                return "データの解析に失敗しました: \(error.localizedDescription)"
            case .serverError(let code, let message):
                return "サーバーエラー (\(code)): \(message ?? "不明なエラー")"
            case .noRecordingAvailable:
                return "録画が利用できません。"
            case .downloadFailed:
                return "録画ファイルのダウンロードに失敗しました。"
            }
        }
    }

    // MARK: - DTOs

    struct ConferenceRecordListResponse: Codable {
        let conferenceRecords: [ConferenceRecord]?
        let nextPageToken: String?
    }

    struct ConferenceRecord: Codable, Identifiable {
        var id: String { name }
        let name: String           // "conferenceRecords/xxx"
        let space: Space?
        let startTime: String?     // RFC 3339
        let endTime: String?

        struct Space: Codable {
            let space: String?      // "spaces/xxx"
            let meetingUri: String?
            let meetingCode: String?
        }

        var startDate: Date? {
            guard let startTime else { return nil }
            return ISO8601DateFormatter().date(from: startTime)
        }

        var endDate: Date? {
            guard let endTime else { return nil }
            return ISO8601DateFormatter().date(from: endTime)
        }
    }

    struct TranscriptListResponse: Codable {
        let transcripts: [Transcript]?
        let nextPageToken: String?
    }

    struct Transcript: Codable {
        let name: String
        let state: String?
    }

    struct TranscriptEntryListResponse: Codable {
        let transcriptEntries: [TranscriptEntry]?
        let nextPageToken: String?
    }

    struct TranscriptEntry: Codable {
        let text: String?
        let languageCode: String?
    }

    struct RecordingListResponse: Codable {
        let recordings: [Recording]?
        let nextPageToken: String?
    }

    struct Recording: Codable {
        let name: String
        let state: String?
        let driveDestination: DriveDestination?

        struct DriveDestination: Codable {
            let exportUri: String?
            let file: String?      // "drive/file_id"
        }

        var driveFileID: String? {
            guard let file = driveDestination?.file else { return nil }
            return file.components(separatedBy: "/").last
        }
    }

    // MARK: - Properties

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Conference Records

    /// 会議レコード一覧を取得する。
    /// - Parameters:
    ///   - token: アクセストークン
    ///   - pageSize: 1ページあたりの件数（デフォルト 50）
    func fetchConferenceRecords(
        token: String,
        pageSize: Int = 50
    ) async throws -> [ConferenceRecord] {
        var allRecords: [ConferenceRecord] = []
        var pageToken: String?

        repeat {
            var components = URLComponents(string: "https://meet.googleapis.com/v2/conferenceRecords")
            components?.queryItems = [
                URLQueryItem(name: "pageSize", value: "\(pageSize)")
            ]
            if let pageToken {
                components?.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            let data = try await authenticatedGET(url: components!.url!, token: token)
            let response = try JSONDecoder().decode(ConferenceRecordListResponse.self, from: data)
            allRecords += response.conferenceRecords ?? []
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allRecords
    }

    // MARK: - Transcripts

    /// 会議の文字起こし一覧を取得する。
    func fetchTranscripts(
        conferenceName: String,
        token: String
    ) async throws -> [Transcript] {
        let url = URL(string: "https://meet.googleapis.com/v2/\(conferenceName)/transcripts")!
        let data = try await authenticatedGET(url: url, token: token)
        let response = try JSONDecoder().decode(TranscriptListResponse.self, from: data)
        return response.transcripts ?? []
    }

    /// 文字起こしエントリ（全文）を取得する。
    /// retention 注意: 会議後 30 日で削除される可能性あり。
    func fetchTranscriptEntries(
        transcriptName: String,
        token: String
    ) async throws -> [TranscriptEntry] {
        var allEntries: [TranscriptEntry] = []
        var pageToken: String?

        repeat {
            var components = URLComponents(string: "https://meet.googleapis.com/v2/\(transcriptName)/entries")
            if let pageToken {
                components?.queryItems = [URLQueryItem(name: "pageToken", value: pageToken)]
            }

            let data = try await authenticatedGET(url: components!.url!, token: token)
            let response = try JSONDecoder().decode(TranscriptEntryListResponse.self, from: data)
            allEntries += response.transcriptEntries ?? []
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allEntries
    }

    // MARK: - Recordings

    /// 会議の録画一覧を取得する。
    func fetchRecordings(
        conferenceName: String,
        token: String
    ) async throws -> [Recording] {
        let url = URL(string: "https://meet.googleapis.com/v2/\(conferenceName)/recordings")!
        let data = try await authenticatedGET(url: url, token: token)
        let response = try JSONDecoder().decode(RecordingListResponse.self, from: data)
        return response.recordings ?? []
    }

    /// Google Drive API で録画ファイルをダウンロードする。
    func downloadRecording(
        driveFileID: String,
        token: String
    ) async throws -> URL {
        let urlString = "https://www.googleapis.com/download/drive/v3/files/\(driveFileID)?alt=media"
        let url = URL(string: urlString)!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MeetError.downloadFailed
        }

        // 一時ファイルに保存
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("google_meet_\(driveFileID).mp4")
        try data.write(to: tempURL)

        return tempURL
    }

    // MARK: - Full Import

    /// 会議レコードを AudioFile としてインポートする。
    /// 録画があればダウンロードし、文字起こしがあれば referenceTranscript に保存。
    func importConferenceRecord(
        record: ConferenceRecord,
        token: String,
        modelContext: ModelContext
    ) async throws -> AudioFile? {
        // 1. 録画を確認
        let recordings = try await fetchRecordings(
            conferenceName: record.name,
            token: token
        )

        guard let recording = recordings.first,
              let driveFileID = recording.driveFileID else {
            // 録画なし → テキストのみインポート
            return try await importTextOnly(
                record: record,
                token: token,
                modelContext: modelContext
            )
        }

        // 2. 録画ダウンロード
        let tempURL = try await downloadRecording(
            driveFileID: driveFileID,
            token: token
        )

        // 3. AudioFile 作成
        let title = record.space?.meetingCode ?? record.name
        let audioFile = try AudioFileImportService.importAudio(
            from: tempURL,
            suggestedTitle: title,
            modelContext: modelContext,
            requiresSecurityScopedAccess: false
        )
        audioFile.sourceTypeRaw = SourceType.google.rawValue

        if let startDate = record.startDate {
            audioFile.createdAt = startDate
        }

        // 4. 文字起こし取得 → referenceTranscript
        let transcriptText = try await fetchFullTranscript(
            conferenceName: record.name,
            token: token
        )
        if !transcriptText.isEmpty {
            audioFile.referenceTranscript = transcriptText
        }

        try modelContext.save()
        return audioFile
    }

    // MARK: - Private

    private func importTextOnly(
        record: ConferenceRecord,
        token: String,
        modelContext: ModelContext
    ) async throws -> AudioFile? {
        let transcriptText = try await fetchFullTranscript(
            conferenceName: record.name,
            token: token
        )

        guard !transcriptText.isEmpty else { return nil }

        let title = record.space?.meetingCode ?? record.name
        let audioFile = PlaudImportService.importTextOnly(
            title: title,
            textContent: transcriptText,
            modelContext: modelContext
        )
        audioFile.sourceTypeRaw = SourceType.google.rawValue

        if let startDate = record.startDate {
            audioFile.createdAt = startDate
        }

        try modelContext.save()
        return audioFile
    }

    /// 会議の完全な文字起こしテキストを取得する。
    private func fetchFullTranscript(
        conferenceName: String,
        token: String
    ) async throws -> String {
        let transcripts = try await fetchTranscripts(
            conferenceName: conferenceName,
            token: token
        )

        guard let transcript = transcripts.first else { return "" }

        let entries = try await fetchTranscriptEntries(
            transcriptName: transcript.name,
            token: token
        )

        return entries
            .compactMap { $0.text }
            .joined(separator: "\n")
    }

    private func authenticatedGET(url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MeetError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw MeetError.tokenExpired
        default:
            let message = String(data: data, encoding: .utf8)
            throw MeetError.serverError(httpResponse.statusCode, message)
        }
    }
}
