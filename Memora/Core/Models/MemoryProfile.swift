import Foundation
import SwiftData

@Model
final class MemoryProfile {
    var id: UUID
    var summaryStyle: String?
    var preferredLanguage: String?
    var roleLabel: String?
    var glossaryJSON: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        summaryStyle: String? = nil,
        preferredLanguage: String? = nil,
        roleLabel: String? = nil,
        glossaryJSON: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.summaryStyle = summaryStyle
        self.preferredLanguage = preferredLanguage
        self.roleLabel = roleLabel
        self.glossaryJSON = glossaryJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(
        summaryStyle: String? = nil,
        preferredLanguage: String? = nil,
        roleLabel: String? = nil,
        glossaryJSON: String? = nil
    ) {
        self.summaryStyle = summaryStyle
        self.preferredLanguage = preferredLanguage
        self.roleLabel = roleLabel
        self.glossaryJSON = glossaryJSON
        self.updatedAt = Date()
    }
}
