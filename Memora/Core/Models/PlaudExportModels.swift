import Foundation

/// Plaud アプリのエクスポート JSON 形式
struct PlaudExportFile: Codable {
    let title: String?
    let createdAt: Date?
    let duration: TimeInterval?
    let transcript: String?
    let summary: String?
    let speakers: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case createdAt = "created_at"
        case duration
        case transcript
        case summary
        case speakers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try? container.decodeIfPresent(String.self, forKey: .title)

        // created_at: ISO8601 or unix timestamp
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString)
                ?? ISO8601DateFormatter().date(from: dateString)
        } else if let timestamp = try? container.decodeIfPresent(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = nil
        }

        // duration: 秒数（String or Double）
        if let durStr = try? container.decodeIfPresent(String.self, forKey: .duration) {
            duration = Double(durStr) ?? 0
        } else {
            duration = try? container.decodeIfPresent(Double.self, forKey: .duration)
        }

        transcript = try? container.decodeIfPresent(String.self, forKey: .transcript)
        summary = try? container.decodeIfPresent(String.self, forKey: .summary)
        speakers = try? container.decodeIfPresent([String].self, forKey: .speakers)
    }
}
