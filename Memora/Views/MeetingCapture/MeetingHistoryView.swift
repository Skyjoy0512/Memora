import SwiftUI
import SwiftData

struct MeetingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \OnlineMeetingCapture.createdAt, order: .reverse) private var localCaptures: [OnlineMeetingCapture]
    @Query(sort: \ScheduledBotMeeting.scheduledTime, order: .reverse) private var botMeetings: [ScheduledBotMeeting]
    @State private var selectedAudioFileID: UUID?
    @State private var navigateToFile = false

    var body: some View {
        NavigationStack {
            Group {
                if unifiedMeetings.isEmpty {
                    emptyState
                } else {
                    meetingList
                }
            }
            .navigationTitle("会議履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToFile) {
                if let fileID = selectedAudioFileID,
                   let file = fetchAudioFile(id: fileID) {
                    FileDetailView(audioFile: file, autoStartTranscription: false)
                }
            }
        }
    }

    // MARK: - Unified Meeting Data

    private var unifiedMeetings: [UnifiedMeeting] {
        let local = localCaptures.map { UnifiedMeeting(from: $0) }
        let bot = botMeetings.map { UnifiedMeeting(from: $0) }
        return (local + bot).sorted { $0.sortDate > $1.sortDate }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("会議履歴はありません")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("FABメニューの「会議キャプチャ」から\nオンライン会議を取り込めます")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .background(MemoraColor.surfacePrimary)
    }

    // MARK: - Meeting List

    private var meetingList: some View {
        List {
            ForEach(unifiedMeetings) { meeting in
                Button {
                    if let fileID = meeting.audioFileID {
                        selectedAudioFileID = fileID
                        navigateToFile = true
                    }
                } label: {
                    meetingRow(meeting)
                }
                .disabled(meeting.audioFileID == nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MemoraColor.surfacePrimary)
    }

    private func meetingRow(_ meeting: UnifiedMeeting) -> some View {
        HStack(spacing: MemoraSpacing.md) {
            Image(systemName: meeting.sourceIcon)
                .font(.title3)
                .foregroundStyle(meeting.sourceColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: MemoraSpacing.xs) {
                    Text(meeting.platformLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(meeting.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            statusBadge(meeting.status)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge(_ status: UnifiedMeeting.Status) -> some View {
        switch status {
        case .completed:
            Label("完了", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(MemoraColor.accentGreen)
        case .pending:
            Label("予約済", systemImage: "clock.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .recording:
            Label("録音中", systemImage: "record.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        case .failed:
            Label("失敗", systemImage: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    private func fetchAudioFile(id: UUID) -> AudioFile? {
        var descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - UnifiedMeeting

private struct UnifiedMeeting: Identifiable {
    enum Source {
        case localCapture
        case botMeeting
    }

    enum Status {
        case completed
        case pending
        case recording
        case failed
    }

    let id: UUID
    let title: String
    let platformLabel: String
    let formattedDate: String
    let sortDate: Date
    let source: Source
    let status: Status
    let audioFileID: UUID?

    var sourceIcon: String {
        switch source {
        case .localCapture: return "waveform.circle.fill"
        case .botMeeting: return "bot.circle.fill"
        }
    }

    var sourceColor: Color {
        switch source {
        case .localCapture: return .blue
        case .botMeeting: return .purple
        }
    }

    init(from capture: OnlineMeetingCapture) {
        self.id = capture.id
        self.title = capture.meetingTitle
        self.platformLabel = platformDisplayName(capture.platform)
        self.formattedDate = formatDate(capture.createdAt)
        self.sortDate = capture.completedAt ?? capture.startedAt ?? capture.createdAt
        self.source = capture.captureMode == "bot" ? .botMeeting : .localCapture
        self.audioFileID = capture.audioFileID

        switch capture.status {
        case "completed": self.status = .completed
        case "failed": self.status = .failed
        default: self.status = .pending
        }
    }

    init(from meeting: ScheduledBotMeeting) {
        self.id = meeting.id
        self.title = meeting.meetingTitle
        self.platformLabel = platformDisplayName(meeting.platform)
        self.formattedDate = formatDate(meeting.scheduledTime)
        self.sortDate = meeting.scheduledTime
        self.source = .botMeeting
        self.audioFileID = meeting.audioFileID

        switch meeting.status {
        case "completed": self.status = .completed
        case "recording", "joined": self.status = .recording
        case "failed": self.status = .failed
        default: self.status = .pending
        }
    }
}

private func platformDisplayName(_ platform: String) -> String {
    switch platform {
    case "zoom": return "Zoom"
    case "google_meet": return "Google Meet"
    case "teams": return "Teams"
    default: return platform.isEmpty ? "その他" : platform
    }
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter.string(from: date)
}

#Preview {
    MeetingHistoryView()
        .modelContainer(for: OnlineMeetingCapture.self, inMemory: true)
}
