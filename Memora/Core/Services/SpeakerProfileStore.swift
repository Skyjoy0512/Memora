import Foundation
import AVFoundation
import Accelerate

struct SpeakerVoiceFeatures: Codable, Sendable {
    let pitch: Double
    let energy: Double
    let zeroCrossingRate: Double
    let voicedRatio: Double

    static let fallback = SpeakerVoiceFeatures(
        pitch: 180,
        energy: 0.05,
        zeroCrossingRate: 0.08,
        voicedRatio: 0.2
    )

    static func average(_ features: [SpeakerVoiceFeatures]) -> SpeakerVoiceFeatures {
        guard !features.isEmpty else { return .fallback }

        let count = Double(features.count)
        return SpeakerVoiceFeatures(
            pitch: features.map(\.pitch).reduce(0, +) / count,
            energy: features.map(\.energy).reduce(0, +) / count,
            zeroCrossingRate: features.map(\.zeroCrossingRate).reduce(0, +) / count,
            voicedRatio: features.map(\.voicedRatio).reduce(0, +) / count
        )
    }

    func distance(to other: SpeakerVoiceFeatures) -> Double {
        let pitchDistance = min(abs(log((pitch + 1) / (other.pitch + 1))), 1.5) / 1.5
        let energyDistance = min(abs(energy - other.energy), 1.0)
        let zcrDistance = min(abs(zeroCrossingRate - other.zeroCrossingRate) * 2.5, 1.0)
        let voicedDistance = min(abs(voicedRatio - other.voicedRatio), 1.0)

        return (pitchDistance * 0.5)
            + (energyDistance * 0.2)
            + (zcrDistance * 0.2)
            + (voicedDistance * 0.1)
    }
}

struct SpeakerProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String
    var voiceFeatures: SpeakerVoiceFeatures
    var isPrimaryUser: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum SpeakerProfileStoreError: LocalizedError {
    case sampleTooShort
    case invalidAudio

    var errorDescription: String? {
        switch self {
        case .sampleTooShort:
            return "声サンプルが短すぎます。10秒以上の録音を使用してください。"
        case .invalidAudio:
            return "声サンプルの解析に失敗しました。"
        }
    }
}

final class SpeakerProfileStore {
    static let shared = SpeakerProfileStore()

    private let extractor = SpeakerVoiceFeatureExtractor()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadProfiles() -> [SpeakerProfile] {
        guard let url = try? profilesFileURL(),
              let data = try? Data(contentsOf: url),
              let profiles = try? decoder.decode([SpeakerProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    func registerPrimaryUserProfile(audioURL: URL, name: String = "自分") throws -> SpeakerProfile {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        guard duration >= 10 else {
            throw SpeakerProfileStoreError.sampleTooShort
        }

        let sampleSegment = TranscriptionSegment(
            id: "primary-speaker-sample",
            speakerLabel: name,
            startSec: 0,
            endSec: duration,
            text: name
        )

        let features = try extractor.extractRepresentativeFeatures(audioURL: audioURL, segments: [sampleSegment])
        guard features.voicedRatio > 0 else {
            throw SpeakerProfileStoreError.invalidAudio
        }

        var profiles = loadProfiles()
        let existingPrimaryProfile = profiles.first(where: { $0.isPrimaryUser })
        for index in profiles.indices {
            profiles[index].isPrimaryUser = false
        }

        let now = Date()
        let profile = SpeakerProfile(
            id: existingPrimaryProfile?.id ?? UUID(),
            displayName: name,
            voiceFeatures: features,
            isPrimaryUser: true,
            createdAt: existingPrimaryProfile?.createdAt ?? now,
            updatedAt: now
        )

        profiles.removeAll { $0.isPrimaryUser || $0.displayName == name }
        profiles.append(profile)
        try saveProfiles(profiles)
        return profile
    }

    private func saveProfiles(_ profiles: [SpeakerProfile]) throws {
        let url = try profilesFileURL()
        let data = try encoder.encode(profiles.sorted { $0.displayName < $1.displayName })
        try data.write(to: url, options: .atomic)
    }

    private func profilesFileURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("Memora", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        return directoryURL.appendingPathComponent("speaker_profiles.json")
    }
}

struct SpeakerVoiceFeatureExtractor {
    func extractRepresentativeFeatures(audioURL: URL, segments: [TranscriptionSegment]) throws -> SpeakerVoiceFeatures {
        SpeakerVoiceFeatures.average(try extractSegmentFeatures(audioURL: audioURL, segments: segments))
    }

    func extractSegmentFeatures(audioURL: URL, segments: [TranscriptionSegment]) throws -> [SpeakerVoiceFeatures] {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return Array(repeating: .fallback, count: segments.count)
        }

        try audioFile.read(into: buffer)

        return segments.map {
            extractFeatures(
                buffer: buffer,
                segment: $0,
                sampleRate: format.sampleRate
            ) ?? .fallback
        }
    }

    private func extractFeatures(
        buffer: AVAudioPCMBuffer,
        segment: TranscriptionSegment,
        sampleRate: Double
    ) -> SpeakerVoiceFeatures? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        let startFrame = max(0, Int(segment.startSec * sampleRate))
        let endFrame = min(Int(buffer.frameLength), Int(segment.endSec * sampleRate))
        let totalLength = endFrame - startFrame
        guard totalLength > 512 else { return nil }

        let frameSize = min(2048, totalLength)
        let hopSize = max(256, frameSize / 4)

        var pitches: [Double] = []
        var energies: [Double] = []
        var zcrs: [Double] = []
        var windows = 0

        for offset in stride(from: 0, to: totalLength - frameSize, by: hopSize) {
            let pointer = channelData.advanced(by: startFrame + offset)
            let length = frameSize

            if let pitch = autocorrelationPitch(data: pointer, length: length, sampleRate: sampleRate) {
                pitches.append(pitch)
            }
            energies.append(rmsEnergy(data: pointer, length: length))
            zcrs.append(zeroCrossingRate(data: pointer, length: length))
            windows += 1
        }

        let pitch = pitches.isEmpty ? SpeakerVoiceFeatures.fallback.pitch : pitches.reduce(0, +) / Double(pitches.count)
        let energy = energies.isEmpty ? SpeakerVoiceFeatures.fallback.energy : energies.reduce(0, +) / Double(energies.count)
        let zcr = zcrs.isEmpty ? SpeakerVoiceFeatures.fallback.zeroCrossingRate : zcrs.reduce(0, +) / Double(zcrs.count)
        let voicedRatio = windows == 0 ? 0 : Double(pitches.count) / Double(windows)

        return SpeakerVoiceFeatures(
            pitch: pitch,
            energy: energy,
            zeroCrossingRate: zcr,
            voicedRatio: voicedRatio
        )
    }

    private func rmsEnergy(data: UnsafePointer<Float>, length: Int) -> Double {
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(length))
        return Double(rms)
    }

    private func zeroCrossingRate(data: UnsafePointer<Float>, length: Int) -> Double {
        guard length > 1 else { return 0 }

        var crossings = 0
        for index in 1..<length {
            let previous = data[index - 1]
            let current = data[index]
            if (previous >= 0 && current < 0) || (previous < 0 && current >= 0) {
                crossings += 1
            }
        }
        return Double(crossings) / Double(length - 1)
    }

    private func autocorrelationPitch(
        data: UnsafePointer<Float>,
        length: Int,
        sampleRate: Double
    ) -> Double? {
        let minPeriod = Int(sampleRate / 420)
        let maxPeriod = Int(sampleRate / 70)
        guard length > maxPeriod else { return nil }

        var bestLag = minPeriod
        var bestCorrelation: Float = 0

        for lag in minPeriod..<maxPeriod {
            var sum: Float = 0
            for index in 0..<(length - lag) {
                sum += data[index] * data[index + lag]
            }

            if sum > bestCorrelation {
                bestCorrelation = sum
                bestLag = lag
            }
        }

        guard bestCorrelation > 0.05 else { return nil }
        return sampleRate / Double(bestLag)
    }
}
