import SwiftUI

struct BotMeetingStatusView: View {
    @Bindable var viewModel: BotMeetingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.scheduledMeetings.isEmpty {
                    emptyStateView
                } else {
                    meetingListView
                }
            }
            .navigationTitle("Bot 会議予約一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .task {
                viewModel.loadScheduledMeetings()
            }
            .refreshable {
                await viewModel.refreshMeetingStatuses()
                viewModel.loadScheduledMeetings()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            Image(systemName: "bot.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("予約済みの会議はありません")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Bot会議予約から新しい会議をスケジュールしてください")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .background(MemoraColor.surfacePrimary)
    }

    private var meetingListView: some View {
        List {
            ForEach(viewModel.scheduledMeetings) { meeting in
                meetingRow(meeting)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MemoraColor.surfacePrimary)
    }

    private func meetingRow(_ meeting: ScheduledBotMeeting) -> some View {
        HStack(spacing: MemoraSpacing.md) {
            statusIcon(meeting.status)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.meetingTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: MemoraSpacing.xs) {
                    Text(platformLabel(meeting.platform))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(formatDate(meeting.scheduledTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let error = meeting.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            if meeting.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MemoraColor.accentGreen)
                    .font(.subheadline)
            } else if meeting.status == "recording" {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !meeting.isFailed {
                Menu {
                    Button(role: .destructive) {
                        Task { await viewModel.cancelMeeting(meeting) }
                    } label: {
                        Label("キャンセル", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await viewModel.cancelMeeting(meeting) }
            } label: {
                Label("キャンセル", systemImage: "xmark.circle")
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
        switch status {
        case "pending":
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
        case "joined":
            Image(systemName: "person.wave.2.fill")
                .foregroundStyle(.blue)
        case "recording":
            Image(systemName: "record.circle.fill")
                .foregroundStyle(.red)
        case "completed":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MemoraColor.accentGreen)
        case "failed":
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        default:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func platformLabel(_ platform: String) -> String {
        switch platform {
        case "zoom": return "Zoom"
        case "google_meet": return "Google Meet"
        case "teams": return "Teams"
        default: return platform
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    BotMeetingStatusView(viewModel: BotMeetingViewModel())
}
