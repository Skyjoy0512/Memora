import SwiftUI

struct TranscriptView: View {
    let result: TranscriptResult
    var onSegmentTap: ((SpeakerSegment) -> Void)? = nil

    var body: some View {
        ScrollView {
            TranscriptContentView(
                result: result,
                onSegmentTap: onSegmentTap
            )
            .padding()
        }
        .navigationTitle("文字起こし")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TranscriptContentView: View {
    let result: TranscriptResult
    var showSegments = true
    var currentPlaybackTime: TimeInterval = -1
    var onSegmentTap: ((SpeakerSegment) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            if showSegments && !result.segments.isEmpty {
                ForEach(Array(result.segments.enumerated()), id: \.offset) { index, seg in
                    SpeakerSegmentView(
                        segment: seg,
                        isPlaying: currentPlaybackTime >= seg.startTime && currentPlaybackTime < seg.endTime,
                        onTap: onSegmentTap
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("文字起こし")
                        .font(MemoraTypography.headline)

                    Text(result.text)
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MemoraColor.divider.opacity(0.05))
                .clipShape(.rect(cornerRadius: MemoraRadius.md))
            }

            Spacer()
                .frame(height: 40)
        }
    }
}

struct SpeakerSegmentView: View {
    let segment: SpeakerSegment
    var isPlaying: Bool = false
    var onTap: ((SpeakerSegment) -> Void)? = nil

    var body: some View {
        Button {
            onTap?(segment)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "play.circle")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text(segment.speakerLabel)
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Spacer()

                    Text(formatTime(segment.startTime))
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                Text(segment.text)
                    .font(MemoraTypography.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, MemoraSpacing.xs)
            .padding(.horizontal, MemoraSpacing.sm)
            .background(isPlaying ? MemoraColor.accentBlue.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        TranscriptView(
            result: TranscriptResult(
                text: "これはテスト用の文字起こし結果です。\n\nSpeaker 1: 今日はプロジェクトの進捗について議論します。",
                segments: [
                    SpeakerSegment(
                        speakerLabel: "Speaker 1",
                        startTime: 0,
                        endTime: 5,
                        text: "今日はプロジェクトの進捗について議論します。"
                    ),
                    SpeakerSegment(
                        speakerLabel: "Speaker 2",
                        startTime: 5,
                        endTime: 10,
                        text: "了解しました。まず現状から確認しましょう。"
                    )
                ],
                duration: 60
            )
        )
    }
}
