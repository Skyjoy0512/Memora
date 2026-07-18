import Foundation
import Testing
@testable import Memora

@Suite("録音ディスク残量ガード")
struct RecordingDiskSpaceGuardTests {
    private let volumeURL = URL(fileURLWithPath: "/tmp/memora-recording-volume")

    @Test("停止閾値未満では録音開始を拒否する")
    func rejectsStartBelowStopThreshold() {
        let guarder = RecordingDiskSpaceGuard(
            provider: FixedDiskSpaceProvider(bytes: RecordingDiskSpaceThresholds.stopBytes - 1)
        )

        #expect(guarder.decision(for: volumeURL) == .stop)
    }

    @Test("警告閾値未満かつ停止閾値以上では録音を継続する")
    func warnsBetweenThresholds() {
        let guarder = RecordingDiskSpaceGuard(
            provider: FixedDiskSpaceProvider(bytes: RecordingDiskSpaceThresholds.warningBytes - 1)
        )

        #expect(guarder.decision(for: volumeURL) == .warning)
    }

    @Test("十分な空き容量では通常録音を許可する")
    func allowsStartWithSufficientCapacity() {
        let guarder = RecordingDiskSpaceGuard(
            provider: FixedDiskSpaceProvider(bytes: RecordingDiskSpaceThresholds.warningBytes)
        )

        #expect(guarder.decision(for: volumeURL) == .sufficient)
    }
}

private struct FixedDiskSpaceProvider: RecordingDiskSpaceProviding {
    let bytes: Int64?
    func availableBytes(for volumeURL: URL) -> Int64? { bytes }
}
