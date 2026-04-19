import Foundation
import SwiftData

@MainActor
enum PlaudImportService {

    /// 音声ファイル + オプションのメタデータJSON を同時インポート
    static func importFromExport(
        audioURL: URL,
        metadataURL: URL?,
        modelContext: ModelContext
    ) throws -> AudioFile {
        let metadata = parseMetadata(at: metadataURL)

        let suggestedTitle = metadata?.title
            ?? audioURL.deletingPathExtension().lastPathComponent

        let audioFile = try AudioFileImportService.importAudio(
            from: audioURL,
            suggestedTitle: suggestedTitle,
            modelContext: modelContext,
            requiresSecurityScopedAccess: true
        )

        audioFile.sourceTypeRaw = SourceType.plaud.rawValue

        if let transcript = metadata?.transcript, !transcript.isEmpty {
            audioFile.referenceTranscript = transcript
            if let count = extractSpeakerCount(from: transcript) {
                audioFile.referenceSpeakerCount = count
            }
        }
        if let summary = metadata?.summary, !summary.isEmpty {
            audioFile.summary = summary
            audioFile.isSummarized = true
        }
        if let duration = metadata?.duration, duration > 0 {
            audioFile.duration = duration
        }
        if let createdAt = metadata?.createdAt {
            audioFile.createdAt = createdAt
        }

        try modelContext.save()
        return audioFile
    }

    /// テキストファイルのみ（音声なし）を参照データとしてインポート
    static func importTextOnly(
        title: String,
        textContent: String,
        modelContext: ModelContext
    ) -> AudioFile {
        let audioFile = AudioFile(title: title, audioURL: "")
        audioFile.sourceTypeRaw = SourceType.plaud.rawValue
        audioFile.referenceTranscript = textContent
        audioFile.duration = 0

        modelContext.insert(audioFile)
        try? modelContext.save()
        return audioFile
    }

    /// 既存 AudioFile に参照文字起こしを付与
    static func attachReferenceTranscript(
        _ audioFile: AudioFile,
        text: String,
        modelContext: ModelContext
    ) {
        audioFile.referenceTranscript = text
        audioFile.sourceTypeRaw = SourceType.plaud.rawValue
        if let count = extractSpeakerCount(from: text) {
            audioFile.referenceSpeakerCount = count
        }
        try? modelContext.save()
    }

    /// Plaud テキストから話者数を抽出する。
    /// 対応形式: "Speaker 1:", "00:00:00 Speaker 1", "Speaker 1"
    static func extractSpeakerCount(from text: String) -> Int? {
        var speakers = Set<String>()
        for line in text.components(separatedBy: .newlines) {
            if let range = line.range(of: "Speaker \\d+", options: .regularExpression) {
                speakers.insert(String(line[range]))
            }
        }
        return speakers.isEmpty ? nil : speakers.count
    }

    // MARK: - Private

    private static func parseMetadata(at url: URL?) -> PlaudExportFile? {
        guard let url else { return nil }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlaudExportFile.self, from: data)
    }
}
