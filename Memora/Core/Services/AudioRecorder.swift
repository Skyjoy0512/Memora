import Foundation
import AVFoundation
import Observation

struct RecordingResult: Sendable {
    let fileID: UUID
    let fileURL: URL
    let duration: TimeInterval
}

@MainActor
protocol AudioRecorderProtocol: Sendable {
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var recordingTime: TimeInterval { get }

    func startRecording() throws
    func stopRecording() throws -> URL
    func cancelRecording()
    func pauseRecording()
    func resumeRecording()

    func startRecording() async throws
    func stopRecording() async throws -> RecordingResult
    func audioLevels() -> AsyncStream<Float>
}

@MainActor
@Observable
final class AudioRecorder: NSObject, AudioRecorderProtocol {
    var isRecording = false
    var isPaused = false
    var recordingTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingFileID: UUID?
    private var levelContinuations: [UUID: AsyncStream<Float>.Continuation] = [:]
    private var meteringTimer: Timer?
    private var shouldResumeAfterInterruption = false

    override init() {
        super.init()
        observeAudioSessionNotifications()
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            NotificationCenter.default.removeObserver(self)
            meteringTimer?.invalidate()
            meteringTimer = nil

            for continuation in levelContinuations.values {
                continuation.finish()
            }
            levelContinuations.removeAll()
        }
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
        isPaused = false
        shouldResumeAfterInterruption = false
        stopMetering()
        finishAudioLevels()
    }

    func pauseRecording() {
        guard let recorder, isRecording, !isPaused else { return }
        recorder.pause()
        isPaused = true
        meteringTimer?.invalidate()
        meteringTimer = nil
        DebugLogger.shared.addLog("AudioRecorder", "録音を一時停止しました", level: .info)
    }

    func resumeRecording() {
        resumeRecordingAfterSessionActivation(reason: "手動再開")
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
            try configureRecordingSession(session)
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
            isPaused = false
            recordingTime = 0
            startMetering()
            DebugLogger.shared.addLog("AudioRecorder", "録音を開始しました", level: .info)
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
        isPaused = false
        shouldResumeAfterInterruption = false

        // MainActor.run を使用して非同期にクリーンアップ
        Task { @MainActor [weak self] in
            self?.stopMetering()
            self?.finishAudioLevels()
        }

        return RecordingResult(fileID: recordingFileID, fileURL: recordingURL, duration: duration)
    }

    private func startMetering() {
        stopMetering()
        meteringTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(handleMeteringTimer), userInfo: nil, repeats: true)
    }

    private func stopMetering() {
        pauseMetering()
        recordingTime = 0
    }

    private func pauseMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func finishAudioLevels() {
        for continuation in levelContinuations.values {
            continuation.finish()
        }
        levelContinuations.removeAll()
    }

    private func observeAudioSessionNotifications() {
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    @objc
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            DebugLogger.shared.addLog("AudioRecorder", "オーディオ割込み通知を解析できませんでした", level: .warning)
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isRecording && !isPaused
            guard shouldResumeAfterInterruption else {
                DebugLogger.shared.addLog("AudioRecorder", "オーディオ割込み開始 — 録音は既に一時停止中または未開始です", level: .info)
                return
            }
            pauseRecording()
            DebugLogger.shared.addLog("AudioRecorder", "オーディオ割込み開始 — 録音を安全に一時停止しました", level: .warning)

        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            let shouldResume = shouldResumeAfterInterruption
            shouldResumeAfterInterruption = false

            guard shouldResume else {
                DebugLogger.shared.addLog("AudioRecorder", "オーディオ割込み終了 — 自動再開対象ではありません", level: .info)
                return
            }
            guard options.contains(.shouldResume) else {
                DebugLogger.shared.addLog("AudioRecorder", "オーディオ割込み終了 — システムが再開を許可しないため一時停止状態を維持します", level: .warning)
                return
            }
            resumeRecordingAfterSessionActivation(reason: "オーディオ割込み終了")

        @unknown default:
            DebugLogger.shared.addLog("AudioRecorder", "未知のオーディオ割込み種別を受信しました", level: .warning)
        }
    }

    @objc
    private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            DebugLogger.shared.addLog("AudioRecorder", "オーディオ経路変更通知を解析できませんでした", level: .warning)
            return
        }

        guard isRecording else { return }

        switch reason {
        case .oldDeviceUnavailable:
            DebugLogger.shared.addLog("AudioRecorder", "オーディオ経路変更 — 接続中の入力装置が利用不可になりました。録音継続を復旧します", level: .warning)
            restoreRecordingAfterRouteChange(reason: "旧デバイス切断")
        case .newDeviceAvailable, .routeConfigurationChange:
            DebugLogger.shared.addLog("AudioRecorder", "オーディオ経路変更 — 新しい入力経路を再構成します", level: .info)
            restoreRecordingAfterRouteChange(reason: "入力経路変更")
        default:
            DebugLogger.shared.addLog("AudioRecorder", "オーディオ経路変更（\(reason.rawValue)）を検出しました", level: .info)
        }
    }

    private func restoreRecordingAfterRouteChange(reason: String) {
        guard let recorder else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !isPaused && !recorder.isRecording {
                guard recorder.record() else {
                    recorder.pause()
                    isPaused = true
                    pauseMetering()
                    DebugLogger.shared.addLog("AudioRecorder", "\(reason)後の録音再開に失敗しました。安全に一時停止状態を維持します", level: .error)
                    return
                }
                startMetering()
            }
            DebugLogger.shared.addLog("AudioRecorder", "\(reason)後も録音状態を維持しました", level: .info)
        } catch {
            recorder.pause()
            isPaused = true
            pauseMetering()
            DebugLogger.shared.addLog("AudioRecorder", "\(reason)後のオーディオセッション再構成に失敗しました。安全に一時停止状態を維持します: \(error.localizedDescription)", level: .error)
        }
    }

    private func resumeRecordingAfterSessionActivation(reason: String) {
        guard let recorder, isRecording, isPaused else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            guard recorder.record() else {
                DebugLogger.shared.addLog("AudioRecorder", "\(reason)に失敗しました。録音は一時停止状態のままです", level: .error)
                return
            }
            isPaused = false
            startMetering()
            DebugLogger.shared.addLog("AudioRecorder", "\(reason) — 録音を再開しました", level: .info)
        } catch {
            DebugLogger.shared.addLog("AudioRecorder", "\(reason)前のオーディオセッション有効化に失敗しました。録音は一時停止状態のままです: \(error.localizedDescription)", level: .error)
        }
    }

    private func configureRecordingSession(_ session: AVAudioSession) throws {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
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
