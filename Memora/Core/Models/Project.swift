import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var descriptionText: String?

    @Relationship(deleteRule: .nullify, inverse: \AudioFile.project)
    var files: [AudioFile]

    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.files = []
        self.createdAt = Date()
    }
}
