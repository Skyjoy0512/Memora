import Foundation
import Observation

@MainActor
@Observable
final class RecordingViewModel {
    @ObservationIgnored
    private var audioFileRepository: AudioFileRepositoryProtocol?

    var isRecording = false
    var recordingTime: TimeInterval = 0
    var recordingTitle = ""
    var errorMessage: String?

    func configure(audioFileRepository: AudioFileRepositoryProtocol?) {
        guard self.audioFileRepository == nil else { return }
        self.audioFileRepository = audioFileRepository
    }

    func startRecording() {
        isRecording = true
        recordingTime = 0
        errorMessage = nil
    }

    func stopRecording() {
        isRecording = false
    }

    func cancelRecording() {
        isRecording = false
        recordingTime = 0
        recordingTitle = ""
        errorMessage = nil
    }

    func saveRecording(
        title: String,
        fileURL: URL,
        duration: TimeInterval,
        projectID: UUID?
    ) -> AudioFile? {
        guard let audioFileRepository else {
            errorMessage = "保存先が初期化されていません"
            return nil
        }

        let audioFile = AudioFile(
            title: title,
            audioURL: fileURL.path,
            projectID: projectID
        )
        audioFile.duration = duration

        do {
            try audioFileRepository.save(audioFile)
            recordingTitle = title
            errorMessage = nil
            return audioFile
        } catch {
            errorMessage = "保存エラー: \(error.localizedDescription)"
            return nil
        }
    }
}
