import SwiftUI

struct AudioFileRow: View {
    let audioFile: AudioFile
    let projectName: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    private var isRecent: Bool {
        Date().timeIntervalSince(audioFile.createdAt) < 86400
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(MemoraColor.accentNothing)
                .frame(width: 3)
                .padding(.vertical, 4)
                .if(isRecent) { view in
                    view.nothingGlow(.subtle)
                }

            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                Text(audioFile.title)
                    .font(MemoraTypography.phiSubhead)
                    .foregroundStyle(MemoraColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: MemoraSpacing.xs) {
                    Text(formatDate(audioFile.createdAt))
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.textTertiary)

                    if audioFile.duration > 0 {
                        Text(formatDuration(audioFile.duration))
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(MemoraColor.textTertiary)
                    }

                    AccentDotIndicator(glowing: isRecent)

                    sourceBadge

                    Spacer()
                }

                HStack(spacing: MemoraSpacing.xxs) {
                    if let projectName {
                        Label(projectName, systemImage: "folder")
                            .font(MemoraTypography.caption2)
                            .foregroundStyle(MemoraColor.accentNothing.opacity(0.7))
                    }

                    Spacer()

                    if audioFile.isTranscribed {
                        StatusChip(title: "文字起こし済", color: MemoraColor.accentBlue)
                    }
                    if audioFile.isSummarized {
                        StatusChip(title: "要約済", color: MemoraColor.accentGreen)
                    }
                }
            }
            .padding(.leading, MemoraSpacing.sm)
        }
        .padding(.vertical, MemoraSpacing.xs)
        .padding(.horizontal, MemoraSpacing.sm)
        .nothingCard(.minimal)
    }

    @ViewBuilder
    private var sourceBadge: some View {
        let icon: String = {
            switch audioFile.sourceType {
            case .recording: return "mic.fill"
            case .import: return "square.and.arrow.down"
            case .plaud: return "waveform"
            case .google: return "video.fill"
            }
        }()
        Image(systemName: icon)
            .font(MemoraTypography.caption2)
            .foregroundStyle(MemoraColor.textTertiary)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct StatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(MemoraTypography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.06))
            .overlay {
                Capsule().stroke(color.opacity(0.3), lineWidth: 0.5)
            }
            .clipShape(Capsule())
    }
}
