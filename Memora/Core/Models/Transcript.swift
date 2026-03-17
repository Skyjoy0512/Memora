import Foundation
import SwiftData

@Model
final class Transcript {
    var id: UUID
    var audioFileID: UUID
    var text: String
    var createdAt: Date
    var speakers: [SpeakerSegment]

    init(audioFileID: UUID, text: String) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.text = text
        self.createdAt = Date()
        self.speakers = []
    }
}

@Model
final class SpeakerSegment {
    var speakerID: String
    var speakerLabel: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String

    init(speakerLabel: String, startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.speakerID = UUID().uuidString
        self.speakerLabel = speakerLabel
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}
