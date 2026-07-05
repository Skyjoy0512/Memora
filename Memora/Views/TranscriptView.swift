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
                VStack(alignment: .leading, spacing: 8) {
                    Text("文字起こし")
                        .font(.system(size: 13, weight: .semibold))

                    Text(result.text)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(5)
                }
                .padding(12)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !segment.speakerLabel.isEmpty {
                        Text(segment.speakerLabel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MemoraColor.textPrimary)
                    }

                    Spacer()

                    if segment.isEstimatedTiming {
                        Text("約 " + formatTime(segment.startTime))
                            .font(.system(size: 11, weight: .regular))
                            .italic()
                            .foregroundStyle(MemoraColor.textTertiary)
                    } else {
                        Text(formatTime(segment.startTime))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(hex: "58585A"))
                    }
                }

                Text(segment.text)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(isPlaying ? MemoraColor.accentBlue.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
                        text: "今日はプロジェクトの進捗について議論します。",
                        isEstimatedTiming: false
                    ),
                    SpeakerSegment(
                        speakerLabel: "Speaker 2",
                        startTime: 5,
                        endTime: 10,
                        text: "了解しました。まず現状から確認しましょう。",
                        isEstimatedTiming: false
                    )
                ],
                duration: 60
            )
        )
    }
}
