import Foundation
import SwiftData

/// Notion 連携の設定。Internal Integration Token と親ページ ID を保持。
@Model
public final class NotionSettings {
    public var id: UUID
    public var integrationToken: String
    public var parentPageID: String
    public var isEnabled: Bool
    public var lastExportAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        integrationToken: String = "",
        parentPageID: String = "",
        isEnabled: Bool = false
    ) {
        self.id = id
        self.integrationToken = integrationToken
        self.parentPageID = parentPageID
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var isConfigured: Bool {
        !integrationToken.isEmpty && !parentPageID.isEmpty
    }
}
