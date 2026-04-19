import Foundation

/// エクスポート形式
enum ExportFormat: String, CaseIterable {
    case txt = "TXT"
    case markdown = "Markdown"
    case json = "JSON"
    case srt = "SRT"
    case vtt = "VTT"
}

/// エクスポート種別
enum ExportType: String, CaseIterable {
    case transcript = "文字起こし"
    case summary = "要約"
    case all = "すべて"
}

/// エクスポートサービス
final class ExportService {
    /// 文字起こしをエクスポート
    func exportTranscript(
        transcript: Transcript,
        format: ExportFormat,
        audioFile: AudioFile
    ) throws -> URL {
        switch format {
        case .txt:
            return try exportTranscriptAsTXT(
                transcript: transcript,
                audioFile: audioFile
            )
        case .markdown:
            return try exportTranscriptAsMarkdown(
                transcript: transcript,
                audioFile: audioFile
            )
        case .json:
            return try exportTranscriptAsJSON(
                transcript: transcript,
                audioFile: audioFile
            )
        case .srt:
            return try exportTranscriptAsSRT(
                transcript: transcript,
                audioFile: audioFile
            )
        case .vtt:
            return try exportTranscriptAsVTT(
                transcript: transcript,
                audioFile: audioFile
            )
        }
    }

    /// 要約をエクスポート
    func exportSummary(
        audioFile: AudioFile,
        format: ExportFormat
    ) throws -> URL {
        guard audioFile.isSummarized,
              let summary = audioFile.summary,
              let keyPoints = audioFile.keyPoints,
              let actionItems = audioFile.actionItems else {
            throw ExportError.noData
        }

        switch format {
        case .txt:
            return try exportSummaryAsTXT(
                audioFile: audioFile,
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
            )
        case .markdown:
            return try exportSummaryAsMarkdown(
                audioFile: audioFile,
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
            )
        case .json:
            return try exportSummaryAsJSON(
                audioFile: audioFile,
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
            )
        case .srt, .vtt:
            // SRT/VTT は要約に対応していないため TXT にフォールバック
            return try exportSummaryAsTXT(
                audioFile: audioFile,
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
            )
        }
    }

    /// すべて（文字起こし + 要約 + メモ + タスク）をエクスポート
    func exportAll(
        transcript: Transcript?,
        audioFile: AudioFile,
        format: ExportFormat,
        memoText: String? = nil,
        todoItems: [TodoItem] = []
    ) throws -> URL {
        switch format {
        case .txt:
            return try exportAllAsTXT(
                transcript: transcript,
                audioFile: audioFile,
                memoText: memoText,
                todoItems: todoItems
            )
        case .markdown:
            return try exportAllAsMarkdown(
                transcript: transcript,
                audioFile: audioFile,
                memoText: memoText,
                todoItems: todoItems
            )
        case .json:
            return try exportAllAsJSON(
                transcript: transcript,
                audioFile: audioFile,
                memoText: memoText,
                todoItems: todoItems
            )
        case .srt:
            guard let transcript = transcript else {
                throw ExportError.noData
            }
            return try exportTranscriptAsSRT(
                transcript: transcript,
                audioFile: audioFile
            )
        case .vtt:
            guard let transcript = transcript else {
                throw ExportError.noData
            }
            return try exportTranscriptAsVTT(
                transcript: transcript,
                audioFile: audioFile
            )
        }
    }

    // MARK: - TXT エクスポート

    private func exportTranscriptAsTXT(
        transcript: Transcript,
        audioFile: AudioFile
    ) throws -> URL {
        var content = "# \(audioFile.title)\n"
        content += "# 作成日: \(formatDate(audioFile.createdAt))\n"
        content += "# 録音時間: \(formatDuration(audioFile.duration))\n\n"
        content += transcript.text

        return try saveToFile(content: content, extension: "txt")
    }

    private func exportSummaryAsTXT(
        audioFile: AudioFile,
        summary: String,
        keyPoints: String,
        actionItems: String
    ) throws -> URL {
        var content = "# \(audioFile.title) - 要約\n"
        content += "# 作成日: \(formatDate(audioFile.createdAt))\n\n"
        content += "【要約】\n\(summary)\n\n"
        content += "【要点】\n\(keyPoints)\n\n"
        content += "【アクションアイテム】\n\(actionItems)"

        return try saveToFile(content: content, extension: "txt")
    }

    private func exportAllAsTXT(
        transcript: Transcript?,
        audioFile: AudioFile,
        memoText: String?,
        todoItems: [TodoItem]
    ) throws -> URL {
        var content = "# \(audioFile.title)\n"
        content += "# 作成日: \(formatDate(audioFile.createdAt))\n"
        content += "# 録音時間: \(formatDuration(audioFile.duration))\n\n"

        if audioFile.isTranscribed, let transcript = transcript {
            content += "## 文字起こし\n\n"
            content += transcript.text
            content += "\n\n"
        }

        if audioFile.isSummarized,
           let summary = audioFile.summary,
           let keyPoints = audioFile.keyPoints,
           let actionItems = audioFile.actionItems {
            content += "## 要約\n\n"
            content += "### 要約\n\(summary)\n\n"
            content += "### 要点\n\(keyPoints)\n\n"
            content += "### アクションアイテム\n\(actionItems)\n\n"
        }

        if let memoText, !memoText.isEmpty {
            content += "## メモ\n\n\(memoText)\n\n"
        }

        if !todoItems.isEmpty {
            content += "## タスク\n\n"
            for todo in todoItems {
                let check = todo.isCompleted ? "[x]" : "[ ]"
                content += "- \(check) \(todo.title)\n"
            }
        }

        return try saveToFile(content: content, extension: "txt")
    }

    // MARK: - Markdown エクスポート

    private func exportTranscriptAsMarkdown(
        transcript: Transcript,
        audioFile: AudioFile
    ) throws -> URL {
        var content = "# \(audioFile.title)\n\n"
        content += "**作成日:** \(formatDate(audioFile.createdAt))  \n"
        content += "**録音時間:** \(formatDuration(audioFile.duration))\n\n"
        content += "---\n\n"
        content += transcript.text

        return try saveToFile(content: content, extension: "md")
    }

    private func exportSummaryAsMarkdown(
        audioFile: AudioFile,
        summary: String,
        keyPoints: String,
        actionItems: String
    ) throws -> URL {
        var content = "# \(audioFile.title) - 要約\n\n"
        content += "**作成日:** \(formatDate(audioFile.createdAt))  \n\n"
        content += "---\n\n"
        content += "## 要約\n\n\(summary)\n\n"
        content += "## 要点\n\n\(keyPoints)\n\n"
        content += "## アクションアイテム\n\n\(actionItems)"

        return try saveToFile(content: content, extension: "md")
    }

    private func exportAllAsMarkdown(
        transcript: Transcript?,
        audioFile: AudioFile,
        memoText: String?,
        todoItems: [TodoItem]
    ) throws -> URL {
        var content = "# \(audioFile.title)\n\n"
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
            content += "### アクションアイテム\n\n\(actionItems)\n\n"
        }

        if let memoText, !memoText.isEmpty {
            content += "## メモ\n\n\(memoText)\n\n"
        }

        if !todoItems.isEmpty {
            content += "## タスク\n\n"
            for todo in todoItems {
                let check = todo.isCompleted ? "x" : " "
                content += "- [\(check)] \(todo.title)\n"
            }
        }

        return try saveToFile(content: content, extension: "md")
    }

    // MARK: - JSON エクスポート

    private func exportTranscriptAsJSON(
        transcript: Transcript,
        audioFile: AudioFile
    ) throws -> URL {
        let data: [String: Any] = [
            "title": audioFile.title,
            "createdAt": Self.iso8601Formatter.string(from: audioFile.createdAt),
            "duration": audioFile.duration,
            "transcript": [
                "text": transcript.text,
                "createdAt": Self.iso8601Formatter.string(from: transcript.createdAt),
                "segments": makeSegmentsJSON(transcript: transcript)
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted])
        return try saveToFile(data: jsonData, extension: "json")
    }

    private func exportSummaryAsJSON(
        audioFile: AudioFile,
        summary: String,
        keyPoints: String,
        actionItems: String
    ) throws -> URL {
        let data: [String: Any] = [
            "title": audioFile.title,
            "createdAt": Self.iso8601Formatter.string(from: audioFile.createdAt),
            "duration": audioFile.duration,
            "summary": [
                "summary": summary,
                "keyPoints": keyPoints.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) },
                "actionItems": actionItems.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted])
        return try saveToFile(data: jsonData, extension: "json")
    }

    private func exportAllAsJSON(
        transcript: Transcript?,
        audioFile: AudioFile,
        memoText: String?,
        todoItems: [TodoItem]
    ) throws -> URL {
        var data: [String: Any] = [
            "title": audioFile.title,
            "createdAt": Self.iso8601Formatter.string(from: audioFile.createdAt),
            "duration": audioFile.duration
        ]

        if audioFile.isTranscribed, let transcript = transcript {
            data["transcript"] = [
                "text": transcript.text,
                "createdAt": Self.iso8601Formatter.string(from: transcript.createdAt)
            ]
        }

        if audioFile.isSummarized,
           let summary = audioFile.summary,
           let keyPoints = audioFile.keyPoints,
           let actionItems = audioFile.actionItems {
            data["summary"] = [
                "summary": summary,
                "keyPoints": keyPoints.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) },
                "actionItems": actionItems.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            ]
        }

        if let memoText, !memoText.isEmpty {
            data["memo"] = memoText
        }

        if !todoItems.isEmpty {
            data["todos"] = todoItems.map { todo in
                var item: [String: Any] = [
                    "title": todo.title,
                    "isCompleted": todo.isCompleted,
                    "priority": todo.priority
                ]
                if let notes = todo.notes { item["notes"] = notes }
                if let assignee = todo.assignee { item["assignee"] = assignee }
                if let dueDate = todo.dueDate {
                    item["dueDate"] = Self.iso8601Formatter.string(from: dueDate)
                }
                return item
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted])
        return try saveToFile(data: jsonData, extension: "json")
    }

    // MARK: - ヘルパーメソッド

    private func saveToFile(content: String, extension ext: String) throws -> URL {
        guard let data = content.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return try saveToFile(data: data, extension: ext)
    }

    private func saveToFile(data: Data, extension ext: String) throws -> URL {
        let filename = "memora_export_\(Date().timeIntervalSince1970).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    private static let exportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.exportDateFormatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func makeSegmentsJSON(transcript: Transcript) -> [[String: Any]] {
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

    private static let iso8601Formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return f
    }()

    // MARK: - SRT エクスポート

    private func exportTranscriptAsSRT(
        transcript: Transcript,
        audioFile: AudioFile
    ) throws -> URL {
        var content = "# \(audioFile.title)\n"
        content += "# 作成日: \(formatDate(audioFile.createdAt))\n\n"

        let count = min(
            transcript.speakerLabels.count,
            transcript.segmentStartTimes.count,
            transcript.segmentEndTimes.count,
            transcript.segmentTexts.count
        )

        for i in 0..<count {
            content += "\(i + 1)\n"

            // SRT 形式: 00:00:00,000 --> 00:00:00,000
            let startTime = formatTimestampForSRT(transcript.segmentStartTimes[i])
            let endTime = formatTimestampForSRT(transcript.segmentEndTimes[i])
            content += "\(startTime) --> \(endTime)\n"

            content += "\(transcript.speakerLabels[i]): \(transcript.segmentTexts[i])\n\n"
        }

        // セグメントがない場合は全文をエクスポート
        if count == 0 {
            content += "1\n"
            content += "00:00:00,000 --> \(formatTimestampForSRT(audioFile.duration))\n"
            content += transcript.text
        }

        return try saveToFile(content: content, extension: "srt")
    }

    // MARK: - VTT エクスポート

    private func exportTranscriptAsVTT(
        transcript: Transcript,
        audioFile: AudioFile
    ) throws -> URL {
        var content = "WEBVTT\n\n"
        content += "# \(audioFile.title)\n\n"

        let count = min(
            transcript.speakerLabels.count,
            transcript.segmentStartTimes.count,
            transcript.segmentEndTimes.count,
            transcript.segmentTexts.count
        )

        for i in 0..<count {
            // VTT 形式: 00:00:00.000 --> 00:00:00.000
            let startTime = formatTimestampForVTT(transcript.segmentStartTimes[i])
            let endTime = formatTimestampForVTT(transcript.segmentEndTimes[i])
            content += "\(startTime) --> \(endTime)\n"

            content += "<v \(transcript.speakerLabels[i].lowercased())>\(transcript.segmentTexts[i])\n\n"
        }

        // セグメントがない場合は全文をエクスポート
        if count == 0 {
            content += "00:00:00.000 --> \(formatTimestampForVTT(audioFile.duration))\n"
            content += transcript.text + "\n\n"
        }

        return try saveToFile(content: content, extension: "vtt")
    }

    // MARK: - タイムスタンプフォーマット

    private func formatTimestampForSRT(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    private func formatTimestampForVTT(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
}

/// エクスポートエラー
enum ExportError: LocalizedError {
    case noData
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .noData:
            return "エクスポートするデータがありません"
        case .encodingFailed:
            return "エンコードに失敗しました"
        }
    }
}
