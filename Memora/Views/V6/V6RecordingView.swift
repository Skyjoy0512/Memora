import SwiftUI
import SwiftData

/// Owns the live recording session so it survives "minimize" (dismissing `V6RecordingView` while
/// recording continues in the background, surfaced via the Dynamic Island `liveRecording` mode).
/// Injected as `.environment` from `ContentView`, mirroring `V6IslandController`.
@MainActor
@Observable
final class V6RecordingSessionController {
    /// Bound to `ContentView`'s `.fullScreenCover(isPresented:)`; any view holding this
    /// controller via `.environment` can request the recording screen (Home FAB, Project Detail,
    /// the Dynamic Island's `liveRecording` tap) without ContentView needing to expose per-caller state.
    var wantsPresentation = false
    private(set) var pendingProjectID: UUID?

    private(set) var isActive = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPaused = false
    private(set) var waveHeights: [CGFloat] = Array(repeating: 6, count: 18)
    private(set) var highlightCount = 0
    private(set) var errorMessage: String?

    private var activeProjectID: UUID?
    private let audioRecorder = AudioRecorder()
    private let recordingViewModel = RecordingViewModel()
    private var timerTask: Task<Void, Never>?
    private var levelsTask: Task<Void, Never>?

    func configure(audioFileRepository: AudioFileRepositoryProtocol?) {
        recordingViewModel.configure(audioFileRepository: audioFileRepository)
    }

    func requestPresentation(projectID: UUID? = nil) {
        pendingProjectID = projectID
        wantsPresentation = true
    }

    func start() {
        guard !isActive else { return }
        activeProjectID = pendingProjectID
        pendingProjectID = nil
        errorMessage = nil
        do {
            try audioRecorder.startRecording()
        } catch {
            errorMessage = "録音の開始に失敗しました。マイクへのアクセスを確認してください。"
            return
        }
        recordingViewModel.startRecording()
        isActive = true
        isPaused = false
        elapsed = 0
        highlightCount = 0
        waveHeights = Array(repeating: 6, count: 18)
        startTimers()
    }

    func togglePause() {
        guard isActive else { return }
        if audioRecorder.isPaused {
            audioRecorder.resumeRecording()
        } else {
            audioRecorder.pauseRecording()
        }
        isPaused = audioRecorder.isPaused
    }

    func captureHighlight() {
        guard isActive else { return }
        highlightCount += 1
    }

    func stopAndSave(title: String) -> AudioFile? {
        guard isActive else { return nil }
        stopTimers()
        guard let url = try? audioRecorder.stopRecording() else {
            isActive = false
            return nil
        }
        let finalElapsed = elapsed
        let projectID = activeProjectID
        isActive = false
        isPaused = false
        activeProjectID = nil
        return recordingViewModel.saveRecording(title: title, fileURL: url, duration: finalElapsed, projectID: projectID)
    }

    func discard() {
        guard isActive else { return }
        stopTimers()
        audioRecorder.cancelRecording()
        recordingViewModel.cancelRecording()
        isActive = false
        isPaused = false
        elapsed = 0
        highlightCount = 0
    }

    private func startTimers() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.elapsed = self.audioRecorder.recordingTime
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        levelsTask?.cancel()
        levelsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await level in self.audioRecorder.audioLevels() {
                self.pushLevel(level)
            }
        }
    }

    private func pushLevel(_ level: Float) {
        let base = min(max(CGFloat(level) * 70, 6), 60)
        waveHeights = waveHeights.indices.map { index in
            let jitter = CGFloat.random(in: -8...8)
            return min(max(base + jitter, 6), 60)
        }
    }

    private func stopTimers() {
        timerTask?.cancel()
        timerTask = nil
        levelsTask?.cancel()
        levelsTask = nil
    }

    /// Formats elapsed time as `M:SS`, matching `.dc.html`'s `formatMMSS`.
    var elapsedLabel: String {
        let total = Int(elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Full-screen recording modal (`.dc.html` `modalRecording`). Minimize keeps the session alive at
/// the `ContentView`-owned `V6RecordingSessionController`; the Dynamic Island shows `liveRecording`
/// while this view is off-screen.
struct V6RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(V6RecordingSessionController.self) private var session
    @Environment(CaptureSourceRegistry.self) private var captureRegistry
    @Environment(V6IslandController.self) private var island

    /// Called once the recording is stopped, saved, and ready to move into the generation flow.
    let onFinished: (AudioFile) -> Void

    @State private var showDiscardConfirm = false

    private var omiAdapter: OmiAdapter? {
        captureRegistry.omiAdapter
    }

    var body: some View {
        ZStack {
            V6Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                Text(session.isPaused ? "一時停止中" : "録音中")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(V6Color.quiet)
                    .padding(.bottom, 8)

                Text(session.elapsedLabel)
                    .font(V6Font.recTime)
                    .tracking(-0.44)
                    .foregroundStyle(V6Color.ink)
                    .padding(.bottom, 36)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(session.waveHeights.enumerated()), id: \.offset) { _, height in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(session.isPaused ? Color(hex: "D6D6DB") : V6Color.ink)
                            .frame(width: 4, height: height)
                    }
                }
                .frame(height: 60)
                .padding(.bottom, 40)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: session.waveHeights)

                transcriptArea

                controls
                    .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            .padding(.bottom, 40)

            VStack {
                HStack {
                    circleButton(systemName: "chevron.down") {
                        island.enterLiveRecording()
                        dismiss()
                    }
                    Spacer()
                    circleButton(systemName: "xmark") {
                        showDiscardConfirm = true
                    }
                }
                Spacer()
            }
            .padding(18)

            if showDiscardConfirm {
                discardConfirmOverlay
            }
        }
        .onAppear {
            if !session.isActive {
                session.start()
            }
            island.exitLiveRecording()
        }
        .onDisappear {
            if !showDiscardConfirm {
                island.enterLiveRecording()
            }
        }
    }

    private var transcriptArea: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                if let omiAdapter, omiAdapter.isConnected, !omiAdapter.previewTranscript.isEmpty {
                    Text(omiAdapter.previewTranscript)
                        .font(.system(size: 13.5))
                        .lineSpacing(6)
                        .foregroundStyle(V6Color.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("録音を停止すると自動で文字起こしされます。")
                        .font(.system(size: 13.5))
                        .lineSpacing(6)
                        .foregroundStyle(V6Color.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(V6Color.paleLine).frame(height: 1)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button {
                session.togglePause()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(V6Color.ink)
                    .frame(width: 52, height: 52)
                    .background(V6Color.soft, in: Circle())
            }
            .buttonStyle(V6ScalePressButtonStyleShared())

            Button {
                finishRecording()
            } label: {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .frame(width: 72, height: 72)
                    .background(V6Color.ink, in: Circle())
            }
            .buttonStyle(V6ScalePressButtonStyleShared())

            Button {
                session.captureHighlight()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(V6Color.ink)
                        .frame(width: 52, height: 52)
                        .background(V6Color.soft, in: Circle())

                    if session.highlightCount > 0 {
                        Text("\(session.highlightCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(V6Color.ink, in: Capsule())
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(V6ScalePressButtonStyleShared())
        }
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(V6Color.tertiary)
                .frame(width: 40, height: 40)
                .background(V6Color.soft, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func finishRecording() {
        let title = Self.defaultTitleFormatter.string(from: .now)
        guard let file = session.stopAndSave(title: "録音 \(title)") else { return }
        island.exitLiveRecording()
        onFinished(file)
    }

    private var discardConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("録音を破棄しますか？")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(V6Color.ink)
                    Text("ここまでの録音内容は保存されません。")
                        .font(.system(size: 12.5))
                        .lineSpacing(4)
                        .foregroundStyle(V6Color.muted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    Button("録音を続ける") {
                        showDiscardConfirm = false
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(V6Color.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(V6Color.fillStrong, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))

                    Button("破棄する") {
                        session.discard()
                        showDiscardConfirm = false
                        island.exitLiveRecording()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(V6Color.accent, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
                }
            }
            .padding(20)
            .background(V6Color.white, in: RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous))
            .padding(.horizontal, 40)
        }
    }

    private static let defaultTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter
    }()
}

/// Shared scale-down press effect (also used by the FAB). Kept internal to V6 views.
struct V6ScalePressButtonStyleShared: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}
