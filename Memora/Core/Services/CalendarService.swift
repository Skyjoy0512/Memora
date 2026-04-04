import Foundation
import EventKit
import SwiftData

// MARK: - Error

enum CalendarError: LocalizedError {
    case accessDenied
    case accessRestricted
    case eventStoreUnavailable
    case eventNotFound
    case linkAlreadyExists

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "カレンダーへのアクセスが拒否されました。設定から許可してください。"
        case .accessRestricted:
            return "カレンダーへのアクセスが制限されています。"
        case .eventStoreUnavailable:
            return "カレンダー機能を利用できません。"
        case .eventNotFound:
            return "該当するカレンダーイベントが見つかりません。"
        case .linkAlreadyExists:
            return "このファイルは既にカレンダーイベントに紐付いています。"
        }
    }
}

// MARK: - CalendarService

/// EventKit をラップし、カレンダーイベントの取得・AudioFile との紐付けを提供するサービス。
@MainActor
final class CalendarService {

    @ObservationIgnored
    private let eventStore = EKEventStore()

    // MARK: - Permission

    /// カレンダーへのアクセス権限を要求する。
    /// - Returns: アクセスが許可されたかどうか
    @discardableResult
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// 現在のアクセス権限状態を返す。
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            authorizationStatus == .fullAccess
        } else {
            authorizationStatus == .authorized
        }
    }

    // MARK: - Fetch Events

    /// 今後のイベント一覧を取得する。
    /// - Parameter daysAhead: 現在から何日先まで取得するか（デフォルト 7 日）
    /// - Returns: 開始日時昇順の EKEvent 配列
    func fetchUpcomingEvents(daysAhead: Int = 7) -> [EKEvent] {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) ?? now

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    /// 指定日のイベント一覧を取得する。
    func fetchEvents(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    /// AudioFile 作成日時前後のイベントを検索し、マッチ候補を返す。
    /// - Parameter audioFile: 対象の AudioFile
    /// - Parameter toleranceMinutes: 前後の許容分数（デフォルト 30 分）
    /// - Returns: マッチする EKEvent（なければ nil）
    func findMatchingEvent(for audioFile: AudioFile, toleranceMinutes: Int = 30) -> EKEvent? {
        let fileDate = audioFile.createdAt
        let startDate = Calendar.current.date(byAdding: .minute, value: -toleranceMinutes, to: fileDate) ?? fileDate
        let endDate = Calendar.current.date(byAdding: .minute, value: toleranceMinutes, to: fileDate) ?? fileDate

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let candidates = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        // 最も近いイベントを返す
        return candidates.first
    }

    // MARK: - Link / Unlink

    /// EKEvent と AudioFile を紐付ける。
    /// - Parameters:
    ///   - event: 紐付けるカレンダーイベント
    ///   - audioFile: 紐付ける録音ファイル
    ///   - modelContext: SwiftData コンテキスト
    /// - Returns: 作成された CalendarEventLink
    func linkEventToAudioFile(
        event: EKEvent,
        audioFile: AudioFile,
        modelContext: ModelContext
    ) throws -> CalendarEventLink {
        // 既存リンク確認
        if audioFile.calendarEventId != nil {
            let existingLink = fetchLink(externalID: event.calendarItemIdentifier, modelContext: modelContext)
            if existingLink != nil {
                throw CalendarError.linkAlreadyExists
            }
        }

        let meetingURL = extractMeetingURL(from: event)

        let link = CalendarEventLink(
            provider: "eventkit",
            externalID: event.calendarItemIdentifier,
            title: event.title ?? "",
            startAt: event.startDate,
            endAt: event.endDate,
            meetingURL: meetingURL?.absoluteString,
            audioFileID: audioFile.id
        )

        audioFile.calendarEventId = event.calendarItemIdentifier

        modelContext.insert(link)
        try modelContext.save()

        return link
    }

    /// AudioFile からカレンダー紐付けを解除する。
    func unlinkEvent(
        audioFile: AudioFile,
        modelContext: ModelContext
    ) throws {
        guard let eventID = audioFile.calendarEventId else { return }

        // CalendarEventLink を検索して削除
        let descriptor = FetchDescriptor<CalendarEventLink>(
            predicate: #Predicate { $0.externalID == eventID }
        )
        let links = try modelContext.fetch(descriptor)
        for link in links {
            modelContext.delete(link)
        }

        audioFile.calendarEventId = nil
        try modelContext.save()
    }

    // MARK: - Query

    /// 指定 externalID の CalendarEventLink を取得する。
    func fetchLink(externalID: String, modelContext: ModelContext) -> CalendarEventLink? {
        var descriptor = FetchDescriptor<CalendarEventLink>(
            predicate: #Predicate { $0.externalID == externalID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 指定 AudioFile に紐付いた CalendarEventLink を取得する。
    func fetchLink(for audioFile: AudioFile, modelContext: ModelContext) -> CalendarEventLink? {
        let fileID = audioFile.id
        var descriptor = FetchDescriptor<CalendarEventLink>(
            predicate: #Predicate { $0.audioFileID == fileID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Private

    /// EKEvent からミーティング URL を抽出する。
    private func extractMeetingURL(from event: EKEvent) -> URL? {
        // event.url を優先
        if let url = event.url {
            return url
        }

        // Notes 内の URL パターンから抽出
        if let notes = event.notes {
            let patterns = [
                "https://meet.google.com/[\\w-]+",
                "https://zoom.us/j/\\d+",
                "https://teams.microsoft.com/[\\w./-]+",
                "https://[\\w.-]+\\.webex\\.com[\\w./-]*"
            ]
            for pattern in patterns {
                if let range = notes.range(of: pattern, options: .regularExpression),
                   let url = URL(string: String(notes[range])) {
                    return url
                }
            }
        }

        return nil
    }
}
