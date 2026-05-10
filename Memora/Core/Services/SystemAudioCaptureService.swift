import Foundation
import ReplayKit
import SwiftData

/// メインアプリ側のブロードキャスト管理サービス。
/// ReplayKit Broadcast Upload Extension と連携し、
/// システムオーディオのキャプチャ開始・停止・ファイル検出を行う。
@MainActor
@Observable
final class SystemAudioCaptureService {
    var isCaptureAvailable: Bool { true }
    private var isMonitoring = false
    private var monitorTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// ブロードキャスト開始用のシステムピッカーを表示する
    func requestBroadcastStart() {
        // RPSystemBroadcastPickerView は UIKit 経由で表示する必要がある
        // SwiftUI では UIViewRepresentable または UIViewControllerRepresentable でラップする
        // 実際の表示は MeetingCaptureSetupView で RPSystemBroadcastPickerView を配置して行う
        DebugLogger.shared.addLog("SystemAudioCapture", "Broadcast start requested", level: .info)
    }

    /// App Group 共有コンテナを監視し、新しい音声ファイルを検出する
    func startMonitoring() -> AsyncStream<CaptureFileEvent> {
        AsyncStream { continuation in
            monitorTask = Task {
                let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.memora.broadcast"
                )
                guard let containerURL else {
                    DebugLogger.shared.addLog(
                        "SystemAudioCapture",
                        "App Group container URL not available",
                        level: .error
                    )
                    continuation.finish()
                    return
                }

                let captureDir = containerURL.appendingPathComponent("Captures", isDirectory: true)
                try? FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)

                // 既存ファイルをチェック
                var knownFiles = Set<String>()
                if let existing = try? FileManager.default.contentsOfDirectory(atPath: captureDir.path) {
                    knownFiles = Set(existing)
                }

                isMonitoring = true

                while !Task.isCancelled && isMonitoring {
                    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: captureDir.path) else {
                        try? await Task.sleep(for: .seconds(2))
                        continue
                    }

                    let currentFiles = Set(contents)
                    let newFiles = currentFiles.subtracting(knownFiles)

                    for fileName in newFiles where fileName.hasSuffix(".m4a") {
                        let fileURL = captureDir.appendingPathComponent(fileName)
                        do {
                            let audioFile = try await importCapturedAudio(from: fileURL)
                            continuation.yield(.newCapture(audioFile: audioFile))
                        } catch {
                            DebugLogger.shared.addLog(
                                "SystemAudioCapture",
                                "Failed to import captured audio: \(error.localizedDescription)",
                                level: .error
                            )
                            continuation.yield(.importFailed(error))
                        }
                    }

                    knownFiles = currentFiles
                    try? await Task.sleep(for: .seconds(2))
                }

                continuation.finish()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// Broadcast Extension が書き出した音声ファイルを AudioFile としてインポートする
    private func importCapturedAudio(from sourceURL: URL) async throws -> AudioFile {
        guard let modelContext else {
            throw CaptureError.modelContextNotConfigured
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documentsDir.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let fileName = "meeting_capture_\(UUID().uuidString.prefix(8)).m4a"
        let destURL = audioDir.appendingPathComponent(fileName)

        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        try? FileManager.default.removeItem(at: sourceURL)

        let asset = AVAsset(url: destURL)
        let duration = asset.duration.seconds

        let audioFile = AudioFile(title: "会議キャプチャ \(formattedCurrentDate())", audioURL: destURL.path)
        audioFile.duration = duration.isFinite ? duration : 0
        audioFile.sourceType = .onlineMeeting

        modelContext.insert(audioFile)
        try modelContext.save()

        DebugLogger.shared.addLog(
            "SystemAudioCapture",
            "Imported captured audio: \(fileName), duration: \(duration)s",
            level: .info
        )

        return audioFile
    }

    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
    }

}

// MARK: - Capture File Event

enum CaptureFileEvent {
    case newCapture(audioFile: AudioFile)
    case importFailed(Error)
}

// MARK: - Capture Error

enum CaptureError: Error {
    case modelContextNotConfigured
}

// MARK: - RPSystemBroadcastPickerView Wrapper

import SwiftUI

/// ReplayKit のシステムブロードキャストピッカーを SwiftUI で表示するためのラッパー
struct SystemBroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = "com.memora.Memora.MemoraBroadcastExtension"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
