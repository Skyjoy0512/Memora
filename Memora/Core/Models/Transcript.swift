import Foundation
import SwiftData

@Model
final class Transcript {
    var id: UUID
    var audioFileID: UUID
    var text: String
    var createdAt: Date
    var speakerLabels: [String] = []
    var segmentStartTimes: [Double] = []
    var segmentEndTimes: [Double] = []
    var segmentTexts: [String] = []

    init(audioFileID: UUID, text: String) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.text = text
        self.createdAt = Date()
        self.speakerLabels = []
        self.segmentStartTimes = []
        self.segmentEndTimes = []
        self.segmentTexts = []
    }

    /// スピーカーセグメントを追加するヘルパーメソッド
    func addSpeakerSegment(speakerLabel: String, startTime: Double, endTime: Double, text: String) {
        speakerLabels.append(speakerLabel)
        segmentStartTimes.append(startTime)
        segmentEndTimes.append(endTime)
        segmentTexts.append(text)
    }
}
