import Foundation
@preconcurrency import AVFoundation
import Observation

@MainActor
protocol AudioPlayerProtocol: Sendable {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    func load(url: URL) async throws
    func play() async
    func play(url: URL) throws
    func pause()
    func pause() async
    func stop()
    func seek(to time: TimeInterval)
    func seek(to time: TimeInterval) async
    func playbackProgress() -> AsyncStream<TimeInterval>
}

@MainActor
@Observable
final class AudioPlayer: NSObject, AudioPlayerProtocol {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    private var audioPlayer: AVAudioPlayer?
    private var loadedURL: URL?
    private var progressContinuations: [UUID: AsyncStream<TimeInterval>.Continuation] = [:]
    private var progressTask: Task<Void, Never>?

    override init() {
        super.init()
    }

    deinit {
        let task = progressTask
        Task { @MainActor in
            task?.cancel()
        }
    }

    func load(url: URL) async throws {
        try loadPlayer(url: url)
    }

    func play(url: URL) throws {
        try loadPlayer(url: url)
        playLoadedPlayer()
    }

    func play() async {
        playLoadedPlayer()
    }

    func pause() {
        pauseCore()
    }

    func pause() async {
        pauseCore()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopProgressTimer()
        yieldProgress(currentTime)
    }

    func cleanup() {
        stop()
        stopProgressTimer()
        progressContinuations.removeAll()
    }

    func seek(to time: TimeInterval) {
        seekCore(to: time)
    }

    func seek(to time: TimeInterval) async {
        seekCore(to: time)
    }

    func playbackProgress() -> AsyncStream<TimeInterval> {
        AsyncStream { continuation in
            let id = UUID()
            progressContinuations[id] = continuation
            continuation.yield(currentTime)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.progressContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func loadPlayer(url: URL) throws {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()

            audioPlayer = player
            loadedURL = url
            duration = player.duration
            currentTime = player.currentTime
            isPlaying = false
            yieldProgress(currentTime)
        } catch {
            throw CoreError.audioError(.playbackFailed(error.localizedDescription))
        }
    }

    private func playLoadedPlayer() {
        guard let player = audioPlayer ?? loadedURL.flatMap({ try? AVAudioPlayer(contentsOf: $0) }) else {
            return
        }

        if audioPlayer == nil {
            audioPlayer = player
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            duration = player.duration
        }

        audioPlayer?.play()
        isPlaying = true
        startProgressTimer()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.audioPlayer, player.isPlaying else { break }
                self.currentTime = player.currentTime
                self.yieldProgress(player.currentTime)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopProgressTimer() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func pauseCore() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    private func seekCore(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        audioPlayer?.currentTime = clamped
        currentTime = clamped
        yieldProgress(clamped)
    }

    private func yieldProgress(_ value: TimeInterval) {
        for continuation in progressContinuations.values {
            continuation.yield(value)
        }
    }

        currentTime = player.currentTime
        yieldProgress(currentTime)
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handlePlaybackFinished()
        }
    }
}

@MainActor
private extension AudioPlayer {
    func handlePlaybackFinished() {
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
        yieldProgress(currentTime)
    }
}
