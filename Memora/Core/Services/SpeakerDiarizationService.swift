import Foundation
import AVFoundation
import Accelerate

/// 話者分離サービス（ローカル）
/// 音声のピッチ（基本周波数）を分析して簡易的に話者を分離します
final class SpeakerDiarizationService: SpeakerDiarizationProtocol {
    /// 音声ファイルから話者セグメントを生成
    func detectSpeakers(audioURL: URL, segments: [TranscriptionSegment]) async -> [TranscriptionSegment] {
        guard !segments.isEmpty else { return segments }

        do {
            // 音声ファイルを読み込む
            let audioFile = try AVAudioFile(forReading: audioURL)
            let audioFormat = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)

            // バッファを確保
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
                return segments.map { segment in
                    TranscriptionSegment(
                        id: segment.id,
                        speakerLabel: "Speaker 1",
                        startSec: segment.startSec,
                        endSec: segment.endSec,
                        text: segment.text
                    )
                }
            }

            try audioFile.read(into: buffer)

            // 各セグメントの代表ピッチを取得
            var segmentPitches: [Double] = []
            for segment in segments {
                let startFrame = Int64(segment.startSec * audioFormat.sampleRate)
                let endFrame = Int64(segment.endSec * audioFormat.sampleRate)
                let length = AVAudioFrameCount(endFrame - startFrame)

                guard length > 0, Int64(length) + startFrame <= frameCount else {
                    segmentPitches.append(200.0) // デフォルト値
                    continue
                }

                // セグメント部分のピッチを計算
                if let pitch = calculatePitch(
                    buffer: buffer,
                    channel: 0,
                    startFrame: startFrame,
                    length: length,
                    sampleRate: audioFormat.sampleRate
                ) {
                    segmentPitches.append(pitch)
                } else {
                    segmentPitches.append(200.0)
                }
            }

            // ピッチを基準に話者をクラスタリング
            let speakerLabels = clusterSpeakers(pitches: segmentPitches)

            // セグメントに話者ラベルを割り当て
            return zip(segments, speakerLabels).map { segment, label in
                TranscriptionSegment(
                    id: segment.id,
                    speakerLabel: "Speaker \(label)",
                    startSec: segment.startSec,
                    endSec: segment.endSec,
                    text: segment.text
                )
            }
        } catch {
            print("話者分離エラー: \(error.localizedDescription)")
            return segments.map { segment in
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

    /// ピッチを計算（自己相関法）
    private func calculatePitch(
        buffer: AVAudioPCMBuffer,
        channel: Int,
        startFrame: Int64,
        length: AVAudioFrameCount,
        sampleRate: Double
    ) -> Double? {
        guard channel < buffer.format.channelCount, length > 0 else { return nil }

        let data = buffer.floatChannelData![channel]
        let startIdx = Int(startFrame)
        let frameLength = Int(length)

        // フレーム全体の平均ピッチを計算
        var pitchSum = 0.0
        var pitchCount = 0

        let frameSize = 2048 // 分析フレームサイズ
        let hopSize = 512

        for i in stride(from: 0, to: frameLength, by: hopSize) {
            let end = min(i + frameSize, frameLength)
            let subLength = end - i

            guard subLength > 100 else { continue } // 十分な長さが必要

            if let pitch = autocorrelationPitch(
                data: data.advanced(by: startIdx + i),
                length: subLength,
                sampleRate: sampleRate
            ) {
                pitchSum += pitch
                pitchCount += 1
            }
        }

        guard pitchCount > 0 else { return nil }
        return pitchSum / Double(pitchCount)
    }

    /// 自己相関法によるピッチ抽出
    private func autocorrelationPitch(
        data: UnsafePointer<Float>,
        length: Int,
        sampleRate: Double
    ) -> Double? {
        let minPeriod = Int(sampleRate / 500) // 最低 500Hz
        let maxPeriod = Int(sampleRate / 50)  // 最高 50Hz

        guard length > maxPeriod else { return nil }

        // 自己相関を計算
        var correlation: [Float] = Array(repeating: 0, count: maxPeriod)

        for lag in minPeriod..<maxPeriod {
            var sum: Float = 0
            for i in 0..<(length - lag) {
                sum += data[i] * data[i + lag]
            }
            correlation[lag] = sum
        }

        // 最大相関値を見つける
        var bestLag = minPeriod
        var maxCorrelation = correlation[minPeriod]

        for lag in (minPeriod + 1)..<maxPeriod {
            if correlation[lag] > maxCorrelation {
                maxCorrelation = correlation[lag]
                bestLag = lag
            }
        }

        // 相関が低い場合は有効なピッチとみなさない
        guard maxCorrelation > 0.1 else { return nil }

        // ピッチを計算
        return Double(sampleRate) / Double(bestLag)
    }

    /// K-means クラスタリングで話者を分類
    private func clusterSpeakers(pitches: [Double]) -> [Int] {
        guard pitches.count > 1 else { return [1] }

        // 最大3人まで話者を検出
        let maxSpeakers = min(3, pitches.count)
        let speakerCount = determineOptimalSpeakerCount(pitches: pitches, maxSpeakers: maxSpeakers)

        // K-means クラスタリング
        var centroids = initializeCentroids(pitches: pitches, count: speakerCount)

        for _ in 0..<10 { // 最大10回イテレーション
            var clusters: [[Double]] = Array(repeating: [], count: speakerCount)

            // 各ピッチを最も近いセントロイドに割り当て
            for pitch in pitches {
                var minDist = Double.infinity
                var closestCluster = 0

                for (idx, centroid) in centroids.enumerated() {
                    let dist = abs(pitch - centroid)
                    if dist < minDist {
                        minDist = dist
                        closestCluster = idx
                    }
                }

                clusters[closestCluster].append(pitch)
            }

            // セントロイドを更新
            var newCentroids: [Double] = []
            for cluster in clusters {
                if cluster.isEmpty {
                    newCentroids.append(centroids[newCentroids.count])
                } else {
                    newCentroids.append(cluster.reduce(0, +) / Double(cluster.count))
                }
            }

            // 収束判定
            let converged = zip(centroids, newCentroids).allSatisfy { abs($0 - $1) < 1.0 }
            centroids = newCentroids
            if converged { break }
        }

        // 各ピッチのクラスタを返す
        var labels: [Int] = []
        for pitch in pitches {
            var minDist = Double.infinity
            var closestCluster = 0

            for (idx, centroid) in centroids.enumerated() {
                let dist = abs(pitch - centroid)
                if dist < minDist {
                    minDist = dist
                    closestCluster = idx
                }
            }

            labels.append(closestCluster + 1) // 1始まり
        }

        return labels
    }

    /// 最適な話者数を決定（エルボー法）
    private func determineOptimalSpeakerCount(pitches: [Double], maxSpeakers: Int) -> Int {
        guard pitches.count >= 2 else { return 1 }

        var bestK = 1
        var bestScore = Double.infinity

        for k in 1...maxSpeakers {
            let variance = calculateIntraClusterVariance(pitches: pitches, k: k)
            let penalty = Double(k) * 100.0 // クラスタ数のペナルティ
            let score = variance + penalty

            if score < bestScore {
                bestScore = score
                bestK = k
            }
        }

        return bestK
    }

    /// クラスタ内分散を計算
    private func calculateIntraClusterVariance(pitches: [Double], k: Int) -> Double {
        var centroids = initializeCentroids(pitches: pitches, count: k)
        var clusters: [[Double]] = Array(repeating: [], count: k)

        for pitch in pitches {
            var minDist = Double.infinity
            var closestCluster = 0

            for (idx, centroid) in centroids.enumerated() {
                let dist = abs(pitch - centroid)
                if dist < minDist {
                    minDist = dist
                    closestCluster = idx
                }
            }

            clusters[closestCluster].append(pitch)
        }

        var totalVariance = 0.0
        for cluster in clusters {
            if let mean = cluster.first, !cluster.isEmpty {
                let variance = cluster.map { pow($0 - mean, 2) }.reduce(0, +) / Double(cluster.count)
                totalVariance += variance
            }
        }

        return totalVariance
    }

    /// セントロイドの初期化
    private func initializeCentroids(pitches: [Double], count: Int) -> [Double] {
        guard count > 1 else {
            return [pitches.reduce(0, +) / Double(pitches.count)]
        }

        let sorted = pitches.sorted()
        let step = Double(sorted.count - 1) / Double(count - 1)

        var centroids: [Double] = []
        for i in 0..<count {
            let idx = Int(Double(i) * step)
            centroids.append(sorted[idx])
        }

        return centroids
    }
}
