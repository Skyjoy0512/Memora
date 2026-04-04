import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProjectsViewModel()
    @State private var showCreateProjectView = false
    @State private var selectedProject: Project?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let errorMessage = viewModel.lastErrorMessage {
                    InlineErrorMessage(message: errorMessage)
                        .padding(.horizontal)
                        .padding(.top, MemoraSpacing.sm)
                }

                if viewModel.projects.isEmpty {
                    // 空の状態
                    VStack(spacing: MemoraSpacing.xxl) {
                        Spacer()

                        Image(systemName: "folder")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(MemoraColor.textSecondary)

                        Text("プロジェクト")
                            .font(MemoraTypography.largeTitle)

                        Text("プロジェクトを作成して録音を整理しましょう")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(MemoraColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Spacer()

                        Button(action: { showCreateProjectView = true }) {
                            Label("プロジェクトを作成", systemImage: "plus.circle.fill")
                                .font(MemoraTypography.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(MemoraColor.divider)
                                .cornerRadius(MemoraRadius.md)
                        }
                        .padding()

                        Text("まだプロジェクトがありません")
                            .foregroundStyle(MemoraColor.textSecondary)
                            .padding(.bottom, 40)
                    }
                } else {
                    // プロジェクト一覧
                    VStack(spacing: 0) {
                        List {
                            ForEach(viewModel.projects) { project in
                                ProjectRow(project: project)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedProject = project
                                    }
                            }
                            .onDelete(perform: deleteProjects)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateProjectView = true }) {
                        Image(systemName: "plus")
                    }
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
        }
        .onAppear {
            viewModel.configure(projectRepository: ProjectRepository(modelContext: modelContext))
            viewModel.loadProjects()
        }
        .onChange(of: selectedProject?.id) { _, projectID in
            if projectID == nil {
                viewModel.loadProjects()
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        viewModel.deleteProjects(at: offsets, from: viewModel.projects)
    }
}

struct InlineErrorMessage: View {
    let message: String

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MemoraColor.accentRed)

            Text(message)
                .font(MemoraTypography.caption1)
                .foregroundStyle(MemoraColor.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MemoraSpacing.lg)
        .padding(.vertical, MemoraSpacing.sm)
        .background(MemoraColor.accentRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.sm))
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // フォルダアイコン
            Image(systemName: "folder")
                .font(.title2)
                .foregroundStyle(MemoraColor.textSecondary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(MemoraTypography.headline)
                    .foregroundStyle(.primary)

                Text("更新: \(formatDate(project.updatedAt))")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, MemoraSpacing.xxxs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: Project.self, inMemory: true)
}
