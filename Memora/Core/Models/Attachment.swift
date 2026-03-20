import Foundation
import SwiftData

@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    var audioFile: AudioFile?
    var type: AttachmentType
    var localPath: String
    var thumbnailPath: String?
    var createdAt: Date

    enum AttachmentType: String, Codable {
        case image = "image"
        case pdf = "pdf"
    }

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        localPath: String,
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.type = type
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.createdAt = Date()
    }
}
