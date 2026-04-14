//
//  MemoraFileDetailView.swift
//  DetailsPro Preview
//
//  Memora FileDetailView - File Detail / Player / Tabs Screen
//

import SwiftUI

// MARK: - File Detail View

struct MemoraFileDetailView: View {
    @State private var selectedTab: DetailTab = .summary
    @State private var playbackPosition: Double = 45.0
    @State private var audioDuration: Double = 180.0
    @State private var isPlaying = false

    enum DetailTab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
        case memo = "Memo"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MemoraSpacing.lg) {
                // Header Section
                headerSection

                // Player Controls
                playerControls

                // Tab Picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                // Tab Content
                switch selectedTab {
                case .summary:
                    summaryContent
                case .transcript:
                    transcriptContent
                case .memo:
                    memoContent
                }
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.top, MemoraSpacing.xl)
            .padding(.bottom, 80)
        }
        .overlay(alignment: .bottom) {
            askAICompactBar
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
            HStack(spacing: MemoraSpacing.xs) {
                Text("週次定例ミーティング")
                    .font(.title2)
                    .fontWeight(.bold)
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: MemoraSpacing.sm) {
                Text("2026/04/14 10:00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("45:30")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("録音", systemImage: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("プロジェクトA", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Calendar Event Card
            HStack(spacing: MemoraSpacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(MemoraColor.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("週次定例ミーティング")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("2026/04/14 10:00 - 11:00")
                        .font(.caption)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
                Spacer()
                Button {} label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(MemoraColor.textSecondary)
                        .font(.caption)
                }
            }
            .padding(MemoraSpacing.sm)
            .background(MemoraColor.accentBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Player

    private var playerControls: some View {
        HStack(spacing: MemoraSpacing.md) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 2) {
                Slider(value: $playbackPosition, in: 0...audioDuration)
                HStack {
                    Text(formatTime(playbackPosition))
                    Spacer()
                    Text(formatTime(audioDuration))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, MemoraSpacing.sm)
        .padding(.vertical, MemoraSpacing.xs)
    }

    // MARK: - Summary Tab

    private var summaryContent: some View {
        VStack(spacing: MemoraSpacing.lg) {
            // Summary card
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    Label("要約", systemImage: "text.quote")
                        .font(.headline)
                        .foregroundStyle(MemoraColor.accentBlue)

                    Text("今週の進捗:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• iOS アプリのUI改修が完了\n• STT バックエンドの安定性向上\n• 新しいデザインシステムの導入")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)

                    Divider()

                    Text("アクションアイテム:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• 来週までにテストカバレッジを80%に\n• CI パイプラインの最適化\n• ドキュメントの更新")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                }
            }

            // Action buttons
            HStack(spacing: MemoraSpacing.sm) {
                Button {} label: {
                    Label("再生成", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {} label: {
                    Label("エクスポート", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Transcript Tab

    private var transcriptContent: some View {
        VStack(spacing: MemoraSpacing.lg) {
            // Speaker segments
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                    SpeakerSegmentDesign(
                        speaker: "Speaker 1",
                        time: "0:00",
                        text: "今週の進捗を確認していきましょう。まずフロントエンドの状況からお願いします。",
                        isPlaying: true
                    )
                    SpeakerSegmentDesign(
                        speaker: "Speaker 2",
                        time: "0:45",
                        text: "UI の改修は完了しました。新しいデザインシステムに沿って全画面を更新しています。",
                        isPlaying: false
                    )
                    SpeakerSegmentDesign(
                        speaker: "Speaker 1",
                        time: "1:30",
                        text: "ありがとうございます。STTの安定性はいかがですか？",
                        isPlaying: false
                    )
                    SpeakerSegmentDesign(
                        speaker: "Speaker 2",
                        time: "2:10",
                        text: "フォールバックの仕組みを改善して、安定性が大幅に向上しました。",
                        isPlaying: false
                    )
                }
            }

            // Action buttons
            HStack(spacing: MemoraSpacing.sm) {
                Button {} label: {
                    Label("再文字起こし", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {} label: {
                    Label("編集", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    // MARK: - Memo Tab

    private var memoContent: some View {
        VStack(spacing: MemoraSpacing.lg) {
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    HStack {
                        Label("Markdown メモ", systemImage: "square.and.pencil")
                            .font(.headline)
                        Spacer()
                        Button("保存") {}
                            .buttonStyle(.borderedProminent)
                    }

                    RoundedRectangle(cornerRadius: MemoraRadius.md)
                        .fill(MemoraColor.divider.opacity(0.08))
                        .frame(height: 180)
                        .overlay(alignment: .topLeading) {
                            Text("# メモ\n\n- 重要な決定事項\n- 次回までの課題\n")
                                .font(.body)
                                .padding(MemoraSpacing.sm)
                                .foregroundStyle(.primary)
                        }

                    HStack(spacing: MemoraSpacing.xs) {
                        Circle()
                            .fill(MemoraColor.accentGreen)
                            .frame(width: 8, height: 8)
                        Text("最終保存: 2026/04/14 10:30")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Photos section
            detailCard {
                VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                    HStack {
                        Label("写真", systemImage: "photo.on.rectangle")
                            .font(.headline)
                        Spacer()
                        Button {} label: {
                            Label("追加", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MemoraSpacing.sm) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: MemoraRadius.md)
                                    .fill(MemoraColor.divider.opacity(0.16))
                                    .frame(width: 132, height: 98)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(MemoraColor.textSecondary)
                                    }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ask AI Bar

    private var askAICompactBar: some View {
        Button {} label: {
            HStack(spacing: MemoraSpacing.sm) {
                Text("OpenAI")
                    .font(.caption)
                    .foregroundStyle(MemoraColor.accentBlue)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 2)
                    .background(MemoraColor.accentBlue.opacity(0.12))
                    .clipShape(Capsule())

                Text("Ask AI...")
                    .font(.body)
                    .foregroundStyle(.tertiary)

                Spacer()

                Image(systemName: "sparkle")
                    .foregroundStyle(MemoraColor.accentBlue)
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.sm)
    }

    // MARK: - Helpers

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(MemoraSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MemoraColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Speaker Segment

struct SpeakerSegmentDesign: View {
    let speaker: String
    let time: String
    let text: String
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "play.circle")
                    .font(.caption)
                    .foregroundStyle(MemoraColor.textSecondary)
                Text(speaker)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(MemoraColor.textSecondary)
                Spacer()
                Text(time)
                    .font(.caption)
                    .foregroundStyle(MemoraColor.textSecondary)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, MemoraSpacing.xs)
        .padding(.horizontal, MemoraSpacing.sm)
        .background(isPlaying ? MemoraColor.accentBlue.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
    }
}

#Preview {
    NavigationStack {
        MemoraFileDetailView()
    }
}
