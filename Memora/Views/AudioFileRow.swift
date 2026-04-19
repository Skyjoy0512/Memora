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
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(audioFile.title)
                .font(.body)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(formatDate(audioFile.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let summary = audioFile.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

// MARK: - Status Chip

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
