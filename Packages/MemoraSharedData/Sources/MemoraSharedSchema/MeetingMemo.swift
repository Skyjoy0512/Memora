import Foundation
import SwiftData

@Model
public final class MeetingMemo {
    public var id: UUID
    public var audioFileID: UUID
    public var markdown: String
    public var plainTextCache: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
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

    public func update(markdown: String, plainTextCache: String) {
        self.markdown = markdown
        self.plainTextCache = plainTextCache
        self.updatedAt = Date()
    }
}
