import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
            // プロジェクト選択
            HStack {
                Text("プロジェクト:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(action: { showProjectPicker = true }) {
                    HStack(spacing: 4) {
                        Text(selectedProject?.title ?? "未選択")
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(MemoraColor.divider.opacity(0.1))
                    .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .padding(.top, 8)

            Divider()

            // カレンダーイベント提案
            if let eventTitle = suggestedEventTitle {
                Button {
                    useEventTitle.toggle()
                } label: {
                    HStack(spacing: MemoraSpacing.sm) {
                        Image(systemName: useEventTitle ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(useEventTitle ? MemoraColor.accentBlue : MemoraColor.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("カレンダーから提案")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                            Text(eventTitle)
                                .font(MemoraTypography.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(MemoraSpacing.sm)
                    .background(MemoraColor.accentBlue.opacity(useEventTitle ? 0.1 : 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            VStack(spacing: 21) {
                Spacer()

                // エラーメッセージ表示
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(MemoraColor.accentRed)
                        .padding()
                        .background(MemoraColor.accentRed.opacity(0.1))
                        .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                        .padding(.horizontal)
                }

                // 録音時間表示
                Text(formatTime(recordingTime))
                    .font(.system(.largeTitle, design: .monospaced).weight(.light))
                    .foregroundStyle(.primary)

                // 波形表示（プレースホルダー）
                HStack(spacing: 5) {
                    ForEach(0..<20, id: \.self) { index in
                        Rectangle()
                            .fill(audioRecorder.isRecording ? MemoraColor.accentNothing.opacity(0.4) : MemoraColor.divider.opacity(0.3))
                            .frame(width: 4, height: audioRecorder.isRecording ? CGFloat.random(in: 10...50) : 20)
                            .animation(
                                .easeInOut(duration: 0.2)
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
                        Circle()
                            .fill(audioRecorder.isRecording ? MemoraColor.accentRed.opacity(0.15) : MemoraColor.accentNothing.opacity(0.15))
                            .frame(width: 70, height: 70)
                            .nothingGlow(.init(color: audioRecorder.isRecording ? MemoraColor.accentRed.opacity(0.3) : MemoraColor.accentNothingGlow, radius: 20, intensity: 0.4, animated: true))

                        if audioRecorder.isRecording {
                            Rectangle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                                .clipShape(.rect(cornerRadius: 4))
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(.bottom, MemoraSpacing.xxxl)
            }
        }
        .navigationTitle("録音")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    cancelRecording()
                }
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

                onRecordingSaved?(savedAudioFile)
                dismiss()
            } catch {
                viewModel.errorMessage = "録音の停止に失敗しました。もう一度お試しください。"
                print("録音停止エラー: \(error)")
            }
        } else {
            // 録音開始
            viewModel.startRecording()
            do {
                try audioRecorder.startRecording()
                startTimer()
            } catch {
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
