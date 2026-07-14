import SwiftUI
import SwiftData

/// Drives the post-recording full pipeline (transcription → summary → todos) via the existing
/// `PipelineCoordinator.runFullPipeline`, and survives the progress screen being dismissed
/// ("バックグラウンドで続行" — background continue), reporting completion through
/// `V6IslandController`. Injected as `.environment` from `ContentView`.
@MainActor
@Observable
final class V6GenerationSessionController {
    enum Phase {
        case analyzing
        case transcribing
        case summarizing
        case completed
        case failed(String)
    }

    private(set) var phase: Phase = .analyzing
    private(set) var progress: Double = 0
    private(set) var resultFile: AudioFile?

    private var pipelineTask: Task<Void, Never>?
    var onCompleted: ((AudioFile) -> Void)?

    var stepLabel: String {
        switch phase {
        case .analyzing: "音声を解析中…"
        case .transcribing: "文字起こしを生成中…"
        case .summarizing: "要約を作成中…"
        case .completed: "完了しました"
        case .failed: "生成に失敗しました"
        }
    }

    var isRunning: Bool {
        switch phase {
        case .completed, .failed: false
        default: true
        }
    }

    func start(audioFile: AudioFile, modelContext: ModelContext) {
        pipelineTask?.cancel()
        phase = .analyzing
        progress = 0
        resultFile = nil

        guard let audioURL = Self.resolveAudioURL(audioFile) else {
            phase = .failed("音声ファイルが見つかりません")
            return
        }

        let provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "") ?? .openai
        let transcriptionMode = TranscriptionMode(rawValue: UserDefaults.standard.string(forKey: "transcriptionMode") ?? "") ?? .local
        let apiKey: String = {
            switch provider {
            case .openai: return KeychainService.load(key: .apiKeyOpenAI)
            case .gemini: return KeychainService.load(key: .apiKeyGemini)
            case .deepseek: return KeychainService.load(key: .apiKeyDeepSeek)
            case .local: return ""
            }
        }()

        let coordinator = PipelineCoordinator(
            transcriptionEngine: TranscriptionEngine(),
            summarizationEngine: SummarizationEngine(),
            modelContext: modelContext
        )

        pipelineTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = coordinator.runFullPipeline(
                audioURL: audioURL,
                audioFile: audioFile,
                apiKey: apiKey,
                provider: provider,
                transcriptionMode: transcriptionMode,
                config: GenerationConfig()
            )
            for await event in stream {
                guard !Task.isCancelled else { return }
                self.handle(event, audioFile: audioFile)
            }
        }
    }

    /// Stop waiting locally without cancelling the underlying pipeline — used by "スキップ" to
    /// jump straight to File Detail while transcription/summary keep running.
    func detach() {
        pipelineTask = nil
    }

    private func handle(_ event: PipelineEvent, audioFile: AudioFile) {
        switch event {
        case .stepStarted(let step), .stepCompleted(let step):
            phase = Self.phase(for: step)
            progress = Self.progressValue(for: phase)
        case .chunkProgress:
            break
        case .completed:
            phase = .completed
            progress = 1
            resultFile = audioFile
            onCompleted?(audioFile)
        case .failed(_, let error):
            phase = .failed(error.localizedDescription)
        }
    }

    private static func phase(for step: PipelineStep) -> Phase {
        switch step {
        case .none, .loadingAudio, .chunking:
            return .analyzing
        case .transcribing, .mergingTranscripts:
            return .transcribing
        case .extractingMetadata, .generatingSummary, .extractingTodos, .finalizing:
            return .summarizing
        }
    }

    private static func progressValue(for phase: Phase) -> Double {
        switch phase {
        case .analyzing: 0.1
        case .transcribing: 0.45
        case .summarizing: 0.8
        case .completed: 1.0
        case .failed: 0
        }
    }

    private static func resolveAudioURL(_ audioFile: AudioFile) -> URL? {
        let path = audioFile.audioURL
        if path.hasPrefix("file://") { return URL(string: path) }
        return URL(fileURLWithPath: path)
    }
}

/// Generation progress screen (`.dc.html` `modalGenerating`). Circular indeterminate progress +
/// status line while the full pipeline runs asynchronously; "skip" jumps straight to File Detail
/// (transcription/summary keep running), "background" dismisses to the Dynamic Island `liveGeneration`
/// mode which posts a completion snackbar when done.
struct V6GenerationProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(V6GenerationSessionController.self) private var session
    @Environment(V6IslandController.self) private var island

    let onSkip: () -> Void
    let onBackground: () -> Void
    let onCompleted: (AudioFile) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            V6GenerationSpinner()
                .frame(width: 52, height: 52)

            Text(session.stepLabel)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(V6Color.ink)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(V6Color.line)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(V6Color.ink)
                            .frame(width: proxy.size.width * session.progress)
                            .animation(.easeOut(duration: 0.5), value: session.progress)
                    }
            }
            .frame(width: 220, height: 4)

            Text("この処理はバックグラウンドで継続されます。ホームに戻っても続行できます。")
                .font(.system(size: 12.5))
                .lineSpacing(5)
                .foregroundStyle(V6Color.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Button("バックグラウンドで続行") {
                island.enterLiveGeneration(stepLabel: session.stepLabel)
                onBackground()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(V6Color.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(V6Color.soft, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))

            Spacer()

            Button("スキップして開く", action: onSkip)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(V6Color.quiet)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(V6Color.white.ignoresSafeArea())
        .onChange(of: session.resultFile) { _, file in
            guard let file else { return }
            onCompleted(file)
        }
    }
}

private struct V6GenerationSpinner: View {
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .stroke(V6Color.line, lineWidth: 3)
            .overlay {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(V6Color.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
            }
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}
