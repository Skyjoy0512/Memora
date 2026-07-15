import Foundation
import SwiftData

/// Webhook イベント種別
public enum WebhookEventType: String, Codable {
    case transcriptionCompleted = "transcription.completed"
    case summarizationCompleted = "summarization.completed"
}

/// Webhook 設定
@Model
public final class WebhookSettings {
    public var id: UUID
    public var url: String
    public var isEnabled: Bool
    public var events: [String] // WebhookEventType の生の文字列
    public var createdAt: Date
    public var updatedAt: Date

    public init() {
        self.id = UUID()
        self.url = ""
        self.isEnabled = false
        self.events = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 有効なイベント種別を取得
    public var enabledEventTypes: [WebhookEventType] {
        events.compactMap { WebhookEventType(rawValue: $0) }
    }

    /// イベントが有効か判定
    public func isEventEnabled(_ eventType: WebhookEventType) -> Bool {
        events.contains(eventType.rawValue)
    }

    /// イベントを切り替え
    public func toggleEvent(_ eventType: WebhookEventType) {
        if isEventEnabled(eventType) {
            events.removeAll { $0 == eventType.rawValue }
        } else {
            events.append(eventType.rawValue)
        }
        updatedAt = Date()
    }
}
