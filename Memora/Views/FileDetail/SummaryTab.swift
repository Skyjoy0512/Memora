import SwiftUI
import PhotosUI

/// Summary tab (`.dc.html` `fdSummaryActive`): meta line, chapters (derived from transcript
/// segments — tap jumps + seeks), decisions, next actions, attachment grid.
struct SummaryTab: View {
    @Bindable var vm: FileDetailViewModel
    let audioFile: AudioFile
    let onSeekToTranscript: (TimeInterval) -> Void
    let onPreviewAttachment: (UUID) -> Void

    private var speakerCount: Int {
        Set((vm.transcriptResult?.segments ?? []).map(\.speakerLabel).filter { !$0.isEmpty }).count
    }

    private var chapters: [(time: TimeInterval, title: String)] {
        guard let segments = vm.transcriptResult?.segments, !segments.isEmpty else { return [] }
        let maxChapters = 4
        let step = max(1, segments.count / maxChapters)
        return stride(from: 0, to: segments.count, by: step).map { index in
            let segment = segments[index]
            let title = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (segment.startTime, String(title.prefix(28)))
        }
    }

    var body: some View {
        if vm.isSummarizing {
            V6GenerationInlineProgress(label: "要約を作成中…", progress: vm.summarizationProgress)
                .padding(.top, 40)
        } else if let result = vm.summaryResult {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(vm.formatDuration(audioFile.duration)) ・ 話者\(speakerCount)名 ・ タスク\(result.actionItems.count)件")
                    .font(.system(size: 12.5))
                    .foregroundStyle(V6Color.muted)

                if !chapters.isEmpty {
                    V6SummarySection(title: "チャプター") {
                        VStack(spacing: 2) {
                            ForEach(Array(chapters.enumerated()), id: \.offset) { _, chapter in
                                Button {
                                    onSeekToTranscript(chapter.time)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(vm.formatTime(chapter.time))
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(V6Color.muted)
                                            .frame(width: 38, alignment: .leading)
                                        Text(chapter.title)
                                            .font(.system(size: 14))
                                            .foregroundStyle(V6Color.ink)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(V6Color.neutralBorder)
                                    }
                                    .padding(.vertical, 9)
                                    .padding(.horizontal, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(V6RowPressStyle())
                            }
                        }
                    }
                }

                if !result.decisions.isNilOrEmpty {
                    V6SummarySection(title: "決定事項") {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(result.decisions ?? [], id: \.self) { decision in
                                Text("・\(decision)")
                                    .font(.system(size: 14))
                                    .lineSpacing(6)
                                    .foregroundStyle(V6Color.tertiary)
                            }
                        }
                    }
                }

                if !result.actionItems.isEmpty {
                    V6SummarySection(title: "次のアクション") {
                        VStack(spacing: 12) {
                            ForEach(result.actionItems, id: \.self) { action in
                                HStack(spacing: 8) {
                                    Text(action)
                                        .font(.system(size: 14))
                                        .foregroundStyle(V6Color.ink)
                                    Spacer()
                                    Text("タスク化")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(V6Color.ink)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(V6Color.ink, lineWidth: 1)
                                        }
                                }
                            }
                        }
                    }
                }

                attachmentsSection
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        } else if audioFile.isSummarized {
            V6TabPlaceholder(title: "要約を読み込めませんでした", description: "保存済みデータの取得後に、このタブへ表示されます。")
        } else if vm.transcriptResult != nil || audioFile.isTranscribed {
            VStack(spacing: 10) {
                Text("要約はまだ生成されていません")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                Text("文字起こしのみ完了しています。あとから要約を作成できます。")
                    .font(.system(size: 12.5))
                    .lineSpacing(5)
                    .foregroundStyle(V6Color.muted)
                    .multilineTextAlignment(.center)
                Button {
                    vm.startSummarization()
                } label: {
                    Text("要約を生成")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(V6Color.ink, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
                }
                .buttonStyle(V6ScalePressButtonStyleShared())
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .padding(.horizontal, 10)
        } else {
            V6TabPlaceholder(
                title: "先に文字起こしが必要です",
                description: "要約タブは文字起こし結果をもとに作成されます。まず文字起こしタブで実行してください。"
            )
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        V6SummarySection(title: "添付", caption: "Ask AI が内容を読み取ります") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(vm.photoAttachments) { attachment in
                    Button {
                        onPreviewAttachment(attachment.id)
                    } label: {
                        FileDetailHelpers.memoThumbnail(for: attachment)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                PhotosPickerButton { data in
                    Task { await vm.importPhoto(from: data) }
                }
            }
        }
    }
}

/// Reusable "section title + content" block matching `.dc.html`'s summary sections
/// (700/15 title, 10pt bottom margin).
struct V6SummarySection<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                if let caption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(V6Color.quiet)
                }
            }
            content
        }
    }
}

struct V6TabPlaceholder: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(V6Color.ink)
            Text(description)
                .font(.system(size: 12.5))
                .lineSpacing(5)
                .foregroundStyle(V6Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }
}

struct V6GenerationInlineProgress: View {
    let label: String
    let progress: Double

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .tint(V6Color.ink)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(V6Color.muted)
        }
        .padding(.horizontal, 30)
    }
}

private struct PhotosPickerButton: View {
    let onPicked: (Data) -> Void
    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "D9D9D9"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(V6Color.quiet)
                }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    onPicked(data)
                }
                selection = nil
            }
        }
    }
}

struct V6RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? V6Color.soft : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension Optional where Wrapped == [String] {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
