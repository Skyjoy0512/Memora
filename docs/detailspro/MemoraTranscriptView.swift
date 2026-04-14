//
//  MemoraTranscriptView.swift
//  DetailsPro Preview
//
//  Memora TranscriptView - Transcript Display Screen
//

import SwiftUI

struct MemoraTranscriptView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Transcript header
                Label("文字起こし", systemImage: "text.alignleft")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                    .padding(.bottom, 4)

                // Speaker segments
                TranscriptSegmentDesign(
                    speaker: "Speaker 1",
                    time: "0:00",
                    text: "お疲れ様です。今日の定例ミーティングを始めます。まず今週の進捗を確認していきましょう。",
                    isPlaying: true
                )

                TranscriptSegmentDesign(
                    speaker: "Speaker 2",
                    time: "0:45",
                    text: "フロントエンドのUI改修は完了しました。新しいデザインシステムに沿って全画面を更新しています。特にHomeViewとFileDetailViewの改善が大きいですね。",
                    isPlaying: false
                )

                TranscriptSegmentDesign(
                    speaker: "Speaker 1",
                    time: "1:30",
                    text: "ありがとうございます。STTバックエンドの安定性はいかがですか？先週の課題は解決しましたか？",
                    isPlaying: false
                )

                TranscriptSegmentDesign(
                    speaker: "Speaker 2",
                    time: "2:10",
                    text: "はい、フォールバックの仕組みを改善して安定性が大幅に向上しました。SpeechAnalyzerからSFSpeechRecognizerへの移行もスムーズに動作しています。",
                    isPlaying: false
                )

                TranscriptSegmentDesign(
                    speaker: "Speaker 3",
                    time: "3:05",
                    text: "テストについて報告します。現在のカバレッジは72%で、来週までに80%を目指しています。",
                    isPlaying: false
                )

                TranscriptSegmentDesign(
                    speaker: "Speaker 1",
                    time: "4:00",
                    text: "了解しました。では次に、来週のスプリント計画について確認しましょう。",
                    isPlaying: false
                )

                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
        .navigationTitle("文字起こし")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TranscriptSegmentDesign: View {
    let speaker: String
    let time: String
    let text: String
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "play.circle")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))

                Text(speaker)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))

                Spacer()

                Text(time)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
            }

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            isPlaying
                ? Color(red: 0, green: 0.478, blue: 1).opacity(0.08)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        MemoraTranscriptView()
    }
}
