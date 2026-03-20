import Foundation
import AVFoundation

// MARK: - Audio Settings Constants

/// 共有のオーディオフォーマット設定
/// 文字起こしエンジンとの統一のため、16kHz mono PCM 16-bit を使用
enum AudioSettings {
    /// 推奨オーディオフォーマット（16kHz mono PCM 16-bit）
    static let preferredFormat: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]
}

// MARK: - Audio Recorder Protocol

protocol AudioRecorderProtocol {
    var isRecording: Bool { get }
    var recordingTime: TimeInterval { get }
    func startRecording() throws
    func stopRecording() throws -> URL
    func cancelRecording()
}

// MARK: - Audio Recorder Implementation

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
                options: [.allowBluetoothA2DP, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
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
        let timestamp = Date().timeIntervalSince1970
        let filename = "recording_\(timestamp).m4a"  // M4A形式は16-bit PCM をサポート

        recordingURL = documentsURL.appendingPathComponent(filename)

        // 共有フォーマット設定を使用
        let settings = AudioSettings.preferredFormat

        print("AudioRecorder: AVAudioRecorderを作成: \(recordingURL!.path)")
        print("  - サンプルレート: 16000Hz")
        print("  - チャンネル数: 1 (mono)")
        print("  - ビット深度: 16-bit")
        print("  - フォーマット: Linear PCM")

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
        print("AudioRecorder: 録音停止")
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
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }

    enum RecordingError: Error, LocalizedError {
        case noRecording
        case audioSessionFailed

        var errorDescription: String? {
            switch self {
            case .noRecording:
                return "録音が開始されていません"
            case .audioSessionFailed:
                return "オーディオセッションの設定に失敗しました"
            }
        }
    }
}
