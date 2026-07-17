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

    /// A draft is written before the first segment is complete. During
    /// recording we persist only closed segments, which bounds crash loss to
    /// the current segment.
    func beginSegmentedRecording(fileURL: URL, projectID: UUID?) -> AudioFile? {
        guard let audioFileRepository else {
            errorMessage = "保存先が初期化されていません"
            return nil
        }
        let audioFile = AudioFile(title: "録音中", audioURL: fileURL.path, projectID: projectID)
        do {
            try audioFileRepository.save(audioFile)
            return audioFile
        } catch {
            errorMessage = "保存エラー: \(error.localizedDescription)"
            return nil
        }
    }

    func persistCompletedSegments(_ paths: [URL], duration: TimeInterval, for audioFile: AudioFile) {
        guard let audioFileRepository else { return }
        audioFile.segmentPaths = paths.map(\.path)
        audioFile.duration = duration
        do { try audioFileRepository.save(audioFile) }
        catch { errorMessage = "保存エラー: \(error.localizedDescription)" }
    }

    func finishSegmentedRecording(_ result: RecordingResult, title: String, for audioFile: AudioFile) -> AudioFile? {
        guard let audioFileRepository else { return nil }
        audioFile.title = title
        audioFile.audioURL = result.fileURL.path
        audioFile.segmentPaths = result.segmentURLs.map(\.path)
        audioFile.duration = result.duration
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

    func discardSegmentedRecording(_ audioFile: AudioFile?) {
        guard let audioFile, let audioFileRepository else { return }
        try? audioFileRepository.delete(audioFile)
    }
}
