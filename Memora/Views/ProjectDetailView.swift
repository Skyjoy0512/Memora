import SwiftUI
import SwiftData
import Observation

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var viewModel = ProjectDetailViewModel()
    @State private var showEditProjectView = false
    @State private var showRecordingView = false
    @State private var selectedAudioFile: AudioFile?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let errorMessage = viewModel.lastErrorMessage {
                    InlineErrorMessage(message: errorMessage)
                        .padding(.horizontal)
                        .padding(.top, MemoraSpacing.sm)
                }

                if viewModel.projectFiles.isEmpty {
                    // 空の状態
                    VStack(spacing: MemoraSpacing.lg) {
                        Spacer()

                        Image(systemName: "folder")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(MemoraColor.textSecondary)

                        Text(project.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text("まだファイルがありません")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: { showRecordingView = true }) {
                            Label("録音を開始", systemImage: "mic.circle.fill")
                                .font(MemoraTypography.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(MemoraColor.divider)
                                .cornerRadius(MemoraRadius.sm)
                        }
                        .padding()

                        Text("録音を開始してファイルを追加しましょう")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, MemoraSpacing.xxxl)
                    }
                } else {
                    // ファイル一覧
                    List {
                        ForEach(viewModel.projectFiles) { file in
                            AudioFileRow(audioFile: file)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAudioFile = file
                                }
                        }
                        .onDelete(perform: deleteAudioFiles)
                    }
                }
            }
            .navigationTitle("詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showRecordingView = true }) {
                        Image(systemName: "mic")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showEditProjectView) {
            EditProjectView(project: project)
        }
        .navigationDestination(isPresented: $showRecordingView) {
            RecordingView(initialProject: project)
        }
        .navigationDestination(item: $selectedAudioFile) { file in
            FileDetailView(audioFile: file)
        }
        .onAppear {
            viewModel.configure(audioFileRepository: AudioFileRepository(modelContext: modelContext))
            viewModel.loadProjectFiles(projectID: project.id)
        }
        .onChange(of: showRecordingView) { _, isPresented in
            if !isPresented {
                viewModel.loadProjectFiles(projectID: project.id)
            }
        }
    }

    private func deleteAudioFiles(at offsets: IndexSet) {
        viewModel.deleteAudioFiles(at: offsets, from: viewModel.projectFiles)
    }
}

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("プロジェクト名を編集")) {
                    TextField("プロジェクト名", text: $title)
                        .textFieldStyle(.plain)
                }
            }
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveProject()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            title = project.title
        }
    }

    private func saveProject() {
        project.title = title
        project.updatedAt = Date()
        dismiss()
    }
}

@MainActor
@Observable
final class ProjectDetailViewModel {
    @ObservationIgnored
    private var audioFileRepository: AudioFileRepositoryProtocol?

    var projectFiles: [AudioFile] = []
    var lastErrorMessage: String?

    func configure(audioFileRepository: AudioFileRepositoryProtocol?) {
        guard self.audioFileRepository == nil else { return }
        self.audioFileRepository = audioFileRepository
    }

    func loadProjectFiles(projectID: UUID) {
        guard let audioFileRepository else { return }

        do {
            projectFiles = try audioFileRepository.fetchByProject(projectID)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteAudioFiles(at offsets: IndexSet, from visibleFiles: [AudioFile]) {
        for index in offsets {
            let file = visibleFiles[index]
            delete(file)
        }
    }

    private func delete(_ file: AudioFile) {
        guard let audioFileRepository else { return }

        do {
            try audioFileRepository.delete(file)
            projectFiles.removeAll(where: { $0.id == file.id })
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
