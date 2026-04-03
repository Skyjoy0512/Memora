import Foundation
import SwiftData
import AVFoundation

@MainActor
enum AudioFileImportService {
    static func importAudio(
        from sourceURL: URL,
        suggestedTitle: String? = nil,
        repositoryFactory: RepositoryFactory? = nil,
        modelContext: ModelContext,
        requiresSecurityScopedAccess: Bool = false
    ) throws -> AudioFile {
        let didStartAccessing: Bool
        if requiresSecurityScopedAccess {
            didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
            guard didStartAccessing else {
                throw CocoaError(.fileReadNoPermission)
            }
        } else {
            didStartAccessing = false
        }

        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sourceTitle = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = sourceTitle?.isEmpty == false
            ? sourceTitle!
            : sourceURL.deletingPathExtension().lastPathComponent

        let fileExtension = sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension
        let destinationName = "\(resolvedTitle)_\(UUID().uuidString.prefix(8)).\(fileExtension)"
        let destinationURL = documentsDir.appendingPathComponent(destinationName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let asset = AVAsset(url: destinationURL)
        let duration = CMTimeGetSeconds(asset.duration)

        let audioFile = AudioFile(title: resolvedTitle, audioURL: destinationURL.path)
        audioFile.duration = duration.isFinite ? duration : 0

        if let repositoryFactory {
            try repositoryFactory.audioFileRepo.save(audioFile)
        } else {
            modelContext.insert(audioFile)
            try modelContext.save()
        }

        return audioFile
    }
}
