import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var selectedProject: Project?
    @State private var showProjectPicker = false

    // プロジェクト一覧
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

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
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .padding(.top, 8)

            Divider()

            VStack(spacing: 21) {
                Spacer()

                // エラーメッセージ表示
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // 録音時間表示
                Text(formatTime(recordingTime))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)

                // 波形表示（プレースホルダー）
                HStack(spacing: 5) {
                    ForEach(0..<20, id: \.self) { index in
                        Rectangle()
                            .fill(audioRecorder.isRecording ? Color.gray : Color.gray.opacity(0.3))
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
                            .fill(Color.gray)
                            .frame(width: 70, height: 70)

                        if audioRecorder.isRecording {
                            Rectangle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                                .cornerRadius(4)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(.bottom, 34)
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

                // AudioFile を保存
                let audioFile = AudioFile(
                    title: formatRecordingTitle(),
                    audioURL: url.path,
                    projectID: selectedProject?.id
                )
                audioFile.duration = recordingTime

                modelContext.insert(audioFile)

                dismiss()
            } catch {
                errorMessage = "録音停止エラー: \(error.localizedDescription)"
                print("録音停止エラー: \(error)")
            }
        } else {
            // 録音開始
            errorMessage = nil
            do {
                try audioRecorder.startRecording()
                startTimer()
            } catch {
                errorMessage = "録音開始エラー: \(error.localizedDescription)\n\nシミュレータではマイクが使えない場合があります"
                print("録音開始エラー: \(error)")
            }
        }
    }

    private func cancelRecording() {
        audioRecorder.cancelRecording()
        stopTimer()
        dismiss()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime = audioRecorder.recordingTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }

    private func formatRecordingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return "録音 \(formatter.string(from: Date()))"
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: AudioFile.self, inMemory: true)
}
