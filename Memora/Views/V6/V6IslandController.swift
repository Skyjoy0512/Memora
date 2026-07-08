import Foundation
import Observation

/// Tone of a Dynamic Island snackbar message. Source: `.dc.html` `islandToneSuccess/Error/Progress`.
enum V6IslandTone {
    case success
    case error
    case progress
}

/// Dynamic Island pill mode. Source: `.dc.html` `islandMode` state field
/// (`idle` / `snackbar` / `live-rec` / `live-gen` / `ask` / `ask-morph`).
enum V6IslandMode: Equatable {
    case idle
    case snackbar
    case liveRecording
    case liveGeneration
    case ask
    case morphingToAsk
}

/// Drives the system-wide Dynamic Island pill (`V6DynamicIslandPill`). Screens update this
/// controller's state (recording elapsed time, generation progress, snackbar toasts); the pill
/// itself only renders whatever is published here. Injected via `.environment` from `ContentView`.
///
/// Ask-capsule listening/answer here uses demo timing identical to the design prototype (which is
/// itself scripted/fake); wiring the island's Ask answer to the real `AskAIRetrievalService` is
/// done in PR-8 once the Ask tab lands, at which point `startAskListening` is replaced by a call
/// that feeds a real query/answer pair into `setAskAnswer`.
@Observable
final class V6IslandController {
    private(set) var mode: V6IslandMode = .idle

    // Snackbar payload
    private(set) var snackbarTone: V6IslandTone = .success
    private(set) var snackbarText: String = ""
    private(set) var snackbarActionLabel: String?
    private var snackbarAction: (() -> Void)?

    // Live recording payload — driven by the recording flow (PR-5).
    var isRecordingPaused = false
    var recordingElapsedText = "0:00"
    var recordingWaveHeights: [CGFloat] = [6, 6, 6, 6, 6]

    // Live generation payload — driven by the generation flow (PR-5/PR-6).
    var generationStepLabel = ""

    // Ask capsule payload
    private(set) var isAskListening = false
    private(set) var askQueryLabel = ""
    private(set) var askAnswerText: String?
    private(set) var askSourceLabel = ""

    var onOpenRecording: (() -> Void)?
    var onOpenGeneration: (() -> Void)?
    var onOpenAskSource: ((String) -> Void)?
    var onOpenAskTab: (() -> Void)?

    private var isRecordingActiveInBackground = false
    private var advanceTask: Task<Void, Never>?
    private var askListenTask: Task<Void, Never>?
    private var askAnswerTask: Task<Void, Never>?
    private var askAutoDismissTask: Task<Void, Never>?
    private var morphTask: Task<Void, Never>?

    // MARK: - Snackbar (login success, Pro purchase, device connected, retry, completion, ...)

    func showSnackbar(_ text: String, tone: V6IslandTone = .success, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        snackbarTone = tone
        snackbarText = text
        snackbarActionLabel = actionLabel
        snackbarAction = action
        mode = .snackbar
        scheduleAdvance(hasAction: actionLabel != nil)
    }

    func runSnackbarAction() {
        snackbarAction?()
        advance()
    }

    private func scheduleAdvance(hasAction: Bool) {
        advanceTask?.cancel()
        let duration: Double = hasAction ? 5 : 3
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    /// Snackbar → `liveRecording` if a recording is running in the background, else `idle`.
    func advance() {
        guard mode == .snackbar else { return }
        advanceTask?.cancel()
        mode = isRecordingActiveInBackground ? .liveRecording : .idle
    }

    // MARK: - Live recording

    func enterLiveRecording() {
        isRecordingActiveInBackground = true
        if mode != .snackbar { mode = .liveRecording }
    }

    func exitLiveRecording() {
        isRecordingActiveInBackground = false
        if mode == .liveRecording { mode = .idle }
    }

    // MARK: - Live generation

    func enterLiveGeneration(stepLabel: String) {
        generationStepLabel = stepLabel
        if mode != .snackbar { mode = .liveGeneration }
    }

    func updateGenerationStep(_ label: String) {
        generationStepLabel = label
    }

    func exitLiveGeneration() {
        if mode == .liveGeneration { mode = .idle }
    }

    // MARK: - Ask capsule

    func openAskCapsule() {
        askAnswerText = nil
        askQueryLabel = ""
        isAskListening = false
        mode = .ask
    }

    func startAskListening(demoQuery: String, demoAnswer: String, sourceLabel: String) {
        guard mode == .ask, !isAskListening, askAnswerText == nil else { return }
        isAskListening = true
        askListenTask?.cancel()
        askListenTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, let self else { return }
            self.isAskListening = false
            self.askQueryLabel = demoQuery
            self.askAnswerTask?.cancel()
            self.askAnswerTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled, let self else { return }
                self.setAskAnswer(demoAnswer, sourceLabel: sourceLabel)
                self.askAutoDismissTask?.cancel()
                self.askAutoDismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    self?.morphToAskTab()
                }
            }
        }
    }

    func setAskAnswer(_ text: String, sourceLabel: String) {
        askAnswerText = text
        askSourceLabel = sourceLabel
    }

    func dismissAsk() {
        askListenTask?.cancel()
        askAnswerTask?.cancel()
        askAutoDismissTask?.cancel()
        isAskListening = false
        askQueryLabel = ""
        askAnswerText = nil
        mode = .idle
    }

    /// Brief white full-expand transition before switching to the Ask tab (`.dc.html` `doMorphToAsk`, 460ms).
    func morphToAskTab() {
        askAutoDismissTask?.cancel()
        mode = .morphingToAsk
        morphTask?.cancel()
        morphTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(460))
            guard !Task.isCancelled, let self else { return }
            self.dismissAsk()
            self.onOpenAskTab?()
        }
    }

    // MARK: - Tap routing (`.dc.html` `islandTap`)

    func handleTap() {
        switch mode {
        case .idle:
            openAskCapsule()
        case .liveRecording:
            onOpenRecording?()
        case .liveGeneration:
            onOpenGeneration?()
        case .snackbar:
            advance()
        case .ask, .morphingToAsk:
            break
        }
    }

    func tapAskSource() {
        onOpenAskSource?(askSourceLabel)
    }
}
