import Foundation
import SwiftData

@Model
public final class MemoryFact {
    public var id: UUID
    public var profileID: UUID
    public var key: String
    public var value: String
    public var source: String
    public var confidence: Double
    public var lastConfirmedAt: Date?

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        key: String,
        value: String,
        source: String,
        confidence: Double = 0,
        lastConfirmedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.key = key
        self.value = value
        self.source = source
        self.confidence = confidence
        self.lastConfirmedAt = lastConfirmedAt
    }

    public func confirm(at date: Date = Date(), confidence: Double? = nil) {
        self.lastConfirmedAt = date
        if let confidence {
            self.confidence = confidence
        }
    }
}
