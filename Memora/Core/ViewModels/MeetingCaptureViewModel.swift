import Foundation
import SwiftUI
import SwiftData

enum CaptureMode: String, CaseIterable {
    case localBroadcast = "local_broadcast"
    case bot = "bot"

    var displayName: String {
        switch self {
        case .localBroadcast: return "ローカルキャプチャ"
        case .bot: return "Bot参加"
        }
    }

    var iconName: String {
        switch self {
        case .localBroadcast: return "waveform.circle.fill"
        case .bot: return "bot.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .localBroadcast: return "デバイスの音声を直接キャプチャします"
        case .bot: return "Botが会議に自動参加して録音します"
        }
    }
}

enum MeetingPlatform: String, CaseIterable {
    case zoom = "zoom"
    case googleMeet = "google_meet"
    case teams = "teams"
    case other = "other"

    var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .teams: return "Microsoft Teams"
        case .other: return "その他"
        }
    }

    var iconName: String {
        switch self {
        case .zoom: return "video.circle.fill"
        case .googleMeet: return "video.fill"
        case .teams: return "person.2.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum CaptureStatus: Equatable {
    case idle
    case settingUp
    case capturing
    case stopped
    case completed(audioFileID: UUID)
    case failed(String)

    var displayText: String {
        switch self {
        case .idle: return "準備完了"
        case .settingUp: return "設定中..."
        case .capturing: return "キャプチャ中..."
        case .stopped: return "停止済み"
        case .completed: return "完了"
        case .failed(let msg): return "エラー: \(msg)"
        }
    }
}

@MainActor
@Observable
final class MeetingCaptureViewModel {
    var captureMode: CaptureMode = .localBroadcast
    var selectedPlatform: MeetingPlatform = .other
    var meetingTitle: String = ""
    var meetingURL: String = ""
    var captureStatus: CaptureStatus = .idle
    var isCapturing: Bool = false
    var captureStartTime: Date?
    var elapsedSeconds: TimeInterval = 0
    var capturedAudioFileID: UUID?
    var errorMessage: String?

    private var timer: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    private var captureService: SystemAudioCaptureService?
    private var modelContext: ModelContext?

    enum CalendarAccessStatus {
        case notRequested
        case authorized
        case denied
        case noMeetings
    }

    var calendarService = CalendarService()
    var upcomingMeetings: [CalendarMeeting] = []
    var showCalendarPicker: Bool = false
    var calendarAccessStatus: CalendarAccessStatus = .notRequested

    var botViewModel = BotMeetingViewModel()
    var onCaptureCompleted: ((UUID) -> Void)?

    var canStartCapture: Bool {
        !meetingTitle.trimmingCharacters(in: .whitespaces).isEmpty && captureStatus == .idle
    }

    var canScheduleBot: Bool {
        botViewModel.canSchedule
    }

    func configure(captureService: SystemAudioCaptureService) {
        self.captureService = captureService
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func configureBotService(_ botService: BotMeetingService, modelContext: ModelContext) {
        botViewModel.configure(botService: botService, modelContext: modelContext)
    }

    func updateBotServerConfig(url: String, apiKey: String) {
        botViewModel.updateServerConfig(url: url, apiKey: apiKey)
    }

    func startLocalCapture() {
        guard let captureService else {
            captureStatus = .failed("キャプチャサービスが初期化されていません")
            return
        }

        captureStatus = .settingUp
        errorMessage = nil

        captureService.requestBroadcastStart()

        captureStartTime = Date()
        isCapturing = true
        captureStatus = .capturing

        timer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if let start = captureStartTime {
                    elapsedSeconds = Date().timeIntervalSince(start)
                }
            }
        }

        startMonitorStream(captureService)
    }

    func startMonitoring() {
        guard let captureService, captureStatus == .idle else { return }
        captureStatus = .settingUp
        errorMessage = nil
        captureStartTime = Date()
        isCapturing = true
        captureStatus = .capturing

        timer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if let start = captureStartTime {
                    elapsedSeconds = Date().timeIntervalSince(start)
                }
            }
        }

        startMonitorStream(captureService)
    }

    private func startMonitorStream(_ captureService: SystemAudioCaptureService) {
        monitorTask = Task {
            let stream = captureService.startMonitoring()
            for await event in stream {
                switch event {
                case .newCapture(let audioFile):
                    handleCaptureCompleted(audioFileID: audioFile.id)
                case .importFailed(let error):
                    handleCaptureFailed(error)
                }
            }
        }
    }

    func stopCapture() {
        timer?.cancel()
        timer = nil
        monitorTask?.cancel()
        monitorTask = nil
        captureService?.stopMonitoring()
        isCapturing = false
        captureStatus = .stopped
    }

    func handleCaptureCompleted(audioFileID: UUID) {
        timer?.cancel()
        timer = nil
        monitorTask?.cancel()
        monitorTask = nil
        captureService?.stopMonitoring()
        isCapturing = false
        capturedAudioFileID = audioFileID
        captureStatus = .completed(audioFileID: audioFileID)

        if let modelContext {
            let capture = OnlineMeetingCapture(
                platform: selectedPlatform.rawValue,
                meetingTitle: meetingTitle,
                meetingURL: meetingURL.isEmpty ? nil : meetingURL,
                captureMode: captureMode.rawValue
            )
            capture.audioFileID = audioFileID
            capture.status = "completed"
            capture.startedAt = captureStartTime
            capture.completedAt = Date()
            capture.duration = elapsedSeconds
            modelContext.insert(capture)
            try? modelContext.save()
        }

        onCaptureCompleted?(audioFileID)
    }

    func scheduleBot() async {
        botViewModel.meetingTitle = meetingTitle
        botViewModel.meetingURL = meetingURL
        botViewModel.selectedPlatform = selectedPlatform == .other ? .googleMeet : selectedPlatform
        await botViewModel.scheduleMeeting()
    }

    func handleCaptureFailed(_ error: Error) {
        timer?.cancel()
        timer = nil
        monitorTask?.cancel()
        monitorTask = nil
        captureService?.stopMonitoring()
        isCapturing = false
        errorMessage = error.localizedDescription
        captureStatus = .failed(error.localizedDescription)
    }

    func loadUpcomingMeetings() async {
        let granted = await calendarService.requestAccess()
        guard granted else {
            calendarAccessStatus = .denied
            return
        }
        calendarAccessStatus = .authorized
        upcomingMeetings = calendarService.fetchUpcomingMeetings(within: 7)
        if upcomingMeetings.isEmpty {
            calendarAccessStatus = .noMeetings
        }
        showCalendarPicker = !upcomingMeetings.isEmpty
    }

    func applyCalendarMeeting(_ meeting: CalendarMeeting) {
        selectedPlatform = meeting.platform
        meetingTitle = meeting.title
        meetingURL = meeting.url
        upcomingMeetings = []
        showCalendarPicker = false
        calendarAccessStatus = .notRequested
    }

    func reset() {
        timer?.cancel()
        timer = nil
        monitorTask?.cancel()
        monitorTask = nil
        captureService?.stopMonitoring()
        captureMode = .localBroadcast
        selectedPlatform = .other
        meetingTitle = ""
        meetingURL = ""
        captureStatus = .idle
        isCapturing = false
        captureStartTime = nil
        elapsedSeconds = 0
        capturedAudioFileID = nil
        errorMessage = nil
    }

    // Timer is cancelled in stopCapture/handleCaptureCompleted/handleCaptureFailed/reset
}
