import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let initialProject: Project?
    let onRecordingSaved: ((AudioFile) -> Void)?
    @State private var viewModel = RecordingViewModel()
    @State private var audioRecorder = AudioRecorder()
    @State private var recordingTime: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var selectedProject: Project?
    @State private var showProjectPicker = false
    @State private var suggestedEventTitle: String?
    @State private var useEventTitle = false
    @State private var pulseRecording = false

    // プロジェクト一覧
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    init(
        initialProject: Project? = nil,
        onRecordingSaved: ((AudioFile) -> Void)? = nil
    ) {
        self.initialProject = initialProject
        self.onRecordingSaved = onRecordingSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            // プロジェクト選択 (glassCard background)
            HStack {
                Text("プロジェクト:")
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textSecondary)

                Button(action: { showProjectPicker = true }) {
                    HStack(spacing: MemoraSpacing.xs) {
                        Text(selectedProject?.title ?? "未選択")
                            .font(MemoraTypography.phiBody)
                            .foregroundStyle(MemoraColor.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(MemoraTypography.phiCaption)
                            .foregroundStyle(MemoraColor.textTertiary)
                    }
                    .padding(.horizontal, MemoraSpacing.md)
                    .padding(.vertical, MemoraSpacing.sm)
                    .background(MemoraColor.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: MemoraRadius.md)
                            .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.top, MemoraSpacing.md)
            .padding(.bottom, MemoraSpacing.sm)

            // カレンダーイベント提案 (accentNothing checkbox)
            if let eventTitle = suggestedEventTitle {
                Button {
                    useEventTitle.toggle()
                } label: {
                    HStack(spacing: MemoraSpacing.sm) {
                        Image(systemName: useEventTitle ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(useEventTitle ? MemoraColor.interactivePrimary : MemoraColor.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("カレンダーから提案")
                                .font(MemoraTypography.phiCaption)
                                .foregroundStyle(MemoraColor.textTertiary)
                            Text(eventTitle)
                                .font(MemoraTypography.phiBody)
                                .foregroundStyle(MemoraColor.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(MemoraSpacing.sm)
                    .background(
                        MemoraColor.interactivePrimary.opacity(useEventTitle ? 0.12 : 0.05)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
                }
                .padding(.horizontal, MemoraSpacing.lg)
                .padding(.top, MemoraSpacing.xs)
            }

            VStack(spacing: MemoraSpacing.phi4) {
                Spacer()

                // エラーメッセージ表示
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.accentRed)
                        .padding(MemoraSpacing.sm)
                        .background(MemoraColor.accentRed.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
                        .padding(.horizontal, MemoraSpacing.lg)
                }

                // 録音時間表示
                Text(formatTime(recordingTime))
                    .font(MemoraTypography.phiDisplay)
                    .foregroundStyle(MemoraColor.textPrimary)
                    .monospacedDigit()

                // 波形表示
                HStack(spacing: MemoraSpacing.xxxs) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: MemoraRadius.sm)
                            .fill(audioRecorder.isRecording ? MemoraColor.interactivePrimary.opacity(0.3) : MemoraColor.divider.opacity(0.3))
                            .frame(width: 4, height: audioRecorder.isRecording ? CGFloat.random(in: 10...50) : 20)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.2)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.02),
                                value: audioRecorder.isRecording
                            )
                    }
                }
                .frame(height: 60)

                Spacer()

                // 録音ボタン
                Button(action: toggleRecording) {
                    ZStack {
                        // 80pt outer ring
                        Circle()
                            .stroke(MemoraColor.interactivePrimary, lineWidth: 3)
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseRecording ? 1.05 : 1.0)

                        // Inner button
                        if audioRecorder.isRecording {
                            RoundedRectangle(cornerRadius: MemoraRadius.sm)
                                .fill(MemoraColor.accentRed)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(MemoraColor.interactivePrimary)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(.bottom, MemoraSpacing.xxxl)
            }
        }
        .background(MemoraColor.surfacePrimary)
        .navigationTitle("録音")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    cancelRecording()
                }
                .foregroundStyle(MemoraColor.textSecondary)
            }
        }
        .onAppear {
            viewModel.configure(audioFileRepository: AudioFileRepository(modelContext: modelContext))
            if selectedProject == nil {
                selectedProject = initialProject
            }
            suggestCalendarEvent()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: audioRecorder.isRecording) { _, isRecording in
            if reduceMotion {
                pulseRecording = isRecording
            } else {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseRecording = isRecording
                }
            }
        }
        .sheet(isPresented: $showProjectPicker) {
            ProjectPickerSheet(
                projects: projects,
                selectedProject: $selectedProject
            )
        }
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            // 録音停止
            do {
                let url = try audioRecorder.stopRecording()
                stopTimer()
                viewModel.stopRecording()

                guard let savedAudioFile = viewModel.saveRecording(
                    title: formatRecordingTitle(),
                    fileURL: url,
                    duration: recordingTime,
                    projectID: selectedProject?.id
                ) else {
                    return
                }

                MemoraHaptics.success()
                onRecordingSaved?(savedAudioFile)
                dismiss()
            } catch {
                MemoraHaptics.error()
                viewModel.errorMessage = "録音の停止に失敗しました。もう一度お試しください。"
                print("録音停止エラー: \(error)")
            }
        } else {
            // 録音開始
            MemoraHaptics.medium()
            viewModel.startRecording()
            do {
                try audioRecorder.startRecording()
                startTimer()
            } catch {
                MemoraHaptics.error()
                viewModel.errorMessage = "録音の開始に失敗しました。マイクへのアクセスを確認してください。"
                print("録音開始エラー: \(error)")
            }
        }
    }

    private func cancelRecording() {
        audioRecorder.cancelRecording()
        viewModel.cancelRecording()
        stopTimer()
        dismiss()
    }

    private func startTimer() {
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                syncRecordingTime()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    @MainActor
    private func syncRecordingTime() {
        recordingTime = audioRecorder.recordingTime
        viewModel.recordingTime = recordingTime
        viewModel.isRecording = audioRecorder.isRecording
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }

    private static let recordingTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f
    }()

    private func formatRecordingTitle() -> String {
        if useEventTitle, let eventTitle = suggestedEventTitle {
            return eventTitle
        }
        return "録音 \(Self.recordingTitleFormatter.string(from: .now))"
    }

    private func suggestCalendarEvent() {
        let service = CalendarService()
        guard service.isAuthorized else { return }

        let today = Date()
        let events = service.fetchEvents(for: today)
        let now = Date()

        // 現在時刻と重なるイベントを探す
        let ongoing = events.filter { event in
            event.startDate <= now && event.endDate > now
        }.sorted { $0.startDate < $1.startDate }

        if let event = ongoing.first {
            suggestedEventTitle = event.title
        }
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
