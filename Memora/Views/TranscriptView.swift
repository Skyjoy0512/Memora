import SwiftUI

struct TranscriptView: View {
    let result: TranscriptResult
    @State private var showSegments = true
    @State private var searchText = ""
    @State private var showCopiedToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MemoraSpacing.xxl) {
                // メタ情報
                HStack(spacing: MemoraSpacing.lg) {
                    Label("\(result.segments.count) セグメント", systemImage: "person.2")
                    if result.duration > 0 {
                        Label(formatDuration(result.duration), systemImage: "clock")
                    }
                }
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)

                // 検索バー
                searchBar

                // 文字起こし全文
                transcriptCard

                // 話者セグメント
                if showSegments && !result.segments.isEmpty {
                    segmentsCard
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
        .navigationTitle("文字起こし")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSegments.toggle()
                    }
                } label: {
                    Image(systemName: showSegments ? "person.2.fill" : "person.2")
                }

                Button {
                    copyTranscript()
                    showCopiedToast = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        .overlay {
            if showCopiedToast {
                ToastOverlay(
                    icon: "checkmark.circle.fill",
                    message: "コピーしました",
                    style: .success,
                    onDismiss: { showCopiedToast = false }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("検索", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.xs)
        .background(MemoraColor.divider.opacity(0.1))
        .cornerRadius(MemoraRadius.sm)
    }

    // MARK: - Transcript Card

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Text("文字起こし")
                .font(MemoraTypography.headline)

            Text(highlightedText(result.text, search: searchText))
                .font(MemoraTypography.body)
                .foregroundStyle(.primary)
                .lineSpacing(6)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Segments Card

    private var segmentsCard: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Text("話者分離")
                .font(MemoraTypography.headline)

            let filtered = filteredSegments
            if filtered.isEmpty && !searchText.isEmpty {
                Text("一致するセグメントがありません")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, MemoraSpacing.sm)
            } else {
                ForEach(filtered.indices, id: \.self) { index in
                    SpeakerSegmentView(segment: filtered[index])
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Helpers

    private var filteredSegments: [SpeakerSegment] {
        guard !searchText.isEmpty else { return result.segments }
        return result.segments.filter { segment in
            segment.text.localizedCaseInsensitiveContains(searchText) ||
            segment.speakerLabel.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func highlightedText(_ text: String, search: String) -> AttributedString {
        guard !search.isEmpty else {
            return AttributedString(text)
        }
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerSearch = search.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText.range(of: lowerSearch, range: searchStart..<lowerText.endIndex) {
            let attrRange = Range(range, in: attributed)!
            attributed[attrRange].backgroundColor = MemoraColor.accentBlue.opacity(0.2)
            attributed[attrRange].foregroundColor = MemoraColor.accentBlue
            searchStart = range.upperBound
        }
        return attributed
    }

    private func copyTranscript() {
        var text = result.text
        if !result.segments.isEmpty {
            text += "\n\n--- 話者分離 ---\n"
            for segment in result.segments {
                let start = formatTime(segment.startTime)
                let end = formatTime(segment.endTime)
                text += "\n[\(start) - \(end)] \(segment.speakerLabel):\n\(segment.text)\n"
            }
        }
        UIPasteboard.general.string = text
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SpeakerSegmentView: View {
    let segment: SpeakerSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.fill")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.accentBlue)

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
        .padding(.horizontal, MemoraSpacing.xs)
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
