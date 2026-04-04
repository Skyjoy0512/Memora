import Foundation
import SwiftData

@Model
final class MeetingMemo {
    var id: UUID
    var audioFileID: UUID
    var markdown: String
    var plainTextCache: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        audioFileID: UUID,
        markdown: String = "",
        plainTextCache: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.audioFileID = audioFileID
        self.markdown = markdown
        self.plainTextCache = plainTextCache
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(markdown: String, plainTextCache: String) {
        self.markdown = markdown
        self.plainTextCache = plainTextCache
        self.updatedAt = Date()
    }
}
