//
//  OpenAIExportService.swift
//  Memora
//
//  OpenAI エクスポート編成サービス
//  Memora の会議データを OpenAI Files API にアップロードする
//

import Foundation

final class OpenAIExportService {
    private let client: OpenAIFileClient

    /// OpenAI Files API の最大ファイルサイズ（512 MB）
    private let maxFileSizeBytes = 512 * 1024 * 1024

    init(apiKey: String) {
        self.client = OpenAIFileClient(apiKey: apiKey)
    }

    // MARK: - Single Meeting Export

    func exportMeeting(
        audioFile: AudioFile,
        transcript: Transcript?,
        format: OpenAIExportFormat,
        purpose: OpenAIFilePurpose
    ) async throws -> OpenAIFileUploadResult {
        let data = try generateContent(
            audioFile: audioFile,
            transcript: transcript,
            format: format
        )

        try validateSize(data)

        let filename = makeFilename(title: audioFile.title, format: format)
        return try await client.uploadFile(data: data, filename: filename, purpose: purpose)
    }

    // MARK: - Batch Export

    func exportMeetings(
        meetings: [(AudioFile, Transcript?)],
        format: OpenAIExportFormat,
        purpose: OpenAIFilePurpose
    ) async throws -> OpenAIFileUploadResult {
        guard !meetings.isEmpty else {
            throw OpenAIExportError.noDataToExport
        }

        let data = try generateBatchContent(meetings: meetings, format: format)
        try validateSize(data)

        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "memora_batch_\(timestamp).\(format == .json ? "json" : "md")"
        return try await client.uploadFile(data: data, filename: filename, purpose: purpose)
    }

    // MARK: - File Management

    func listExportedFiles() async throws -> [OpenAIFileUploadResult] {
        try await client.listFiles(purpose: .userData)
    }

    func deleteExportedFile(fileId: String) async throws -> Bool {
        try await client.deleteFile(fileId: fileId)
    }

    // MARK: - Content Generation

    private func generateContent(
        audioFile: AudioFile,
        transcript: Transcript?,
        format: OpenAIExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            return try generateJSON(audioFile: audioFile, transcript: transcript)
        case .markdown:
            return try generateMarkdown(audioFile: audioFile, transcript: transcript)
        }
    }

    private func generateBatchContent(
        meetings: [(AudioFile, Transcript?)],
        format: OpenAIExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            return try generateBatchJSON(meetings: meetings)
        case .markdown:
            return try generateBatchMarkdown(meetings: meetings)
        }
    }

    // MARK: - JSON Generation

    private func generateJSON(audioFile: AudioFile, transcript: Transcript?) throws -> Data {
        var meetingData: [String: Any] = [
            "title": audioFile.title,
            "createdAt": iso8601String(audioFile.createdAt),
            "duration": audioFile.duration
        ]

        if audioFile.isTranscribed, let transcript = transcript {
            meetingData["transcript"] = [
                "text": transcript.text,
                "createdAt": iso8601String(transcript.createdAt),
                "segments": makeSegmentsArray(transcript: transcript)
            ]
        }

        if audioFile.isSummarized,
           let summary = audioFile.summary,
           let keyPoints = audioFile.keyPoints,
           let actionItems = audioFile.actionItems {
            meetingData["summary"] = [
                "summary": summary,
                "keyPoints": keyPoints.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) },
                "actionItems": actionItems.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            ]
        }

        let exportData: [String: Any] = [
            "source": "Memora",
            "exportDate": iso8601String(Date()),
            "meeting": meetingData
        ]

        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted])
        } catch {
            throw OpenAIExportError.encodingFailed
        }
    }

    private func generateBatchJSON(meetings: [(AudioFile, Transcript?)]) throws -> Data {
        var meetingsArray: [[String: Any]] = []

        for (audioFile, transcript) in meetings {
            var meetingData: [String: Any] = [
                "title": audioFile.title,
                "createdAt": iso8601String(audioFile.createdAt),
                "duration": audioFile.duration
            ]

            if audioFile.isTranscribed, let transcript = transcript {
                meetingData["transcript"] = [
                    "text": transcript.text,
                    "createdAt": iso8601String(transcript.createdAt)
                ]
            }

            if audioFile.isSummarized,
               let summary = audioFile.summary,
               let keyPoints = audioFile.keyPoints,
               let actionItems = audioFile.actionItems {
                meetingData["summary"] = [
                    "summary": summary,
                    "keyPoints": keyPoints.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) },
                    "actionItems": actionItems.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                ]
            }

            meetingsArray.append(meetingData)
        }

        let exportData: [String: Any] = [
            "source": "Memora",
            "exportDate": iso8601String(Date()),
            "meetings": meetingsArray
        ]

        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted])
        } catch {
            throw OpenAIExportError.encodingFailed
        }
    }

    // MARK: - Markdown Generation

    private func generateMarkdown(audioFile: AudioFile, transcript: Transcript?) throws -> Data {
        var content = "---\n"
        content += "source: Memora\n"
        content += "export_date: \(formatDateForHeader(Date()))\n"
        content += "---\n\n"

        content += "# \(audioFile.title)\n\n"
        content += "**作成日:** \(formatDate(audioFile.createdAt))  \n"
        content += "**録音時間:** \(formatDuration(audioFile.duration))  \n\n"
        content += "---\n\n"

        if audioFile.isTranscribed, let transcript = transcript {
            content += "## 文字起こし\n\n"
            content += transcript.text
            content += "\n\n---\n\n"
        }

        if audioFile.isSummarized,
           let summary = audioFile.summary,
           let keyPoints = audioFile.keyPoints,
           let actionItems = audioFile.actionItems {
            content += "## 要約\n\n"
            content += "### 要約\n\n\(summary)\n\n"
            content += "### 要点\n\n\(keyPoints)\n\n"
            content += "### アクションアイテム\n\n\(actionItems)"
        }

        guard let data = content.data(using: .utf8) else {
            throw OpenAIExportError.encodingFailed
        }
        return data
    }

    private func generateBatchMarkdown(meetings: [(AudioFile, Transcript?)]) throws -> Data {
        var content = "---\n"
        content += "source: Memora\n"
        content += "export_date: \(formatDateForHeader(Date()))\n"
        content += "meeting_count: \(meetings.count)\n"
        content += "---\n\n"

        content += "# Memora 会議エクスポート\n\n"

        for (index, (audioFile, transcript)) in meetings.enumerated() {
            content += "## \(audioFile.title)\n\n"
            content += "**作成日:** \(formatDate(audioFile.createdAt))  \n"
            content += "**録音時間:** \(formatDuration(audioFile.duration))  \n\n"

            if audioFile.isTranscribed, let transcript = transcript {
                content += "### 文字起こし\n\n"
                content += transcript.text
                content += "\n\n"
            }

            if audioFile.isSummarized,
               let summary = audioFile.summary,
               let keyPoints = audioFile.keyPoints,
               let actionItems = audioFile.actionItems {
                content += "### 要約\n\n\(summary)\n\n"
                content += "### 要点\n\n\(keyPoints)\n\n"
                content += "### アクションアイテム\n\n\(actionItems)\n\n"
            }

            if index < meetings.count - 1 {
                content += "---\n\n"
            }
        }

        guard let data = content.data(using: .utf8) else {
            throw OpenAIExportError.encodingFailed
        }
        return data
    }

    // MARK: - Validation

    private func validateSize(_ data: Data) throws {
        guard data.count <= maxFileSizeBytes else {
            throw OpenAIExportError.fileTooLarge(maxBytes: maxFileSizeBytes)
        }
    }

    // MARK: - Filename

    private func makeFilename(title: String, format: OpenAIExportFormat) -> String {
        let sanitized = title
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .lowercased()

        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = format == .json ? "json" : "md"

        return "memora_\(sanitized)_\(timestamp).\(ext)"
    }

    // MARK: - Date Formatting

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func iso8601String(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.string(from: date)
    }

    private func makeSegmentsArray(transcript: Transcript) -> [[String: Any]] {
        var segments: [[String: Any]] = []
        let count = min(
            transcript.speakerLabels.count,
            transcript.segmentStartTimes.count,
            transcript.segmentEndTimes.count,
            transcript.segmentTexts.count
        )

        for i in 0..<count {
            segments.append([
                "speaker": transcript.speakerLabels[i],
                "start": transcript.segmentStartTimes[i],
                "end": transcript.segmentEndTimes[i],
                "text": transcript.segmentTexts[i]
            ])
        }

        return segments
    }
}
