import AVFoundation
import Foundation

/// Presents an `AudioFile` as one playable/transcribable URL without changing
/// the existing one-file audio consumers. V3 and imported records have no
/// segment paths and therefore retain their original URL unchanged.
@MainActor
enum SegmentedAudioFileResolver {
    enum Error: LocalizedError {
        case missingAudio
        case missingSegment(URL)
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .missingAudio: "音声ファイルがありません"
            case .missingSegment(let url): "録音セグメントが見つかりません: \(url.lastPathComponent)"
            case .exportFailed: "録音セグメントの連結に失敗しました"
            }
        }
    }

    static func resolve(_ audioFile: AudioFile) async throws -> URL {
        let segmentURLs = audioFile.segmentPaths.map(URL.init(fileURLWithPath:))
        guard !segmentURLs.isEmpty else {
            return try primaryURL(audioFile.audioURL)
        }
        guard segmentURLs.count > 1 else { return segmentURLs[0] }
        for url in segmentURLs where !FileManager.default.fileExists(atPath: url.path) {
            throw Error.missingSegment(url)
        }

        let cacheDirectory = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Memora/SegmentCompositions", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let outputURL = cacheDirectory.appendingPathComponent("\(audioFile.id.uuidString).m4a")
        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()
        guard let destination = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Error.exportFailed
        }
        var insertionTime = CMTime.zero
        for url in segmentURLs {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let source = tracks.first else { throw Error.missingSegment(url) }
            let duration = try await asset.load(.duration)
            try destination.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: insertionTime)
            insertionTime = CMTimeAdd(insertionTime, duration)
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw Error.exportFailed
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously { continuation.resume() }
        }
        guard exporter.status == .completed else { throw exporter.error ?? Error.exportFailed }
        return outputURL
    }

    private static func primaryURL(_ path: String) throws -> URL {
        guard !path.isEmpty else { throw Error.missingAudio }
        if path.hasPrefix("file://"), let url = URL(string: path) { return url }
        return URL(fileURLWithPath: path)
    }
}
