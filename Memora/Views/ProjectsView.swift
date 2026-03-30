import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.repositoryFactory) private var repoFactory
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var showCreateProjectView = false
    @State private var selectedProject: Project?

    var body: some View {
        NavigationStack {
            if projects.isEmpty {
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
                .navigationTitle("Projects")
                .navigationBarTitleDisplayMode(.large)
            } else {
                // プロジェクト一覧
                VStack(spacing: 0) {
                    List {
                        ForEach(projects) { project in
                            ProjectRow(project: project)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedProject = project
                                }
                        }
                        .onDelete(perform: deleteProjects)
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
        }
        .navigationDestination(isPresented: $showCreateProjectView) {
            CreateProjectView()
        }
        .navigationDestination(item: $selectedProject) { project in
            ProjectDetailView(project: project)
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            if let repo = repoFactory?.projectRepo as? ProjectRepository {
                try? repo.delete(projects[index])
            }
        }
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
