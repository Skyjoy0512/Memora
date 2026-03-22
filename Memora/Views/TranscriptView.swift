import SwiftUI

struct TranscriptView: View {
    let result: TranscriptResult
    @State private var showSegments = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 文字起こし全文
                VStack(alignment: .leading, spacing: 12) {
                    Text("文字起こし")
                        .font(.headline)

                    Text(result.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                // 話者セグメント
                if showSegments && !result.segments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("話者分離")
                            .font(.headline)

                        ForEach(result.segments.indices, id: \.self) { index in
                            SpeakerSegmentView(segment: result.segments[index])
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)

                Spacer()

                Text(formatTime(segment.startTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(segment.text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
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
