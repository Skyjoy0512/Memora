import Foundation
import SwiftData

@Model
public final class MemoryProfile {
    public var id: UUID
    public var summaryStyle: String?
    public var preferredLanguage: String?
    public var roleLabel: String?
    public var glossaryJSON: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
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

    public func update(
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
