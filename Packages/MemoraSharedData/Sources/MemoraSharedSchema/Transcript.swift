import Foundation
import SwiftData

@Model
public final class Transcript {
    public var id: UUID
    public var audioFileID: UUID
    public var audioFile: AudioFile?
    public var text: String
    public var createdAt: Date
    public var speakerLabels: [String] = []
    public var segmentStartTimes: [Double] = []
    public var segmentEndTimes: [Double] = []
    public var segmentTexts: [String] = []
    public var cleanedText: String?
    public var cleanedSegmentTexts: [String] = []

    public init(audioFileID: UUID, text: String) {
        self.id = UUID()
        self.audioFileID = audioFileID
        self.text = text
        self.createdAt = Date()
        self.speakerLabels = []
        self.segmentStartTimes = []
        self.segmentEndTimes = []
        self.segmentTexts = []
        self.cleanedText = nil
        self.cleanedSegmentTexts = []
    }

    /// スピーカーセグメントを追加するヘルパーメソッド
    public func addSpeakerSegment(speakerLabel: String, startTime: Double, endTime: Double, text: String) {
        speakerLabels.append(speakerLabel)
        segmentStartTimes.append(startTime)
        segmentEndTimes.append(endTime)
        segmentTexts.append(text)
    }

    public func replaceSpeakerSegments(
        speakerLabels: [String],
        startTimes: [Double],
        endTimes: [Double],
        texts: [String]
    ) {
        self.speakerLabels = speakerLabels
        segmentStartTimes = startTimes
        segmentEndTimes = endTimes
        segmentTexts = texts
    }
}
