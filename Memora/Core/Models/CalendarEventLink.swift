import Foundation
import SwiftData

/// 端末カレンダーから取り込んだイベント情報のキャッシュ。
/// AudioFile との紐付け（audioFileID）を持ち、将来の Google 連携にも対応する。
@Model
final class CalendarEventLink {
    var id: UUID
    var provider: String       // "eventkit" | "google"
    var externalID: String     // EKEvent.calendarItemIdentifier 等
    var audioFile: AudioFile?
    var title: String
    var startAt: Date
    var endAt: Date
    var meetingURL: String?
    var conferenceProvider: String?
    var audioFileID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
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
