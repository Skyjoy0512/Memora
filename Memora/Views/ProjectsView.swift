import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var showCreateProjectView = false
    @State private var selectedProject: Project?

    var body: some View {
        NavigationStack {
            if projects.isEmpty {
                // 空の状態
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "folder")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.gray)

                    Text("プロジェクト")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("プロジェクトを作成して録音を整理しましょう")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    Button(action: { showCreateProjectView = true }) {
                        Label("プロジェクトを作成", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(12)
                    }
                    .padding()

                    Text("まだプロジェクトがありません")
                        .foregroundStyle(.secondary)
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
            modelContext.delete(projects[index])
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
                .foregroundStyle(.gray)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("更新: \(formatDate(project.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
