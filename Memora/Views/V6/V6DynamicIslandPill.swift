import SwiftUI

/// System-wide Dynamic Island pill (in-app reproduction — real Live Activity integration is a
/// separate epic). Renders whatever `V6IslandController` publishes; morphs width/height/radius
/// between modes exactly as `.dc.html`'s `islandDimsByMode` table. Pin to the top of the phone
/// frame from `ContentView` (`top: 11pt`, horizontally centered, ignoring the top safe area).
struct V6DynamicIslandPill: View {
    @Environment(V6IslandController.self) private var island
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let frame = dimensions(for: island.mode)
        content
            .frame(width: frame.w, height: frame.h)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: frame.r, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: frame.r, style: .continuous))
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowOpacity > 0 ? 12 : 0, y: shadowOpacity > 0 ? 8 : 0)
            .contentShape(RoundedRectangle(cornerRadius: frame.r, style: .continuous))
            .onTapGesture { island.handleTap() }
            .animation(reduceMotion ? nil : V6Anim.islandMorph, value: frame)
    }

    private var backgroundColor: Color {
        island.mode == .morphingToAsk ? V6Color.white : V6Color.islandSurface
    }

    private var shadowOpacity: Double {
        island.mode == .idle ? 0 : 0.28
    }

    @ViewBuilder
    private var content: some View {
        switch island.mode {
        case .idle, .morphingToAsk:
            Color.clear
        case .snackbar:
            snackbarContent
        case .liveRecording:
            liveRecordingContent
        case .liveGeneration:
            liveGenerationContent
        case .ask:
            if island.askAnswerText != nil {
                askAnswerContent
            } else {
                askNoAnswerContent
            }
        }
    }

    // MARK: - Snackbar

    private var snackbarContent: some View {
        HStack(spacing: 10) {
            snackbarIcon
            Text(island.snackbarText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            if let actionLabel = island.snackbarActionLabel {
                Button {
                    island.runSnackbarAction()
                } label: {
                    Text(actionLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var snackbarIcon: some View {
        switch island.snackbarTone {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(V6Color.success)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(V6Color.accent)
        case .progress:
            V6SpinnerArc(diameter: 16, trackColor: Color(hex: "4A4A4E"))
        }
    }

    // MARK: - Live recording

    private var liveRecordingContent: some View {
        HStack(spacing: 8) {
            V6PulsingDot(
                color: island.isRecordingPaused ? V6Color.muted : V6Color.accent,
                isPulsing: !island.isRecordingPaused
            )
            Text(island.recordingElapsedText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .fixedSize()
            HStack(spacing: 2) {
                ForEach(Array(island.recordingWaveHeights.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(.white)
                        .frame(width: 2, height: height)
                }
            }
            .frame(height: 14, alignment: .center)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: island.recordingWaveHeights)
    }

    // MARK: - Live generation

    private var liveGenerationContent: some View {
        HStack(spacing: 8) {
            V6SpinnerArc(diameter: 14, trackColor: Color(hex: "4A4A4E"))
            Text(island.generationStepLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ask capsule (no answer yet)

    private var askNoAnswerContent: some View {
        HStack(spacing: 10) {
            Text(island.isAskListening ? "聞き取っています…" : "Search or Ask")
                .font(.system(size: 15))
                .foregroundStyle(V6Color.muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                island.startAskListening(
                    demoQuery: "この前の定例の決定事項をまとめて",
                    demoAnswer: "2025-01-24 エンジニア定例より:\n・音声データはCloud Storageへ保存\n・要約生成は非同期ジョブに変更",
                    sourceLabel: "2025-01-24_エンジニア定例"
                )
            } label: {
                ZStack {
                    if island.isAskListening {
                        HStack(spacing: 2.5) {
                            ForEach([11.0, 16.0, 13.0, 15.0], id: \.self) { height in
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(.white)
                                    .frame(width: 2.5, height: height)
                            }
                        }
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
    }

    // MARK: - Ask capsule (answer)

    private var askAnswerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(island.askQueryLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(V6Color.muted)
                .lineLimit(1)
                .padding(.bottom, 6)

            ScrollView(showsIndicators: false) {
                Text(island.askAnswerText ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .lineSpacing(7.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button {
                    island.tapAskSource()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc")
                            .font(.system(size: 9))
                        Text(island.askSourceLabel)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 6)

            Text("タップして Ask で続ける ›")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(V6Color.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture { island.morphToAskTab() }
    }

    private func dimensions(for mode: V6IslandMode) -> V6IslandFrame {
        switch mode {
        case .idle:
            return V6IslandFrame(V6IslandDims.idle)
        case .snackbar:
            return V6IslandFrame(V6IslandDims.snackbar)
        case .liveRecording:
            return V6IslandFrame(V6IslandDims.liveRec)
        case .liveGeneration:
            return V6IslandFrame(V6IslandDims.liveGen)
        case .ask:
            return V6IslandFrame(island.askAnswerText != nil ? V6IslandDims.askAnswer : V6IslandDims.ask)
        case .morphingToAsk:
            return V6IslandFrame(V6IslandDims.askMorph)
        }
    }
}

private struct V6IslandFrame: Equatable {
    let w: CGFloat
    let h: CGFloat
    let r: CGFloat

    init(_ dims: (CGFloat, CGFloat, CGFloat)) {
        (w, h, r) = dims
    }
}

/// Recording dot with `pulseDot 1s ease-in-out infinite` (opacity 1 → .35 → 1).
private struct V6PulsingDot: View {
    let color: Color
    let isPulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(isPulsing && dimmed ? 0.35 : 1)
            .onAppear { startPulsing() }
            .onChange(of: isPulsing) { _, newValue in
                if newValue { startPulsing() } else { dimmed = false }
            }
    }

    private func startPulsing() {
        guard isPulsing, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            dimmed = true
        }
    }
}

/// `spin .8s linear infinite` — matches the prototype's snackbar/generation spinner.
private struct V6SpinnerArc: View {
    let diameter: CGFloat
    let trackColor: Color
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .stroke(trackColor, lineWidth: 2)
            .overlay {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
            }
            .frame(width: diameter, height: diameter)
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}
