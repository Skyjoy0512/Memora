import SwiftUI

struct LiveRecordingBanner: View {
    let duration: TimeInterval
    let onTap: () -> Void
    let onStop: () -> Void

    @State private var isBlinking = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MemoraSpacing.sm) {
                // Recording indicator with glow
                Circle()
                    .fill(MemoraColor.accentRed)
                    .frame(width: 6, height: 6)
                    .opacity(isBlinking ? 1.0 : 0.3)
                    .nothingGlow(.init(
                        color: MemoraColor.accentRed.opacity(0.4),
                        radius: 8,
                        intensity: 0.5,
                        animated: true
                    ))

                // Duration
                Text(formatDuration(duration))
                    .font(MemoraTypography.subheadline)
                    .foregroundStyle(MemoraColor.textPrimary)
                    .monospacedDigit()

                // Waveform placeholder
                WaveformIndicator()

                Spacer()

                // Stop button
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(MemoraTypography.body)
                        .foregroundStyle(MemoraColor.accentRed)
                }
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .frame(height: 52)
            .glassCard(.default)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct WaveformIndicator: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 20)
    @State private var displayLink: Timer?

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(MemoraColor.accentNothing.opacity(0.3))
                    .frame(width: 2, height: 12 * levels[i])
            }
        }
        .frame(width: 60)
        .onAppear {
            displayLink = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                for i in 0..<levels.count {
                    levels[i] = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
        .onDisappear {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}
