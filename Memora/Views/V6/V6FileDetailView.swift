import SwiftUI
import SwiftData
import PhotosUI

enum V6FileDetailTab {
    case summary
    case transcript
    case memo
}

/// File Detail shell (`.dc.html` `modalFileDetail`). Reuses `FileDetailViewModel` and its
/// pipeline/export/photo logic entirely — this is a visual reskin, not a new data layer.
struct V6FileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let audioFile: AudioFile
    var autoStartTranscription = false

    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"
    @AppStorage("transcriptionMode") private var transcriptionMode: String = "ローカル"

    @State private var viewModel: FileDetailViewModel?
    @State private var selectedTab: V6FileDetailTab = .summary
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var previewPhotoID: UUID?
    @State private var showAskAI = false
    @State private var showExport = false
    @State private var showMore = false
    @State private var showDeleteConfirm = false
    @State private var showMoveProject = false
    @State private var moveProjectSelection: Project?
    @State private var isRenaming = false
    @State private var renameDraft = ""

    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    private var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    private var currentTranscriptionMode: TranscriptionMode {
        TranscriptionMode(rawValue: transcriptionMode) ?? .local
    }

    private var currentAPIKey: String {
        switch currentProvider {
        case .openai: return KeychainService.load(key: .apiKeyOpenAI)
        case .gemini: return KeychainService.load(key: .apiKeyGemini)
        case .deepseek: return KeychainService.load(key: .apiKeyDeepSeek)
        case .local: return ""
        }
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(V6Color.white)
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let vm = FileDetailViewModel(
                audioFile: audioFile,
                modelContext: modelContext,
                provider: currentProvider,
                transcriptionMode: currentTranscriptionMode,
                apiKey: currentAPIKey
            )
            vm.setupAudioPlayer()
            vm.loadSavedData()
            viewModel = vm
            if autoStartTranscription && !audioFile.isTranscribed {
                vm.startTranscription()
            }
        }
        .onDisappear {
            viewModel?.cleanup()
        }
    }

    @ViewBuilder
    private func content(vm: FileDetailViewModel) -> some View {
        VStack(spacing: 0) {
            header(vm: vm)
            tabBar

            ScrollView(showsIndicators: false) {
                switch selectedTab {
                case .summary:
                    SummaryTab(vm: vm, audioFile: audioFile, onSeekToTranscript: { time in
                        vm.seekToTime(time)
                        selectedTab = .transcript
                    }, onPreviewAttachment: { previewPhotoID = $0 })
                case .transcript:
                    TranscriptTab(vm: vm, audioFile: audioFile)
                case .memo:
                    MemoTab(vm: vm, selectedPhotoItems: $selectedPhotoItems, onPreviewAttachment: { previewPhotoID = $0 })
                }
            }
            .padding(.horizontal, 18)

            askBar
        }
        .background(V6Color.white.ignoresSafeArea())
        .sheet(isPresented: $showAskAI) {
            AskAIView(scope: .file(fileId: audioFile.id))
        }
        .sheet(isPresented: $showExport) {
            ExportOptionsSheet(audioFile: audioFile)
        }
        .sheet(isPresented: $showMoveProject) {
            ProjectPickerSheet(projects: projects, selectedProject: $moveProjectSelection)
                .onDisappear {
                    audioFile.projectID = moveProjectSelection?.id
                    try? modelContext.save()
                }
        }
        .sheet(
            isPresented: Binding(
                get: { previewPhotoID != nil },
                set: { if !$0 { previewPhotoID = nil } }
            )
        ) {
            if let attachment = vm.photoAttachments.first(where: { $0.id == previewPhotoID }) {
                PhotoAttachmentPreviewSheet(
                    attachment: attachment,
                    image: FileDetailHelpers.fullSizeImage(for: attachment),
                    canMoveLeading: vm.canMovePhotoAttachment(attachment, towardLeading: true),
                    canMoveTrailing: vm.canMovePhotoAttachment(attachment, towardLeading: false),
                    onSaveCaption: { caption in vm.updatePhotoCaption(attachment, caption: caption) },
                    onMoveLeading: { vm.movePhotoAttachment(attachment, towardLeading: true) },
                    onMoveTrailing: { vm.movePhotoAttachment(attachment, towardLeading: false) },
                    onDelete: {
                        vm.deletePhotoAttachment(attachment)
                        previewPhotoID = nil
                    }
                )
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await vm.importPhoto(from: data)
                    }
                }
                await MainActor.run { selectedPhotoItems = [] }
            }
        }
        .sheet(isPresented: $showMore) {
            V6FileMoreSheet(
                onRename: {
                    renameDraft = audioFile.title
                    showMore = false
                    isRenaming = true
                },
                onMove: {
                    moveProjectSelection = projects.first(where: { $0.id == audioFile.projectID })
                    showMore = false
                    showMoveProject = true
                },
                onDelete: {
                    showMore = false
                    showDeleteConfirm = true
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .alert("タイトルを変更", isPresented: $isRenaming) {
            TextField("ファイル名", text: $renameDraft)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                audioFile.title = trimmed
                try? modelContext.save()
            }
        }
        .overlay {
            if showDeleteConfirm {
                V6FileDetailDeleteConfirm(
                    onCancel: { showDeleteConfirm = false },
                    onConfirm: {
                        vm.deleteAudioFile()
                        showDeleteConfirm = false
                        dismiss()
                    }
                )
            }
        }
    }

    private func header(vm: FileDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(V6Color.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Button { showExport = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(V6Color.ink)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)

                    Button { showMore = true } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(V6Color.ink)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(audioFile.title)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.24)
                    .foregroundStyle(V6Color.ink)
                    .lineLimit(1)
                Text("\(vm.formatDate(audioFile.createdAt)) ・ \(vm.formatDuration(audioFile.duration))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(V6Color.muted)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 24) {
            tabItem("要約", tab: .summary)
            tabItem("文字起こし", tab: .transcript)
            tabItem("メモ", tab: .memo)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V6Color.soft).frame(height: 1)
        }
    }

    private func tabItem(_ title: String, tab: V6FileDetailTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selectedTab == tab ? V6Color.ink : V6Color.quiet)
                .padding(.bottom, 9)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(selectedTab == tab ? V6Color.ink : .clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private var askBar: some View {
        Button {
            showAskAI = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V6Color.ink)
                Text("このファイルについて質問する")
                    .font(.system(size: 13.5))
                    .foregroundStyle(V6Color.muted)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(V6Color.white, in: RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous)
                    .stroke(Color(hex: "ECECEC"), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }
}

private struct V6FileDetailDeleteConfirm: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("このファイルを削除しますか？")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(V6Color.ink)
                    Text("録音・文字起こし・メモはすべて削除されます。")
                        .font(.system(size: 12.5))
                        .lineSpacing(4)
                        .foregroundStyle(V6Color.muted)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 8) {
                    Button("キャンセル", action: onCancel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(V6Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(V6Color.fillStrong, in: RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous))
                    Button("削除", action: onConfirm)
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
}
