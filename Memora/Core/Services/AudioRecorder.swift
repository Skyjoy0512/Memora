import Foundation
import AVFoundation

protocol AudioRecorderProtocol {
    var isRecording: Bool { get }
    var recordingTime: TimeInterval { get }
    func startRecording() throws
    func stopRecording() throws -> URL
    func cancelRecording()
}

final class AudioRecorder: AudioRecorderProtocol, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .record,
                mode: .default,
                options: []
            )
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func startRecording() throws {
        print("AudioRecorder: 録音開始をリクエスト")

        let session = AVAudioSession.sharedInstance()
        do {
            print("AudioRecorder: AudioSessionをアクティブ化")
            try session.setActive(true)
        } catch {
            print("AudioRecorder: AudioSessionのアクティブ化に失敗: \(error)")
            throw RecordingError.audioSessionFailed
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = documentsURL.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        print("AudioRecorder: AVAudioRecorderを作成: \(recordingURL!.path)")
        audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)

        if let recorder = audioRecorder {
            print("AudioRecorder: 録音開始")
            recorder.record()
            isRecording = true
            startTimer()
            print("AudioRecorder: 録音中 \(recorder.isRecording)")
        } else {
            print("AudioRecorder: recorderがnil")
            throw RecordingError.noRecording
        }
    }

    func stopRecording() throws -> URL {
        guard let url = recordingURL else {
            throw RecordingError.noRecording
        }

        audioRecorder?.stop()
        isRecording = false
        stopTimer()

        return url
    }

    func cancelRecording() {
        audioRecorder?.stop()
        isRecording = false
        stopTimer()

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }

    enum RecordingError: Error {
        case noRecording
        case audioSessionFailed
    }
}
