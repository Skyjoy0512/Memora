import Foundation
import SwiftData
import AVFoundation

/// Bot サーバーからの録音完了 Webhook を受信し、
/// 音声ファイルをダウンロードして既存パイプラインに接続する。
@MainActor
final class MeetingWebhookReceiver {
    private var modelContext: ModelContext?
    private let botService = BotMeetingService()

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Webhook ペイロードを処理する
    func handleWebhook(payload: BotMeetingWebhookPayload) async throws {
        guard let modelContext else {
            throw BotMeetingError.notConfigured
        }

        // ScheduledBotMeeting を検索
        let meetingID = UUID(uuidString: payload.meetingID) ?? UUID()
        let descriptor = FetchDescriptor<ScheduledBotMeeting>(
            predicate: #Predicate { $0.id == meetingID }
        )
        guard let meeting = try modelContext.fetch(descriptor).first else {
            DebugLogger.shared.addLog("MeetingWebhook", "Meeting not found: \(payload.meetingID)", level: .warning)
            return
        }

        switch payload.event {
        case "meeting.completed":
            meeting.status = "completed"
            meeting.updatedAt = Date()

            if let audioURLString = payload.audioURL, let audioURL = URL(string: audioURLString) {
                _ = try await downloadAndImportAudio(from: audioURL, meeting: meeting)
                meeting.resultSummary = payload.summary
            }

        case "meeting.failed":
            meeting.status = "failed"
            meeting.errorMessage = payload.error
            meeting.updatedAt = Date()

        case "meeting.joined":
            meeting.status = "joined"
            meeting.serverJobID = payload.jobID
            meeting.updatedAt = Date()

        case "meeting.recording":
            meeting.status = "recording"
            meeting.updatedAt = Date()

        default:
            DebugLogger.shared.addLog("MeetingWebhook", "Unknown event: \(payload.event)", level: .warning)
        }

        try modelContext.save()
    }

    /// Bot サーバーから音声ファイルをダウンロードし AudioFile としてインポート
    private func downloadAndImportAudio(from url: URL, meeting: ScheduledBotMeeting) async throws -> AudioFile {
        guard let modelContext else {
            throw BotMeetingError.notConfigured
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documentsDir.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let fileName = "bot_meeting_\(meeting.id.uuidString.prefix(8)).m4a"
        let fileURL = audioDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        let asset = AVAsset(url: fileURL)
        let duration = asset.duration.seconds

        let audioFile = AudioFile(title: meeting.meetingTitle, audioURL: fileURL.path)
        audioFile.duration = duration.isFinite ? duration : 0
        audioFile.sourceType = .botMeeting

        modelContext.insert(audioFile)
        try modelContext.save()

        // Look up the ScheduledBotMeeting and link the audioFileID
        let meetingID = meeting.id
        let descriptor = FetchDescriptor<ScheduledBotMeeting>(
            predicate: #Predicate { $0.id == meetingID }
        )
        if let botMeeting = try modelContext.fetch(descriptor).first {
            botMeeting.audioFileID = audioFile.id
            try modelContext.save()
        }

        DebugLogger.shared.addLog(
            "MeetingWebhook",
            "Downloaded bot meeting audio: \(fileName), duration: \(duration)s",
            level: .info
        )

        return audioFile
    }
}

// MARK: - Webhook Payload

struct BotMeetingWebhookPayload: Codable {
    let event: String
    let meetingID: String
    let jobID: String?
    let audioURL: String?
    let transcript: String?
    let summary: String?
    let error: String?
}
