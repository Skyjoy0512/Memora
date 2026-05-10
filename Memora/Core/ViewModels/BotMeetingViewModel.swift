import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class BotMeetingViewModel {
    var meetingTitle: String = ""
    var meetingURL: String = ""
    var selectedPlatform: MeetingPlatform = .googleMeet
    var scheduledDate: Date = Date().addingTimeInterval(300)
    var durationMinutes: Int = 60
    var isLoading: Bool = false
    var errorMessage: String?
    var scheduledMeetings: [ScheduledBotMeeting] = []
    var connectionStatus: ConnectionStatus = .unknown

    var botService = BotMeetingService()
    private var modelContext: ModelContext?

    enum ConnectionStatus: Equatable {
        case unknown
        case testing
        case connected
        case failed(String)
    }

    var canSchedule: Bool {
        !meetingTitle.trimmingCharacters(in: .whitespaces).isEmpty
            && !meetingURL.trimmingCharacters(in: .whitespaces).isEmpty
            && botService.isConfigured
            && !isLoading
    }

    func configure(botService: BotMeetingService, modelContext: ModelContext) {
        self.botService = botService
        self.modelContext = modelContext
    }

    func updateServerConfig(url: String, apiKey: String) {
        botService.configure(serverURL: url, apiKey: apiKey)
    }

    // MARK: - Test Connection

    func testConnection() async {
        connectionStatus = .testing
        do {
            let ok = try await botService.testConnection()
            connectionStatus = ok ? .connected : .failed("サーバーが応答しませんでした")
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Schedule Meeting

    func scheduleMeeting() async {
        guard let modelContext else {
            errorMessage = "データベースが初期化されていません"
            return
        }

        isLoading = true
        errorMessage = nil

        let meeting = ScheduledBotMeeting(
            platform: selectedPlatform.rawValue,
            meetingURL: meetingURL.trimmingCharacters(in: .whitespaces),
            meetingTitle: meetingTitle.trimmingCharacters(in: .whitespaces),
            scheduledTime: scheduledDate,
            durationMinutes: durationMinutes
        )

        modelContext.insert(meeting)
        try? modelContext.save()

        do {
            let response = try await botService.scheduleMeeting(meeting)
            meeting.serverJobID = response.jobID
            meeting.status = response.status
            meeting.updatedAt = Date()
            try modelContext.save()

            scheduledMeetings.append(meeting)
            resetForm()
        } catch {
            meeting.status = "failed"
            meeting.errorMessage = error.localizedDescription
            meeting.updatedAt = Date()
            try? modelContext.save()
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Refresh Status

    func refreshMeetingStatuses() async {
        for meeting in scheduledMeetings {
            guard !meeting.isCompleted, !meeting.isFailed, let jobID = meeting.serverJobID else { continue }

            do {
                let status = try await botService.getMeetingStatus(jobID: jobID)
                meeting.status = status.status
                meeting.updatedAt = Date()

                if status.status == "completed", let audioURLString = status.audioURL {
                    if let audioURL = URL(string: audioURLString) {
                        let webhookReceiver = MeetingWebhookReceiver()
                        webhookReceiver.configure(modelContext: modelContext!)
                        let payload = BotMeetingWebhookPayload(
                            event: "meeting.completed",
                            meetingID: meeting.id.uuidString,
                            jobID: jobID,
                            audioURL: audioURLString,
                            transcript: status.transcript,
                            summary: status.summary,
                            error: nil
                        )
                        try await webhookReceiver.handleWebhook(payload: payload)
                    }
                }
            } catch {
                DebugLogger.shared.addLog("BotMeeting", "Status refresh failed: \(error.localizedDescription)", level: .warning)
            }
        }
        try? modelContext?.save()
    }

    // MARK: - Cancel Meeting

    func cancelMeeting(_ meeting: ScheduledBotMeeting) async {
        guard let jobID = meeting.serverJobID else {
            if let ctx = modelContext {
                ctx.delete(meeting)
                try? ctx.save()
            }
            scheduledMeetings.removeAll { $0.id == meeting.id }
            return
        }

        do {
            try await botService.cancelMeeting(jobID: jobID)
            if let ctx = modelContext {
                ctx.delete(meeting)
                try? ctx.save()
            }
            scheduledMeetings.removeAll { $0.id == meeting.id }
        } catch {
            errorMessage = "キャンセルに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Meetings

    func loadScheduledMeetings() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<ScheduledBotMeeting>(
            sortBy: [SortDescriptor(\.scheduledTime, order: .reverse)]
        )
        scheduledMeetings = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func resetForm() {
        meetingTitle = ""
        meetingURL = ""
        scheduledDate = Date().addingTimeInterval(300)
        durationMinutes = 60
    }
}
