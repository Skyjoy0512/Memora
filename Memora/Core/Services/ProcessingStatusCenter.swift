import Foundation
import Observation

/// ファイル単位の処理状態をアプリ全域へ通知する軽量レジストリ。
/// SwiftData には保存しない（プロセス内揮発）。永続的な失敗記録は ProcessingJob が担う。
@MainActor
@Observable
final class ProcessingStatusCenter {
    static let shared = ProcessingStatusCenter()

    enum Phase: Equatable {
        case transcribing(progress: Double)
        case summarizing(progress: Double)
        case failed(jobType: String)
    }

    private(set) var phases: [UUID: Phase] = [:]

    func setTranscribing(fileID: UUID, progress: Double) {
        phases[fileID] = .transcribing(progress: progress)
    }

    func setSummarizing(fileID: UUID, progress: Double) {
        phases[fileID] = .summarizing(progress: progress)
    }

    func setFailed(fileID: UUID, jobType: String) {
        phases[fileID] = .failed(jobType: jobType)
    }

    func clear(fileID: UUID) {
        phases.removeValue(forKey: fileID)
    }

    func phase(for fileID: UUID) -> Phase? { phases[fileID] }
}
