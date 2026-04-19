import Foundation
import SwiftData

enum PhotoAttachmentOwnerType: String, CaseIterable {
    case audioFile = "audioFile"
    case project = "project"
    case memo = "memo"
}

@Model
final class PhotoAttachment {
    var id: UUID
    var ownerTypeRaw: String
    var ownerID: UUID
    var audioFile: AudioFile?
    var sortOrder: Int
    var localPath: String
    var thumbnailPath: String?
    var caption: String?
    var ocrText: String?
    var createdAt: Date
    var updatedAt: Date

    var ownerType: PhotoAttachmentOwnerType {
        get { PhotoAttachmentOwnerType(rawValue: ownerTypeRaw) ?? .audioFile }
        set { ownerTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ownerType: PhotoAttachmentOwnerType,
        ownerID: UUID,
        sortOrder: Int = 0,
        localPath: String,
        thumbnailPath: String? = nil,
        caption: String? = nil,
        ocrText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerTypeRaw = ownerType.rawValue
        self.ownerID = ownerID
        self.sortOrder = sortOrder
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.caption = caption
        self.ocrText = ocrText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func updateCaption(_ caption: String?) {
        self.caption = caption
        self.updatedAt = Date()
    }

    func updateOCRText(_ ocrText: String?) {
        self.ocrText = ocrText
        self.updatedAt = Date()
    }

    func updateSortOrder(_ sortOrder: Int) {
        self.sortOrder = sortOrder
        self.updatedAt = Date()
    }
}
