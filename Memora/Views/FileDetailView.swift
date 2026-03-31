import SwiftUI
import SwiftData

struct FileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.repositoryFactory) private var repoFactory
    let audioFile: AudioFile
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"
    @AppStorage("apiKey_openai") private var apiKeyOpenAI = ""
    @AppStorage("apiKey_gemini") private var apiKeyGemini = ""
    @AppStorage("apiKey_deepseek") private var apiKeyDeepSeek = ""
    @State private var viewModel: FileDetailViewModel?

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    var currentAPIKey: String {
        switch currentProvider {
        case .openai: return apiKeyOpenAI
        case .gemini: return apiKeyGemini
        case .deepseek: return apiKeyDeepSeek
        }
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    viewModel?.stopPlayback()
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel?.showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(viewModel?.audioURL == nil && viewModel?.transcriptResult == nil)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    viewModel?.showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let vm = FileDetailViewModel(
                audioFile: audioFile,
                repoFactory: repoFactory!,
                provider: currentProvider,
                transcriptionMode: currentTranscriptionMode,
                apiKey: currentAPIKey
            )
            vm.setupAudioPlayer()
            vm.loadSavedData()
            viewModel = vm
        }
        .task {
            await viewModel?.setupEngines()
        }
        .onDisappear {
            viewModel?.cleanup()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: FileDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: MemoraSpacing.xxl) {
                Spacer()
                    .frame(height: MemoraSpacing.xxl)

                // 音声波形イメージ
                Image(systemName: "waveform")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(MemoraColor.textSecondary)

                // タイトル
                Text(audioFile.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // メタデータ
                HStack(spacing: MemoraSpacing.xxl) {
                    Label(vm.formatDate(audioFile.createdAt), systemImage: "calendar")
                    Label(vm.formatDuration(audioFile.duration), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal)

                // プレイヤーコントロール
                playerControls(vm: vm)

                Divider()
                    .padding(.horizontal)

                // アクションボタン
                actionButtons(vm: vm)

                Spacer()
            }
            .padding()
        }
        .navigationDestination(isPresented: Binding(
            get: { vm.showTranscriptView },
            set: { vm.showTranscriptView = $0 }
        )) {
            if let result = vm.transcriptResult {
                TranscriptView(result: result)
            } else {
                Text("文字起こしデータがありません")
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { vm.showSummaryView },
            set: { vm.showSummaryView = $0 }
        )) {
            if let result = vm.summaryResult {
                SummaryView(result: result)
            } else {
                Text("要約データがありません")
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showGenerationFlow },
            set: { vm.showGenerationFlow = $0 }
        )) {
            GenerationFlowSheet(isPresented: Binding(
                get: { vm.showGenerationFlow },
                set: { vm.showGenerationFlow = $0 }
            )) { config in
                vm.startSummarization(with: config)
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showShareSheet },
            set: { vm.showShareSheet = $0 }
        )) {
            ShareSheet(
                shareText: vm.transcriptResult?.text,
                shareURL: vm.audioURL,
                audioFile: audioFile
            )
        }
        .alert("ファイルを削除", isPresented: Binding(
            get: { vm.showDeleteAlert },
            set: { vm.showDeleteAlert = $0 }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                vm.deleteAudioFile()
                dismiss()
            }
        } message: {
            Text("この録音ファイルを削除しますか？")
        }
        .alert("エラー", isPresented: Binding(
            get: { vm.showErrorAlert },
            set: { vm.showErrorAlert = $0 }
        )) {
            Button("OK", role: .cancel) {
                vm.errorMessage = nil
            }
        } message: {
            if let message = vm.errorMessage {
                Text(message)
            }
        }
        .alert("完了", isPresented: Binding(
            get: { vm.showSuccessAlert },
            set: { vm.showSuccessAlert = $0 }
        )) {
            Button("OK", role: .cancel) {
                vm.successMessage = nil
            }
        } message: {
            if let message = vm.successMessage {
                Text(message)
            }
        }
        .overlay(alignment: .top) {
            if let message = vm.toastMessage {
                ToastOverlay(
                    icon: vm.toastStyle == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    message: message,
                    style: vm.toastStyle,
                    onDismiss: { vm.toastMessage = nil }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.toastMessage)
    }

    // MARK: - Player Controls

    @ViewBuilder
    private func playerControls(vm: FileDetailViewModel) -> some View {
        VStack(spacing: MemoraSpacing.xxl) {
            // プログレスバー
            VStack(spacing: 5) {
                Slider(
                    value: Binding(
                        get: { vm.playbackPosition },
                        set: { newPosition in
                            vm.playbackPosition = newPosition
                        }
                    ),
                    in: 0...max(vm.audioDuration, 1),
                    onEditingChanged: { editing in
                        if !editing && vm.audioDuration > 0 {
                            vm.seek(to: vm.playbackPosition)
                        }
                    }
                )
                .accentColor(MemoraColor.textSecondary)

                HStack {
                    Text(vm.formatTime(vm.playbackPosition))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(vm.formatTime(vm.audioDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // 再生ボタン
            Button(action: { vm.togglePlayback() }) {
                ZStack {
                    Circle()
                        .fill(MemoraColor.divider)
                        .frame(width: 70, height: 70)

                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.vertical, MemoraSpacing.xxl)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(vm: FileDetailViewModel) -> some View {
        VStack(spacing: MemoraSpacing.lg) {
            // 文字起こし
            if vm.isTranscribing {
                VStack(spacing: MemoraSpacing.sm) {
                    SkeletonView(height: 20)
                    SkeletonView(height: 16)
                        .frame(maxWidth: 200)
                    Text("文字起こし中... \(Int(vm.transcriptionProgress * 100))%")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(MemoraColor.divider.opacity(0.1))
                .cornerRadius(MemoraRadius.md)
            } else if vm.transcriptResult != nil {
                Button(action: { vm.showTranscriptView = true }) {
                    Label("文字起こし結果を表示", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            } else if audioFile.isTranscribed {
                Button(action: { vm.showTranscriptView = true }) {
                    Label("文字起こし結果を表示", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            } else {
                Button(action: { vm.startTranscription() }) {
                    Label("文字起こし", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            }

            // 要約
            if vm.isSummarizing {
                VStack(spacing: MemoraSpacing.sm) {
                    SkeletonView(height: 20)
                    SkeletonView(height: 16)
                        .frame(maxWidth: 200)
                    Text("要約中... \(Int(vm.summarizationProgress * 100))%")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(MemoraColor.divider.opacity(0.1))
                .cornerRadius(MemoraRadius.md)
            } else if vm.summaryResult != nil {
                Button(action: { vm.showSummaryView = true }) {
                    Label("要約結果を表示", systemImage: "text.quote")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            } else if audioFile.isSummarized {
                Button(action: { vm.showSummaryView = true }) {
                    Label("要約結果を表示", systemImage: "text.quote")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            } else if vm.transcriptResult != nil || audioFile.isTranscribed {
                Button(action: { vm.showGenerationFlow = true }) {
                    Label("生成", systemImage: "text.quote")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            } else {
                Button(action: {}) {
                    Label("要約", systemImage: "text.quote")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.05))
                        .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.secondary)
            }

            // スピーカー登録
            if vm.audioURL != nil {
                Button(action: { vm.registerPrimarySpeakerSample() }) {
                    VStack(spacing: 6) {
                        Label("この録音を自分の声サンプルに登録", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                        Text("1人だけが話している録音を使うと精度が安定します")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(MemoraColor.divider.opacity(0.08))
                    .cornerRadius(MemoraRadius.md)
                }
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AudioFile.self, configurations: config)

    let audioFile = AudioFile(title: "テスト録音", audioURL: "")
    audioFile.duration = 120

    container.mainContext.insert(audioFile)

    return NavigationStack {
        FileDetailView(audioFile: audioFile)
    }
    .modelContainer(container)
}
