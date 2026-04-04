import Foundation
import SwiftData

@Model
final class MemoryFact {
    var id: UUID
    var profileID: UUID
    var key: String
    var value: String
    var source: String
    var confidence: Double
    var lastConfirmedAt: Date?

    init(
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

    func confirm(at date: Date = Date(), confidence: Double? = nil) {
        self.lastConfirmedAt = date
        if let confidence {
            self.confidence = confidence
        }
    }
}
