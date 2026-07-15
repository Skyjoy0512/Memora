import Foundation
import SwiftData

public enum PhotoAttachmentOwnerType: String, CaseIterable {
    case audioFile = "audioFile"
    case project = "project"
    case memo = "memo"
}

@Model
public final class PhotoAttachment {
    public var id: UUID
    public var ownerTypeRaw: String
    public var ownerID: UUID
    public var audioFile: AudioFile?
    public var sortOrder: Int
    public var localPath: String
    public var thumbnailPath: String?
    public var caption: String?
    public var ocrText: String?
    public var createdAt: Date
    public var updatedAt: Date

    public var ownerType: PhotoAttachmentOwnerType {
        get { PhotoAttachmentOwnerType(rawValue: ownerTypeRaw) ?? .audioFile }
        set { ownerTypeRaw = newValue.rawValue }
    }

    public init(
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

    public func updateCaption(_ caption: String?) {
        self.caption = caption
        self.updatedAt = Date()
    }

    public func updateOCRText(_ ocrText: String?) {
        self.ocrText = ocrText
        self.updatedAt = Date()
    }

    public func updateSortOrder(_ sortOrder: Int) {
        self.sortOrder = sortOrder
        self.updatedAt = Date()
    }
}
