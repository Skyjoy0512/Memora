import SwiftUI

struct MeetingCaptureProgressView: View {
    @Bindable var viewModel: MeetingCaptureViewModel
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Recording indicator
            ZStack {
                Circle()
                    .fill(.red.opacity(0.15))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(.red.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)

                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.red)
                        .symbolEffect(.variableColor.iterative, options: .repeating)

                    Text(formatElapsed(viewModel.elapsedSeconds))
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }

            VStack(spacing: 6) {
                Text(viewModel.meetingTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(viewModel.selectedPlatform.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !viewModel.meetingURL.isEmpty {
                    Text(viewModel.meetingURL)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Text("コントロールセンターから\nブロードキャストを停止してください")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(role: .destructive) {
                onStop()
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("キャプチャを停止")
                }
                .font(.body.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.bottom, 40)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .presentationBackground(.ultraThinMaterial)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

#Preview {
    MeetingCaptureProgressView(
        viewModel: MeetingCaptureViewModel(),
        onStop: {}
    )
}
