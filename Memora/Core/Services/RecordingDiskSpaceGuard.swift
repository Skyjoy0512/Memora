import Foundation

/// Disk thresholds are expressed in bytes so every recording entry point uses
/// the same policy. 500 MB warns early; 200 MB stops before a new five-minute
/// AAC segment can be opened and corrupted by a full volume.
enum RecordingDiskSpaceThresholds {
    static let warningBytes: Int64 = 500 * 1024 * 1024
    static let stopBytes: Int64 = 200 * 1024 * 1024
}

enum RecordingDiskSpaceDecision: Equatable {
    case sufficient
    case warning
    case stop

    var userMessage: String? {
        switch self {
        case .sufficient: nil
        case .warning:
            "空き容量が少なくなっています（500 MB未満）。録音を続けるには容量を確保してください。"
        case .stop:
            "空き容量が不足したため録音を安全に停止しました。確定済みの録音は保存されています。"
        }
    }
}

protocol RecordingDiskSpaceProviding {
    func availableBytes(for volumeURL: URL) -> Int64?
}

struct SystemRecordingDiskSpaceProvider: RecordingDiskSpaceProviding {
    func availableBytes(for volumeURL: URL) -> Int64? {
        guard let values = try? volumeURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) else {
            return nil
        }
        if let important = values.volumeAvailableCapacityForImportantUsage {
            return important
        }
        return values.volumeAvailableCapacity.map(Int64.init)
    }
}

struct RecordingDiskSpaceGuard {
    let provider: any RecordingDiskSpaceProviding

    init(provider: any RecordingDiskSpaceProviding = SystemRecordingDiskSpaceProvider()) {
        self.provider = provider
    }

    func decision(for volumeURL: URL) -> RecordingDiskSpaceDecision {
        guard let availableBytes = provider.availableBytes(for: volumeURL) else {
            // A capacity lookup failure must not discard an otherwise valid
            // recording. The recorder logs it and proceeds conservatively.
            return .sufficient
        }
        if availableBytes < RecordingDiskSpaceThresholds.stopBytes { return .stop }
        if availableBytes < RecordingDiskSpaceThresholds.warningBytes { return .warning }
        return .sufficient
    }
}
