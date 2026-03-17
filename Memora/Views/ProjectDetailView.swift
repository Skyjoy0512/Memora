import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var showEditProjectView = false
    @State private var showRecordingView = false

    // 全ファイルを取得
    @Query private var allAudioFiles: [AudioFile]

    // プロジェクトに関連するファイル
    var projectFiles: [AudioFile] {
        allAudioFiles.filter { $0.projectID == project.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if projectFiles.isEmpty {
                    // 空の状態
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "folder")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.gray)

                        Text(project.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text("まだファイルがありません")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: { showRecordingView = true }) {
                            Label("録音を開始", systemImage: "mic.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray)
                                .cornerRadius(12)
                        }
                        .padding()

                        Text("録音を開始してファイルを追加しましょう")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 40)
                    }
                } else {
                    // ファイル一覧
                    List {
                        ForEach(projectFiles) { file in
                            AudioFileRow(audioFile: file)
                        }
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
            RecordingView()
        }
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

