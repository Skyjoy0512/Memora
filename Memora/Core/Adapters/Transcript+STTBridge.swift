import Foundation

/// Host-only conversion between the shared persistence model and STT UI DTOs.
/// Keeping this extension in the app target prevents the schema package from
/// depending on the protected STT implementation.
extension Transcript {
    func replaceSpeakerSegments(_ segments: [SpeakerSegment]) {
        replaceSpeakerSegments(
            speakerLabels: segments.map(\.speakerLabel),
            startTimes: segments.map(\.startTime),
            endTimes: segments.map(\.endTime),
            texts: segments.map(\.text)
        )
    }
}
