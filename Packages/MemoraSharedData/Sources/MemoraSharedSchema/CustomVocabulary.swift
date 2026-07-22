import Foundation
import SwiftData

@Model
public final class CustomVocabulary {
    public var id: UUID
    public var pattern: String
    public var replacement: String
    public var reading: String?
    public var enabled: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), pattern: String, replacement: String, reading: String? = nil, enabled: Bool = true, createdAt: Date = Date()) {
        self.id = id; self.pattern = pattern; self.replacement = replacement; self.reading = reading; self.enabled = enabled; self.createdAt = createdAt
    }
}
