import SwiftUI

// MARK: - Player Controls

struct PlayerControls: View {
    @Bindable var vm: FileDetailViewModel

    var body: some View {
        HStack(spacing: MemoraSpacing.md) {
            // 再生ボタン
            Button(action: { vm.togglePlayback() }) {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(MemoraTypography.chatSegment)
                    .foregroundStyle(MemoraColor.interactivePrimary)
                    .frame(minWidth: MemoraSize.minTapTarget, minHeight: MemoraSize.minTapTarget)
            }

            // プログレスバー
            VStack(spacing: 2) {
                Slider(
                    value: $vm.playbackPosition,
                    in: 0...max(vm.audioDuration, 1),
                    onEditingChanged: { editing in
                        if !editing && vm.audioDuration > 0 {
                            vm.seek(to: vm.playbackPosition)
                        }
                    }
                )
                .tint(MemoraColor.interactivePrimary)

                HStack {
                    Text(vm.formatTime(vm.playbackPosition))
                    Spacer()
                    Text(vm.formatTime(vm.audioDuration))
                }
                .font(MemoraTypography.chatToken)
                .foregroundStyle(MemoraColor.textTertiary)
            }
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.sm)
    }
}
