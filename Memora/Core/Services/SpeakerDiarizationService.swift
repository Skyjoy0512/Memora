import Foundation
import AVFoundation

/// 話者分離サービス（ローカル）
/// 複数の音響特徴を使って話者をクラスタリングし、登録済みプロフィール名にマッチします。
final class SpeakerDiarizationService: SpeakerDiarizationProtocol {
    private let featureExtractor = SpeakerVoiceFeatureExtractor()
    private let profileStore = SpeakerProfileStore.shared

    /// 音声ファイルから話者セグメントを生成
    func detectSpeakers(audioURL: URL, segments: [TranscriptionSegment]) async -> [TranscriptionSegment] {
        guard !segments.isEmpty else { return segments }

        do {
            let features = try featureExtractor.extractSegmentFeatures(audioURL: audioURL, segments: segments)
            let rawLabels = clusterSpeakers(features: features)
            let smoothedLabels = smoothLabels(rawLabels, segments: segments, features: features)
            let speakerLabels = resolveDisplayLabels(clusterLabels: smoothedLabels, features: features)

            return zip(segments, speakerLabels).map { segment, label in
                TranscriptionSegment(
                    id: segment.id,
                    speakerLabel: label,
                    startSec: segment.startSec,
                    endSec: segment.endSec,
                    text: segment.text
                )
            }
        } catch {
            print("話者分離エラー: \(error.localizedDescription)")
            return defaultSegments(for: segments)
        }
    }

    private func defaultSegments(for segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
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

    private func clusterSpeakers(features: [SpeakerVoiceFeatures]) -> [Int] {
        guard features.count > 1 else { return [0] }

        let maxSpeakers = min(3, features.count)
        let speakerCount = determineOptimalSpeakerCount(features: features, maxSpeakers: maxSpeakers)
        var centroids = initializeCentroids(features: features, count: speakerCount)

        for _ in 0..<12 {
            var clusters: [[SpeakerVoiceFeatures]] = Array(repeating: [], count: speakerCount)
            for feature in features {
                let closest = nearestCentroidIndex(for: feature, centroids: centroids)
                clusters[closest].append(feature)
            }

            let newCentroids = clusters.enumerated().map { index, cluster in
                cluster.isEmpty ? centroids[index] : SpeakerVoiceFeatures.average(cluster)
            }

            let converged = zip(centroids, newCentroids).allSatisfy { $0.distance(to: $1) < 0.03 }
            centroids = newCentroids
            if converged { break }
        }

        return features.map { nearestCentroidIndex(for: $0, centroids: centroids) }
    }

    private func smoothLabels(
        _ labels: [Int],
        segments: [TranscriptionSegment],
        features: [SpeakerVoiceFeatures]
    ) -> [Int] {
        guard labels.count >= 3 else { return labels }

        var result = labels
        for index in 1..<(labels.count - 1) {
            let duration = segments[index].endSec - segments[index].startSec
            let shortSegment = duration < 1.4 || segments[index].text.count < 18

            if shortSegment && result[index - 1] == result[index + 1] {
                result[index] = result[index - 1]
                continue
            }

            let isolated = result[index] != result[index - 1] && result[index] != result[index + 1]
            guard isolated else { continue }

            let previousDistance = features[index].distance(to: features[index - 1])
            let nextDistance = features[index].distance(to: features[index + 1])
            let bestNeighborDistance = min(previousDistance, nextDistance)

            if shortSegment || bestNeighborDistance < 0.18 {
                result[index] = previousDistance <= nextDistance ? result[index - 1] : result[index + 1]
            }
        }

        return result
    }

    private func resolveDisplayLabels(
        clusterLabels: [Int],
        features: [SpeakerVoiceFeatures]
    ) -> [String] {
        let profiles = profileStore.loadProfiles()
        let orderedClusters = clusterLabels.reduce(into: [Int]()) { partialResult, label in
            if !partialResult.contains(label) {
                partialResult.append(label)
            }
        }

        let clusterCentroids = Dictionary(uniqueKeysWithValues: orderedClusters.map { label in
            let clusterFeatures = zip(clusterLabels, features)
                .filter { $0.0 == label }
                .map(\.1)
            return (label, SpeakerVoiceFeatures.average(clusterFeatures))
        })

        var usedProfileIDs = Set<UUID>()
        var labelMap: [Int: String] = [:]
        var fallbackIndex = 1

        for cluster in orderedClusters {
            guard let centroid = clusterCentroids[cluster] else { continue }

            if let match = bestMatchingProfile(
                for: centroid,
                profiles: profiles,
                usedProfileIDs: usedProfileIDs
            ) {
                labelMap[cluster] = match.displayName
                usedProfileIDs.insert(match.id)
            } else {
                labelMap[cluster] = "Speaker \(fallbackIndex)"
                fallbackIndex += 1
            }
        }

        return clusterLabels.map { labelMap[$0] ?? "Speaker 1" }
    }

    private func bestMatchingProfile(
        for features: SpeakerVoiceFeatures,
        profiles: [SpeakerProfile],
        usedProfileIDs: Set<UUID>
    ) -> SpeakerProfile? {
        let candidates = profiles
            .filter { !usedProfileIDs.contains($0.id) }
            .map { profile in
                (profile: profile, distance: features.distance(to: profile.voiceFeatures))
            }
            .sorted { $0.distance < $1.distance }

        guard let best = candidates.first else { return nil }
        let threshold = best.profile.isPrimaryUser ? 0.24 : 0.18
        return best.distance <= threshold ? best.profile : nil
    }

    private func nearestCentroidIndex(
        for feature: SpeakerVoiceFeatures,
        centroids: [SpeakerVoiceFeatures]
    ) -> Int {
        centroids.enumerated().min { lhs, rhs in
            feature.distance(to: lhs.element) < feature.distance(to: rhs.element)
        }?.offset ?? 0
    }

    private func determineOptimalSpeakerCount(features: [SpeakerVoiceFeatures], maxSpeakers: Int) -> Int {
        guard features.count >= 2 else { return 1 }

        var bestK = 1
        var bestScore = Double.infinity

        for k in 1...maxSpeakers {
            let variance = calculateIntraClusterVariance(features: features, k: k)
            let penalty = Double(k - 1) * 0.12
            let score = variance + penalty

            if score < bestScore {
                bestScore = score
                bestK = k
            }
        }

        return bestK
    }

    private func calculateIntraClusterVariance(features: [SpeakerVoiceFeatures], k: Int) -> Double {
        var centroids = initializeCentroids(features: features, count: k)
        var clusters: [[SpeakerVoiceFeatures]] = Array(repeating: [], count: k)

        for feature in features {
            let closest = nearestCentroidIndex(for: feature, centroids: centroids)
            clusters[closest].append(feature)
        }

        var totalDistance = 0.0
        for (index, cluster) in clusters.enumerated() where !cluster.isEmpty {
            centroids[index] = SpeakerVoiceFeatures.average(cluster)
            totalDistance += cluster.map { $0.distance(to: centroids[index]) }.reduce(0, +) / Double(cluster.count)
        }

        return totalDistance / Double(max(k, 1))
    }

    private func initializeCentroids(features: [SpeakerVoiceFeatures], count: Int) -> [SpeakerVoiceFeatures] {
        guard count > 1 else {
            return [SpeakerVoiceFeatures.average(features)]
        }

        let sorted = features.sorted { $0.pitch < $1.pitch }
        let step = Double(sorted.count - 1) / Double(count - 1)

        var centroids: [SpeakerVoiceFeatures] = []
        for i in 0..<count {
            let idx = Int(Double(i) * step)
            centroids.append(sorted[idx])
        }

        return centroids
    }
}
