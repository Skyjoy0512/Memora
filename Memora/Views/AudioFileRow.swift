import SwiftUI

struct AudioFileRow: View {
    let audioFile: AudioFile
    let projectName: String?
    var showActions: Bool = true
    var onTap: (() -> Void)? = nil
    var onTranscribe: (() -> Void)? = nil
    var onAISummary: (() -> Void)? = nil
    var onAddToProject: (() -> Void)? = nil
    var onContextMenu: (() -> Void)? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
            // Row 1: Title + Duration
            HStack(alignment: .firstTextBaseline) {
                Text(audioFile.title)
                    .font(MemoraTypography.chatBody)
                    .fontWeight(.medium)
                    .foregroundStyle(MemoraColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(formatDuration(audioFile.duration))
                    .font(MemoraTypography.chatToken)
                    .foregroundStyle(MemoraColor.textTertiary)
                    .monospacedDigit()
            }

            // Row 2: Date + Summary preview
            HStack(spacing: MemoraSpacing.xxs) {
                Text(formatDate(audioFile.createdAt))
                    .font(MemoraTypography.chatToken)
                    .foregroundStyle(MemoraColor.textTertiary)

                if let summary = audioFile.summary, !summary.isEmpty {
                    Text("\u{2022}")
                        .font(MemoraTypography.chatToken)
                        .foregroundStyle(MemoraColor.textTertiary)

                    Text(summary)
                        .font(MemoraTypography.chatToken)
                        .foregroundStyle(MemoraColor.textSecondary)
                        .lineLimit(1)
                }
            }

            // Row 3: Status chips
            if hasStatusChips {
                HStack(spacing: MemoraSpacing.xxs) {
                    if audioFile.isTranscribed {
                        StatusChip(title: "文字起こし済", color: MemoraColor.accentGreen)
                    } else {
                        StatusChip(title: "未文字起こし", color: MemoraColor.textTertiary)
                    }

                    if audioFile.isSummarized {
                        StatusChip(title: "要約済", color: MemoraColor.accentGreen)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var hasStatusChips: Bool {
        true // always show transcription status
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(MemoraTypography.chatToken)
            .foregroundStyle(MemoraColor.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.clear)
            .overlay {
                Capsule().stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
            }
            .clipShape(Capsule())
    }
}
