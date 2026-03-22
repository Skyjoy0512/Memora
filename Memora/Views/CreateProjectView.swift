import SwiftUI
import SwiftData

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""

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
        let project = Project(title: title)
        modelContext.insert(project)
        dismiss()
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
