import Foundation

/// 話者分離プロトコル
protocol SpeakerDiarizationProtocol {
    func detectSpeakers(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int?
    ) async -> [TranscriptionSegment]
}
