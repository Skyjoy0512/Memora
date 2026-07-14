import Foundation

struct PlaudMCPFile: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let createdAt: Date?
    let startAt: Date?
    let durationMilliseconds: Double?
    let presignedURL: URL?
    let sourceList: [PlaudMCPTranscriptSegment]
    let noteList: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case startAt = "start_at"
        case duration
        case presignedURL = "presigned_url"
        case sourceList = "source_list"
        case noteList = "note_list"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? "PLAUD録音"
        createdAt = try container.decodePlaudDateIfPresent(forKey: .createdAt)
        startAt = try container.decodePlaudDateIfPresent(forKey: .startAt)
        durationMilliseconds = try container.decodePlaudNumberIfPresent(forKey: .duration)
        presignedURL = try container.decodeURLIfPresent(forKey: .presignedURL)
        sourceList = (try? container.decode([PlaudMCPTranscriptSegment].self, forKey: .sourceList)) ?? []
        noteList = try container.decodePlaudNotesIfPresent(forKey: .noteList)
    }
}

struct PlaudMCPTranscriptSegment: Decodable, Sendable {
    let start: Double?
    let end: Double?
    let text: String
    let speaker: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        start = try container.decodeFlexibleNumber(forKeys: ["start", "start_time", "startTime"])
        end = try container.decodeFlexibleNumber(forKeys: ["end", "end_time", "endTime"])
        text = (try container.decodeFlexibleString(forKeys: ["text", "content", "transcript"])) ?? ""
        speaker = try container.decodeFlexibleString(forKeys: ["speaker", "speaker_name", "speakerName"])
    }

    var formattedLine: String {
        let timestamp = start.map { String(format: "%02d:%02d", Int($0) / 60, Int($0) % 60) }
        let prefix = [timestamp, speaker].compactMap { $0 }.joined(separator: " ")
        return prefix.isEmpty ? text : "\(prefix) \(text)"
    }
}

struct PlaudMCPToolError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

private extension KeyedDecodingContainer {
    func decodePlaudDateIfPresent(forKey key: Key) throws -> Date? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        if let string = try? decode(String.self, forKey: key) {
            return ISO8601DateFormatter().date(from: string)
        }
        if let timestamp = try? decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    func decodePlaudNumberIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        if let number = try? decode(Double.self, forKey: key) { return number }
        if let string = try? decode(String.self, forKey: key) { return Double(string) }
        return nil
    }

    func decodeURLIfPresent(forKey key: Key) throws -> URL? {
        guard let string = try? decode(String.self, forKey: key) else { return nil }
        return URL(string: string)
    }

    func decodePlaudNotesIfPresent(forKey key: Key) throws -> [String] {
        guard contains(key), !(try decodeNil(forKey: key)) else { return [] }
        if let notes = try? decode([String].self, forKey: key) { return notes }
        guard let notes = try? decode([PlaudMCPNote].self, forKey: key) else { return [] }
        return notes.compactMap(\.displayText)
    }
}

private struct PlaudMCPNote: Decodable {
    let displayText: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        displayText = try container.decodeFlexibleString(
            forKeys: ["content", "text", "note", "summary", "description", "title"]
        )
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func decodeFlexibleString(forKeys keys: [String]) throws -> String? {
        for name in keys {
            let key = DynamicCodingKey(stringValue: name)!
            if let value = try? decode(String.self, forKey: key) { return value }
        }
        return nil
    }

    func decodeFlexibleNumber(forKeys keys: [String]) throws -> Double? {
        for name in keys {
            let key = DynamicCodingKey(stringValue: name)!
            if let value = try? decode(Double.self, forKey: key) { return value }
            if let string = try? decode(String.self, forKey: key), let value = Double(string) { return value }
        }
        return nil
    }
}
