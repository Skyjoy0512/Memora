import SwiftUI

struct TranscriptView: View {
    let result: TranscriptResult
    @State private var showSegments = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MemoraSpacing.xxl) {
                // 文字起こし全文
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
                .cornerRadius(MemoraRadius.md)

                // 話者セグメント
                if showSegments && !result.segments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("話者分離")
                            .font(MemoraTypography.headline)

                        ForEach(result.segments.indices, id: \.self) { index in
                            SpeakerSegmentView(segment: result.segments[index])
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MemoraColor.divider.opacity(0.05))
                    .cornerRadius(MemoraRadius.md)
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
        .navigationTitle("文字起こし")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SpeakerSegmentView: View {
    let segment: SpeakerSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
        }
        .padding(.vertical, MemoraSpacing.xs)
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
