import Foundation
import SwiftData

@Model
final class Transcript {
    @Attribute(.unique) var id: UUID
    var audioFile: AudioFile?
    var fullText: String
    var language: String
    var speakerSegments: [SpeakerSegment]
    var createdAt: Date

    struct SpeakerSegment: Codable {
        var speakerLabel: String   // "Speaker 1" etc.
        var startSec: Double
        var endSec: Double
        var text: String
    }

    init(
        id: UUID = UUID(),
        fullText: String,
        language: String,
        speakerSegments: [SpeakerSegment] = []
    ) {
        self.id = id
        self.fullText = fullText
        self.language = language
        self.speakerSegments = speakerSegments
        self.createdAt = Date()
    }
}
