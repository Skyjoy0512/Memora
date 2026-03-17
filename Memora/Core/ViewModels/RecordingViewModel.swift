import Foundation
import Observation

@Observable
final class RecordingViewModel {
    var isRecording = false
    var recordingTime: TimeInterval = 0
    var recordingTitle = ""

    func startRecording() {
        isRecording = true
        recordingTime = 0
        // TODO: 実際の録音処理
    }

    func stopRecording() {
        isRecording = false
        // TODO: 録音を停止して保存
    }

    func cancelRecording() {
        isRecording = false
        recordingTime = 0
        recordingTitle = ""
    }
}
