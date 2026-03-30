import SwiftUI
import SwiftData

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.repositoryFactory) private var repoFactory
    @State private var title = ""

    private var projectRepo: ProjectRepositoryProtocol? {
        repoFactory?.projectRepo
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("新しいプロジェクト")) {
                    TextField("プロジェクト名", text: $title)
                        .textFieldStyle(.plain)
                }
            }
            .navigationTitle("プロジェクト作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        createProject()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createProject() {
        guard let repo = repoFactory?.projectRepo as? ProjectRepository else { return }
        let project = Project(title: title)
        try? repo.save(project)
        dismiss()
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
