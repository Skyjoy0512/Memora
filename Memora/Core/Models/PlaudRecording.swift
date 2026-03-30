import Foundation

/// Plaud 録音データ
struct PlaudRecording: Codable, Identifiable {
    /// 録音 ID
    let id: String

    /// タイトル
    let title: String

    /// 録音時間（秒）
    let duration: TimeInterval

    /// 作成日時
    let createdAt: Date

    /// オーディオ URL
    let audioUrl: String?

    /// 文字起こしテキスト（あれば）
    let transcript: String?

    /// 要約（あれば）
    let summary: String?

    /// JSON データから初期化（Plaud API レスポンス対応）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // API レスポンス形式に応じたデコード
        id = try container.decode(String.self, forKey: .id)

        title = (try? container.decode(String.self, forKey: .title)) ?? "録音"

        let durationString = try container.decode(String.self, forKey: .duration)
        duration = Double(durationString) ?? 0

        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        createdAt = formatter.date(from: dateString) ?? Date()

        audioUrl = try? container.decodeIfPresent(String.self, forKey: .audioUrl)
        transcript = try? container.decodeIfPresent(String.self, forKey: .transcript)
        summary = try? container.decodeIfPresent(String.self, forKey: .summary)
    }

    /// 手動初期化（テスト用）
    init(
        id: String,
        title: String,
        duration: TimeInterval,
        createdAt: Date,
        audioUrl: String? = nil,
        transcript: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.createdAt = createdAt
        self.audioUrl = audioUrl
        self.transcript = transcript
        self.summary = summary
    }

    /// CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case createdAt = "created_at"
        case audioUrl = "audio_url"
        case transcript
        case summary
    }

    /// Encodable サポート（必要な場合）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode("\(duration)", forKey: .duration)

        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: createdAt), forKey: .createdAt)

        try container.encodeIfPresent(audioUrl, forKey: .audioUrl)
        try container.encodeIfPresent(transcript, forKey: .transcript)
        try container.encodeIfPresent(summary, forKey: .summary)
    }
}
