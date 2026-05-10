import Foundation
import FluidAudio

/// FluidAudio（CoreML / ANE）ベースの話者分離サービス。
/// Pyannote Community-1 + VBx クラスタリングでオンデバイス高速推論を行う。
///
/// ダイアライゼーション結果のタイムスタンプを主構造とし、STTテキストを比例配分する。
/// SpeechAnalyzer のように単語タイムスタンプがない場合でも正確に話者を分離できる。
@available(macOS 14.0, iOS 17.0, *)
final class FluidAudioDiarizationService: SpeakerDiarizationProtocol {

    /// クラスタリング設定: 閾値を下げて話者分離を積極化。
    /// デフォルト 0.6 は類似声をマージしすぎるため 0.38 に調整。
    /// Fa/Fb は pyannote community-1 のデフォルト値を維持（VBx の発散を防ぐ）。
    private let manager: OfflineDiarizerManager = {
        var config = OfflineDiarizerConfig()
        config.clustering.threshold = 0.38
        config.clustering.minSpeakers = 1
        return OfflineDiarizerManager(config: config)
    }()

    private var isPrepared = false
    private var speakerCountManagers: [Int: OfflineDiarizerManager] = [:]
    private var preparedSpeakerCounts = Set<Int>()

    func detectSpeakers(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int? = nil
    ) async -> [TranscriptionSegment] {
        guard !segments.isEmpty else { return segments }

        do {
            // numSpeakers が指定されていれば専用の manager を構築
            let effectiveManager: OfflineDiarizerManager
            if let numSpeakers {
                effectiveManager = manager(forSpeakerCount: numSpeakers)
                if !preparedSpeakerCounts.contains(numSpeakers) {
                    STTConsoleLog("[Diarization] numSpeakers=\(numSpeakers) 指定 — 専用 manager prepare 開始")
                    DebugLogger.shared.addLog("Diarization", "numSpeakers=\(numSpeakers) 指定 — 専用 manager prepare 開始", level: .info)
                    try await effectiveManager.prepareModels()
                    preparedSpeakerCounts.insert(numSpeakers)
                }
            } else {
                if !isPrepared {
                    STTConsoleLog("[Diarization] FluidAudio model prepare 開始")
                    DebugLogger.shared.addLog("Diarization", "FluidAudio model prepare 開始", level: .info)
                    try await manager.prepareModels()
                    isPrepared = true
                    STTConsoleLog("[Diarization] FluidAudio model prepare 完了")
                    DebugLogger.shared.addLog("Diarization", "FluidAudio model prepare 完了", level: .info)
                }
                effectiveManager = manager
            }

            STTConsoleLog("[Diarization] 話者分離開始 — \(audioURL.lastPathComponent)")
            DebugLogger.shared.addLog("Diarization", "話者分離開始 — \(audioURL.lastPathComponent)", level: .info)
            let result = try await effectiveManager.process(audioURL)
            STTConsoleLog("[Diarization] 話者分離完了 — \(result.segments.count)セグメント, スピーカー: \(Set(result.segments.map(\.speakerId)).sorted())")
            DebugLogger.shared.addLog("Diarization", "話者分離完了 — \(result.segments.count)セグメント", level: .info)

            let built = buildSegmentsFromDiarization(
                diarizationSegments: result.segments,
                sttSegments: segments
            )
            STTConsoleLog("[Diarization] セグメント再構築完了 — \(built.count)セグメント, ラベル: \(built.map(\.speakerLabel))")
            return built

        } catch {
            STTConsoleLog("[Diarization] ★ FluidAudio エラー: \(error)")
            DebugLogger.shared.addLog("Diarization", "FluidAudio エラー: \(error.localizedDescription)", level: .error)
            return fallbackSegments(for: segments)
        }
    }

    private func manager(forSpeakerCount speakerCount: Int) -> OfflineDiarizerManager {
        if let manager = speakerCountManagers[speakerCount] {
            return manager
        }

        var config = OfflineDiarizerConfig()
        config.clustering.threshold = 0.38
        config.clustering.numSpeakers = speakerCount
        let manager = OfflineDiarizerManager(config: config)
        speakerCountManagers[speakerCount] = manager
        return manager
    }

    // MARK: - Diarization-First Segment Building

    /// 連続する同じ話者のセグメントを1つのターンにマージする内部型。
    private struct SpeakerTurn {
        let speakerId: String
        var startTimeSeconds: Float
        var endTimeSeconds: Float
        var durationSeconds: Float { endTimeSeconds - startTimeSeconds }
    }

    /// ダイアライゼーション結果を主構造としてセグメントを再構築する。
    ///
    /// 流れ:
    /// 1. 連続同一話者セグメントをターンにマージ
    /// 2. 全テキスト行を抽出
    /// 3. 各ターンの発話時間割合に応じてテキスト行数を配分（最低1行保証）
    /// 4. テキスト行を順序通りターンに割り当て
    private func buildSegmentsFromDiarization(
        diarizationSegments: [TimedSpeakerSegment],
        sttSegments: [TranscriptionSegment]
    ) -> [TranscriptionSegment] {
        guard !diarizationSegments.isEmpty else {
            return fallbackSegments(for: sttSegments)
        }

        let textLines = sttSegments.map(\.text).filter { !$0.isEmpty }
        guard !textLines.isEmpty else {
            return fallbackSegments(for: sttSegments)
        }

        // 1. 連続同一話者をマージ
        let turns = mergeIntoTurns(diarizationSegments)
        let speakerIds = Set(turns.map(\.speakerId)).sorted()
        DebugLogger.shared.addLog("Diarization", "話者ターン数: \(turns.count), スピーカー: \(speakerIds)", level: .info)

        if canAssignByTime(sttSegments) {
            let timeAssigned = assignSegmentsByTimeOverlap(sttSegments: sttSegments, turns: turns)
            if !timeAssigned.isEmpty {
                DebugLogger.shared.addLog("Diarization", "時刻 overlap によるセグメント割当完了 — \(timeAssigned.count)セグメント", level: .info)
                return timeAssigned
            }
        }

        // 2. 時間比例でテキスト行数を配分
        let allocation = allocateLines(to: turns, totalLines: textLines.count)

        STTConsoleLog("[Diarization] 行数配分: \(allocation.map { "\($0.speakerId)=\($0.lineCount)行" }.joined(separator: ", "))")

        // 3. 順序通りテキストを割り当ててセグメント構築
        var result: [TranscriptionSegment] = []
        var lineIndex = 0

        for entry in allocation {
            guard entry.lineCount > 0 else { continue }
            let endIndex = min(lineIndex + entry.lineCount, textLines.count)
            guard lineIndex < endIndex else { continue }

            let lines = Array(textLines[lineIndex..<endIndex])
            result.append(TranscriptionSegment(
                id: "diarized-\(result.count)",
                speakerLabel: entry.speakerId,
                startSec: Double(entry.startSeconds),
                endSec: Double(entry.endSeconds),
                text: lines.joined(separator: "\n")
            ))
            lineIndex = endIndex
        }

        // 余った行があれば最後のセグメントに追加
        if lineIndex < textLines.count, let last = result.last {
            let remaining = textLines[lineIndex...].joined(separator: "\n")
            result[result.count - 1] = TranscriptionSegment(
                id: last.id,
                speakerLabel: last.speakerLabel,
                startSec: last.startSec,
                endSec: last.endSec,
                text: last.text + "\n" + remaining
            )
        }

        DebugLogger.shared.addLog("Diarization", "セグメント再構築完了 — \(result.count)セグメント", level: .info)
        return result.isEmpty ? fallbackSegments(for: sttSegments) : result
    }

    private func canAssignByTime(_ segments: [TranscriptionSegment]) -> Bool {
        let timedSegments = segments.filter { $0.endSec > $0.startSec && !$0.text.isEmpty }
        return timedSegments.count >= 2
    }

    private func assignSegmentsByTimeOverlap(
        sttSegments: [TranscriptionSegment],
        turns: [SpeakerTurn]
    ) -> [TranscriptionSegment] {
        guard !turns.isEmpty else { return [] }

        let assigned = sttSegments.compactMap { segment -> TranscriptionSegment? in
            guard !segment.text.isEmpty else { return nil }
            let bestTurn = bestOverlappingTurn(for: segment, turns: turns)
            let speakerId = bestTurn?.speakerId ?? nearestTurn(to: segment, turns: turns).speakerId
            return TranscriptionSegment(
                id: segment.id,
                speakerLabel: speakerId,
                startSec: segment.startSec,
                endSec: segment.endSec,
                text: segment.text
            )
        }

        return mergeAdjacentSpeakerSegments(assigned)
    }

    private func bestOverlappingTurn(
        for segment: TranscriptionSegment,
        turns: [SpeakerTurn]
    ) -> SpeakerTurn? {
        turns
            .map { turn in
                (turn: turn, overlap: overlapSeconds(segment: segment, turn: turn))
            }
            .filter { $0.overlap > 0 }
            .max { $0.overlap < $1.overlap }?
            .turn
    }

    private func nearestTurn(
        to segment: TranscriptionSegment,
        turns: [SpeakerTurn]
    ) -> SpeakerTurn {
        let midpoint = (segment.startSec + segment.endSec) / 2
        return turns.min { lhs, rhs in
            distance(from: midpoint, to: lhs) < distance(from: midpoint, to: rhs)
        } ?? turns[0]
    }

    private func overlapSeconds(segment: TranscriptionSegment, turn: SpeakerTurn) -> Double {
        let start = max(segment.startSec, Double(turn.startTimeSeconds))
        let end = min(segment.endSec, Double(turn.endTimeSeconds))
        return max(0, end - start)
    }

    private func distance(from time: Double, to turn: SpeakerTurn) -> Double {
        if time < Double(turn.startTimeSeconds) {
            return Double(turn.startTimeSeconds) - time
        }
        if time > Double(turn.endTimeSeconds) {
            return time - Double(turn.endTimeSeconds)
        }
        return 0
    }

    private func mergeAdjacentSpeakerSegments(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        guard let first = segments.first else { return [] }

        var result: [TranscriptionSegment] = []
        var current = first

        for segment in segments.dropFirst() {
            let sameSpeaker = segment.speakerLabel == current.speakerLabel
            let closeInTime = segment.startSec - current.endSec <= 1.0
            if sameSpeaker && closeInTime {
                current = TranscriptionSegment(
                    id: current.id,
                    speakerLabel: current.speakerLabel,
                    startSec: current.startSec,
                    endSec: max(current.endSec, segment.endSec),
                    text: [current.text, segment.text]
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                )
            } else {
                result.append(current)
                current = segment
            }
        }

        result.append(current)
        return result
    }

    /// 各ターンに配分するテキスト行数を計算する。
    /// 発話時間に比例して配分し、各ターンに最低1行を保証する。
    private func allocateLines(
        to turns: [SpeakerTurn],
        totalLines: Int
    ) -> [(speakerId: String, lineCount: Int, startSeconds: Float, endSeconds: Float)] {
        guard !turns.isEmpty else { return [] }

        let totalDuration = turns.reduce(Float(0)) { $0 + $1.durationSeconds }
        guard totalDuration > 0 else {
            // 全ターン同一行数で均等配分
            let perTurn = max(1, totalLines / turns.count)
            return turns.map { (speakerId: $0.speakerId, lineCount: perTurn, startSeconds: $0.startTimeSeconds, endSeconds: $0.endTimeSeconds) }
        }

        // 比例配分（floor）+ 最低1行保証
        var allocations = turns.map { turn -> Int in
            let proportion = Float(turn.durationSeconds) / totalDuration
            return max(1, Int(floor(proportion * Float(totalLines))))
        }

        // 配分合計が totalLines を超える場合は最大配分から減らす
        while allocations.reduce(0, +) > totalLines {
            if let maxIdx = allocations.indices.max(by: { allocations[$0] < allocations[$1] }) {
                allocations[maxIdx] = max(1, allocations[maxIdx] - 1)
            } else {
                break
            }
        }

        // 残りを行数の多いターンに順次追加
        var remaining = totalLines - allocations.reduce(0, +)
        while remaining > 0 {
            // 最も行数が少ない（＝実際の発話時間に対してテキストが少ない）ターンに優先追加
            if let minIdx = allocations.indices.min(by: { allocations[$0] > allocations[$1] }) {
                allocations[minIdx] += 1
            } else {
                allocations[0] += 1
            }
            remaining -= 1
        }

        return zip(turns, allocations).map { turn, count in
            (speakerId: turn.speakerId, lineCount: count, startSeconds: turn.startTimeSeconds, endSeconds: turn.endTimeSeconds)
        }
    }

    /// 連続する同一話者セグメントを1つのターンにマージ。
    private func mergeIntoTurns(_ segments: [TimedSpeakerSegment]) -> [SpeakerTurn] {
        guard let first = segments.first else { return [] }

        var turns: [SpeakerTurn] = []
        var current = SpeakerTurn(
            speakerId: first.speakerId,
            startTimeSeconds: first.startTimeSeconds,
            endTimeSeconds: first.endTimeSeconds
        )

        for segment in segments.dropFirst() {
            if segment.speakerId == current.speakerId {
                current.endTimeSeconds = segment.endTimeSeconds
            } else {
                turns.append(current)
                current = SpeakerTurn(
                    speakerId: segment.speakerId,
                    startTimeSeconds: segment.startTimeSeconds,
                    endTimeSeconds: segment.endTimeSeconds
                )
            }
        }
        turns.append(current)

        return turns
    }

    private func fallbackSegments(for segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        segments.map { segment in
            TranscriptionSegment(
                id: segment.id,
                speakerLabel: "Speaker 1",
                startSec: segment.startSec,
                endSec: segment.endSec,
                text: segment.text
            )
        }
    }
}
