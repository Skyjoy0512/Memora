import SwiftUI

/// Transcript tab (`.dc.html` `fdTranscriptActive`): sticky player bar (play/pause, time, speed
/// cycle, seek) + speaker/time/text lines — tapping a line seeks the player.
struct TranscriptTab: View {
    @Bindable var vm: FileDetailViewModel
    let audioFile: AudioFile

    var body: some View {
        if vm.isTranscribing {
            V6GenerationInlineProgress(label: "文字起こしを生成中…", progress: vm.transcriptionProgress)
                .padding(.top, 40)
        } else if let result = vm.transcriptResult {
            VStack(alignment: .leading, spacing: 0) {
                playerBar

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { _, segment in
                        let isActive = vm.playbackPosition >= segment.startTime && vm.playbackPosition < segment.endTime
                        Button {
                            vm.seekToTime(segment.startTime)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    if !segment.speakerLabel.isEmpty {
                                        Text(segment.speakerLabel)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(V6Color.tertiary)
                                    }
                                    Text(vm.formatTime(segment.startTime))
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(V6Color.quiet)
                                }
                                Text(segment.text)
                                    .font(.system(size: 14))
                                    .lineSpacing(6)
                                    .foregroundStyle(V6Color.ink)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isActive ? V6Color.soft : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 24)
        } else if audioFile.isTranscribed {
            V6TabPlaceholder(title: "文字起こしを読み込めませんでした", description: "保存済みデータの取得後に、このタブへ全文を表示します。")
        } else {
            VStack(spacing: 10) {
                Text("文字起こしはまだありません")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                Text("録音を文字起こしすると、全文とタイムスタンプ付きセグメントをこのタブで確認できます。")
                    .font(.system(size: 12.5))
                    .lineSpacing(5)
                    .foregroundStyle(V6Color.muted)
                    .multilineTextAlignment(.center)
                Button {
                    vm.startTranscription()
                } label: {
                    Text("文字起こしを開始")
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
            .padding(.horizontal, 20)
        }
    }

    private var playerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    vm.togglePlayback()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(V6Color.ink)
                        .frame(width: 38, height: 38)
                        .overlay {
                            Circle().stroke(V6Color.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Text("\(vm.formatTime(vm.playbackPosition)) / \(vm.formatTime(vm.audioDuration))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(V6Color.ink)

                Spacer()

                Button {
                    vm.cyclePlaybackSpeed()
                } label: {
                    Text(String(format: "%gx", vm.playbackRate))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(V6Color.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(V6Color.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            GeometryReader { proxy in
                let ratio = vm.audioDuration > 0 ? vm.playbackPosition / vm.audioDuration : 0
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: "EEEEEE"))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(V6Color.ink)
                            .frame(width: proxy.size.width * ratio)
                    }
                    .contentShape(Rectangle().inset(by: -8))
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            guard vm.audioDuration > 0 else { return }
                            let pct = min(max(value.location.x / proxy.size.width, 0), 1)
                            vm.seek(to: vm.audioDuration * pct)
                        }
                    )
            }
            .frame(height: 12)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(V6Color.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V6Color.paleLine).frame(height: 1)
        }
    }
}
