import SwiftUI
import SwiftData

struct FileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.repositoryFactory) private var repoFactory
    @Environment(\.modelContext) private var modelContext
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
                loadingSkeleton
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
                modelContext: modelContext,
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

                // 画像アップロード行
                uploadImageRow(vm: vm)

                // 添付サムネイル（TODO: attachments 実装後に有効化）
                // attachmentsRow(vm: vm)

                // アクションボタン
                actionButtons(vm: vm)

                // ---- 生成結果セクション ----
                if let result = vm.summaryResult {
                    generatedResultSections(vm: vm, result: result)
                }

                Spacer()
                    .frame(height: 80) // Ask AI 入力欄のスペース
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            askAIInputBar(vm: vm)
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
                vm.startPipeline(config: config)
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
        .overlay(alignment: .top) {
            if vm.showErrorAlert, let message = vm.errorMessage {
                ToastOverlay(
                    icon: "exclamationmark.triangle.fill",
                    message: message,
                    style: .error,
                    onDismiss: {
                        vm.errorMessage = nil
                        vm.showErrorAlert = false
                    }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if vm.showSuccessAlert, let message = vm.successMessage {
                ToastOverlay(
                    icon: "checkmark.circle.fill",
                    message: message,
                    style: .success,
                    onDismiss: {
                        vm.successMessage = nil
                        vm.showSuccessAlert = false
                    }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.showErrorAlert)
        .animation(.easeInOut(duration: 0.3), value: vm.showSuccessAlert)
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
            // パイプライン実行中
            if vm.pipelineRunning {
                pipelineProgressView(vm: vm)
            } else {
                // 文字起こし
            if vm.isTranscribing {
                VStack(spacing: MemoraSpacing.lg) {
                    ProgressView(value: vm.transcriptionProgress)
                        .tint(MemoraColor.textSecondary)
                    Text("文字起こし中... \(Int(vm.transcriptionProgress * 100))%")
                        .font(.caption)
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
                VStack(spacing: MemoraSpacing.lg) {
                    ProgressView(value: vm.summarizationProgress)
                        .tint(MemoraColor.textSecondary)
                    Text("要約中... \(Int(vm.summarizationProgress * 100))%")
                        .font(.caption)
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
            } // else (not pipelineRunning)

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
    // MARK: - Pipeline Progress

    private let pipelineSteps: [(PipelineStep, String, String)] = [
        (.loadingAudio, "オーディオ読み込み", "waveform"),
        (.transcribing, "文字起こし", "text.alignleft"),
        (.mergingTranscripts, "文字起こし統合", "doc.text.magnifyingglass"),
        (.generatingSummary, "要約生成", "text.quote"),
        (.extractingMetadata, "メタデータ抽出", "tag"),
        (.extractingTodos, "ToDo抽出", "checklist"),
        (.finalizing, "完了処理", "checkmark.circle")
    ]

    @ViewBuilder
    private func pipelineProgressView(vm: FileDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.md) {
            Text("パイプライン処理中")
                .font(MemoraTypography.headline)
                .foregroundStyle(.primary)

            ForEach(pipelineSteps, id: \.0) { step, label, icon in
                HStack(spacing: MemoraSpacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(stepColor(for: step, vm: vm))
                        .frame(width: 20)

                    Text(label)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(step == vm.currentPipelineStep ? .primary : .secondary)

                    Spacer()

                    if vm.completedPipelineSteps.contains(step) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(MemoraColor.accentGreen)
                    } else if step == vm.currentPipelineStep && !vm.completedPipelineSteps.contains(step) {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.vertical, MemoraSpacing.xxxs)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(MemoraColor.divider.opacity(0.1))
        .cornerRadius(MemoraRadius.md)
    }

    private func stepColor(for step: PipelineStep, vm: FileDetailViewModel) -> Color {
        if vm.completedPipelineSteps.contains(step) {
            return MemoraColor.accentGreen
        } else if step == vm.currentPipelineStep {
            return MemoraColor.accentBlue
        }
        return .secondary.opacity(0.4)
    }

    // MARK: - Upload Image Row

    @ViewBuilder
    private func uploadImageRow(vm: FileDetailViewModel) -> some View {
        Button(action: { /* TODO: PhotosPicker */ }) {
            HStack {
                Image(systemName: "photo.badge.plus")
                Text("画像を追加")
            }
            .font(MemoraTypography.subheadline)
            .foregroundStyle(MemoraColor.accentBlue)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(MemoraColor.divider.opacity(0.05))
            .cornerRadius(MemoraRadius.sm)
        }
        .padding(.horizontal)
    }

    // MARK: - Attachments Row

    @ViewBuilder
    private func attachmentsRow(vm: FileDetailViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: MemoraSpacing.sm) {
                // TODO: attachments 実装後に有効化
                // ForEach(vm.attachments) { attachment in ... }
                RoundedRectangle(cornerRadius: MemoraRadius.sm)
                    .fill(MemoraColor.divider.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Generated Result Sections

    @ViewBuilder
    private func generatedResultSections(vm: FileDetailViewModel, result: SummaryResult) -> some View {
        VStack(spacing: MemoraSpacing.xxl) {
            // Summary
            sectionHeader("Summary", icon: "doc.text") {
                Text(result.summary)
                    .font(MemoraTypography.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(6)
            }

            // Decisions
            if let decisions = result.decisions, !decisions.isEmpty {
                sectionHeader("Decisions", icon: "checkmark.seal") {
                    ForEach(decisions.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                            Text("\(index + 1).")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.accentBlue)
                                .frame(width: 20, alignment: .trailing)
                            Text(decisions[index])
                                .font(MemoraTypography.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            // Action Items
            if !result.actionItems.isEmpty {
                sectionHeader("Action Items", icon: "checklist") {
                    ForEach(result.actionItems.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                            Image(systemName: "circle")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                            Text(result.actionItems[index])
                                .font(MemoraTypography.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            // Transcript Preview
            if let transcript = vm.transcriptResult {
                sectionHeader("Transcript", icon: "text.alignleft") {
                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                        Text(transcript.text)
                            .font(MemoraTypography.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        Button(action: { vm.showTranscriptView = true }) {
                            Text("全文を表示")
                                .font(MemoraTypography.subheadline)
                                .foregroundStyle(MemoraColor.accentBlue)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func sectionHeader<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label(title, systemImage: icon)
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            content()
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Ask AI Input Bar

    @ViewBuilder
    private func askAIInputBar(vm: FileDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: MemoraSpacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(MemoraColor.accentBlue)

                TextField("Ask AI...", text: $askAIQuery)
                    .textFieldStyle(.plain)
                    .font(MemoraTypography.subheadline)

                if !askAIQuery.isEmpty {
                    Button(action: { submitAskAI(vm: vm) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(MemoraColor.accentBlue)
                    }
                }
            }
            .padding(.horizontal, MemoraSpacing.lg)
            .padding(.vertical, MemoraSpacing.sm)
            .background(.bar)
        }
    }

    @State private var askAIQuery = ""

    private func submitAskAI(vm: FileDetailViewModel) {
        // TODO: Navigate to AskAI chat view with context
        askAIQuery = ""
    }

    // MARK: - Loading Skeleton

    @ViewBuilder
    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: MemoraSpacing.xxl) {
                Spacer()
                    .frame(height: MemoraSpacing.xxl)

                // 波形イメージ
                SkeletonView(height: 120, cornerRadius: MemoraRadius.md)
                    .frame(width: 120)
                    .padding(.horizontal)

                // タイトル
                SkeletonView(height: 24, cornerRadius: MemoraRadius.sm)
                    .padding(.horizontal, 60)

                // メタデータ
                HStack(spacing: MemoraSpacing.xxl) {
                    SkeletonView(height: 16, cornerRadius: MemoraRadius.sm)
                        .frame(width: 100)
                    SkeletonView(height: 16, cornerRadius: MemoraRadius.sm)
                        .frame(width: 80)
                }

                Divider()
                    .padding(.horizontal)

                // プレイヤー
                VStack(spacing: MemoraSpacing.lg) {
                    SkeletonView(height: 6, cornerRadius: 3)
                        .padding(.horizontal)
                    SkeletonView(height: 70, cornerRadius: 35)
                        .frame(width: 70)
                }
                .padding(.vertical, MemoraSpacing.xxl)

                Divider()
                    .padding(.horizontal)

                // アクションボタン
                VStack(spacing: MemoraSpacing.lg) {
                    SkeletonView(height: 44, cornerRadius: MemoraRadius.md)
                    SkeletonView(height: 44, cornerRadius: MemoraRadius.md)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
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
