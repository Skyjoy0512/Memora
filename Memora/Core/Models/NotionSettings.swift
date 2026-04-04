import Foundation
import SwiftData

/// Notion 連携の設定。Internal Integration Token と親ページ ID を保持。
@Model
final class NotionSettings {
    var id: UUID
    var integrationToken: String
    var parentPageID: String
    var isEnabled: Bool
    var lastExportAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
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

    var isConfigured: Bool {
        !integrationToken.isEmpty && !parentPageID.isEmpty
    }
}
