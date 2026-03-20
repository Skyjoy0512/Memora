import Foundation
import AVFoundation

struct RecordingResult: Sendable {
    let fileID: UUID
    let fileURL: URL
    let duration: TimeInterval
}

@MainActor
protocol AudioRecorderProtocol: Sendable {
    var isRecording: Bool { get }
    var recordingTime: TimeInterval { get }

    func startRecording() throws
    func stopRecording() throws -> URL
    func cancelRecording()

    func startRecording() async throws
    func stopRecording() async throws -> RecordingResult
    func audioLevels() -> AsyncStream<Float>
}

@MainActor
final class AudioRecorder: NSObject, AudioRecorderProtocol, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingFileID: UUID?
    private var levelContinuations: [UUID: AsyncStream<Float>.Continuation] = [:]
    private var meteringTimer: Timer?

    deinit {
        stopMetering()
        finishAudioLevels()
    }

    func startRecording() throws {
        try startRecordingCore()
    }

    func startRecording() async throws {
        let granted = try await requestMicrophonePermissionIfNeeded()
        guard granted else {
            throw RecordingError.microphonePermissionDenied
        }

        try startRecordingCore()
    }

    func stopRecording() throws -> URL {
        try stopRecordingCore().fileURL
    }

    func stopRecording() async throws -> RecordingResult {
        try stopRecordingCore()
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        recordingURL = nil
        recordingFileID = nil
        isRecording = false
        stopMetering()
        finishAudioLevels()
    }

    func audioLevels() -> AsyncStream<Float> {
        AsyncStream { continuation in
            let id = UUID()
            levelContinuations[id] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.levelContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func startRecordingCore() throws {
        let session = AVAudioSession.sharedInstance()

        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            throw RecordingError.microphonePermissionDenied
        case .undetermined, .granted:
            break
        @unknown default:
            break
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw RecordingError.audioSessionFailed(error)
        }

        let fileID = UUID()
        let fileURL = try STTFileLocations.audioDirectory()
            .appendingPathComponent("\(fileID.uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.isMeteringEnabled = true

            guard recorder.record() else {
                throw RecordingError.recordingFailed()
            }

            self.recorder = recorder
            recordingURL = fileURL
            recordingFileID = fileID
            isRecording = true
            recordingTime = 0
            startMetering()
        } catch let error as RecordingError {
            throw error
        } catch {
            throw RecordingError.recordingFailed(error)
        }
    }

    private func stopRecordingCore() throws -> RecordingResult {
        guard let recorder, let recordingURL, let recordingFileID else {
            throw RecordingError.noActiveRecording
        }

        recorder.stop()
        let duration = recorder.currentTime

        self.recorder = nil
        self.recordingURL = nil
        self.recordingFileID = nil
        isRecording = false
        stopMetering()
        finishAudioLevels()

        return RecordingResult(fileID: recordingFileID, fileURL: recordingURL, duration: duration)
    }

    private func startMetering() {
        stopMetering()
        meteringTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(handleMeteringTimer), userInfo: nil, repeats: true)
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        recordingTime = 0
    }

    private func finishAudioLevels() {
        for continuation in levelContinuations.values {
            continuation.finish()
        }
        levelContinuations.removeAll()
    }

    private func requestMicrophonePermissionIfNeeded() async throws -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    @objc
    private func handleMeteringTimer() {
        guard let recorder else { return }

        recorder.updateMeters()
        recordingTime = recorder.currentTime

        let averagePower = recorder.averagePower(forChannel: 0)
        let linearLevel = max(0, powf(10, averagePower / 20))
        for continuation in levelContinuations.values {
            continuation.yield(linearLevel)
        }
    }

    enum RecordingError: LocalizedError {
        case noActiveRecording
        case microphonePermissionDenied
        case audioSessionFailed(Error)
        case recordingFailed(Error? = nil)

        var errorDescription: String? {
            switch self {
            case .noActiveRecording:
                return "録音が開始されていません"
            case .microphonePermissionDenied:
                return "マイクへのアクセスが許可されていません"
            case .audioSessionFailed(let error):
                return "オーディオセッションの設定に失敗しました: \(error.localizedDescription)"
            case .recordingFailed(let error):
                if let error {
                    return "録音に失敗しました: \(error.localizedDescription)"
                }
                return "録音に失敗しました"
            }
        }
    }
}
