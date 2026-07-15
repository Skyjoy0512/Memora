import Foundation
import SwiftData

/// 端末カレンダーから取り込んだイベント情報のキャッシュ。
/// AudioFile との紐付け（audioFileID）を持ち、将来の Google 連携にも対応する。
@Model
public final class CalendarEventLink {
    public var id: UUID
    public var provider: String       // "eventkit" | "google"
    public var externalID: String     // EKEvent.calendarItemIdentifier 等
    public var audioFile: AudioFile?
    public var title: String
    public var startAt: Date
    public var endAt: Date
    public var meetingURL: String?
    public var conferenceProvider: String?
    public var audioFileID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        provider: String,
        externalID: String,
        title: String,
        startAt: Date,
        endAt: Date,
        meetingURL: String? = nil,
        conferenceProvider: String? = nil,
        audioFileID: UUID? = nil
    ) {
        self.id = id
        self.provider = provider
        self.externalID = externalID
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.meetingURL = meetingURL
        self.conferenceProvider = conferenceProvider
        self.audioFileID = audioFileID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
