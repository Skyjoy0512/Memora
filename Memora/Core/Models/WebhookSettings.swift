import Foundation
import SwiftData

/// Webhook イベント種別
enum WebhookEventType: String, Codable {
    case transcriptionCompleted = "transcription.completed"
    case summarizationCompleted = "summarization.completed"
}

/// Webhook 設定
@Model
final class WebhookSettings {
    var id: UUID
    var url: String
    var isEnabled: Bool
    var events: [String] // WebhookEventType の生の文字列
    var createdAt: Date
    var updatedAt: Date

    init() {
        self.id = UUID()
        self.url = ""
        self.isEnabled = false
        self.events = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 有効なイベント種別を取得
    var enabledEventTypes: [WebhookEventType] {
        events.compactMap { WebhookEventType(rawValue: $0) }
    }

    /// イベントが有効か判定
    func isEventEnabled(_ eventType: WebhookEventType) -> Bool {
        events.contains(eventType.rawValue)
    }

    /// イベントを切り替え
    func toggleEvent(_ eventType: WebhookEventType) {
        if isEventEnabled(eventType) {
            events.removeAll { $0 == eventType.rawValue }
        } else {
            events.append(eventType.rawValue)
        }
        updatedAt = Date()
    }
}
