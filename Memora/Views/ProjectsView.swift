import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProjectsViewModel()
    @State private var showCreateProjectView = false
    @State private var selectedProject: Project?
    @Query private var audioFiles: [AudioFile]
    @Binding var isTabBarHidden: Bool
    @State private var isInitialLoading = true

    init(isTabBarHidden: Binding<Bool> = .constant(false)) {
        self._isTabBarHidden = isTabBarHidden
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.lastErrorMessage {
                    InlineErrorMessage(message: errorMessage)
                }

                if isInitialLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.projects.isEmpty {
                    ContentUnavailableView(
                        "プロジェクトはまだありません",
                        systemImage: "folder",
                        description: Text("プロジェクトを作成して録音を整理しましょう。"),
                        actions: {
                            Button("プロジェクトを作成") {
                                showCreateProjectView = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    )
                } else {
                    Section {
                        ForEach(viewModel.projects) { project in
                            Button {
                                selectedProject = project
                            } label: {
                                ProjectRow(project: project, fileCount: fileCount(for: project))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("プロジェクトを開く")
                            .swipeActions {
                                Button(role: .destructive) {
                                    if let index = viewModel.projects.firstIndex(of: project) {
                                        deleteProjects(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("プロジェクト")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateProjectView = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("プロジェクトを作成")
                }
            }
        }
        .navigationDestination(isPresented: $showCreateProjectView) {
            CreateProjectView {
                viewModel.loadProjects()
            }
        }
        .navigationDestination(item: $selectedProject) { project in
            ProjectDetailView(project: project)
                .toolbar(.hidden, for: .tabBar)
                .onAppear { isTabBarHidden = true }
                .onDisappear { isTabBarHidden = false }
        }
        .task {
            viewModel.configure(projectRepository: ProjectRepository(modelContext: modelContext))
            viewModel.loadProjects()
            isInitialLoading = false
        }
        .onChange(of: selectedProject?.id) { _, projectID in
            if projectID == nil {
                viewModel.loadProjects()
            }
        }
    }

    private func fileCount(for project: Project) -> Int {
        audioFiles.filter { $0.projectID == project.id }.count
    }

    private func deleteProjects(at offsets: IndexSet) {
        viewModel.deleteProjects(at: offsets, from: viewModel.projects)
    }
}

// MARK: - Inline Error Message

struct InlineErrorMessage: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProjectRow: View {
    let project: Project
    var fileCount: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(formatDate(project.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(fileCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private static let projectDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.projectDateFormatter.string(from: date)
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: Project.self, inMemory: true)
}
