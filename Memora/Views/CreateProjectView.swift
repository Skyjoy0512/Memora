import SwiftUI
import SwiftData
import Observation

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CreateProjectViewModel()
    @State private var title = ""
    let onProjectCreated: (() -> Void)?

    init(onProjectCreated: (() -> Void)? = nil) {
        self.onProjectCreated = onProjectCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("新しいプロジェクト")) {
                    TextField("プロジェクト名", text: $title)
                        .textFieldStyle(.plain)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.red)
                    }
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
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .task {
            viewModel.configure(projectRepository: ProjectRepository(modelContext: modelContext))
        }
    }

    private func createProject() {
        if viewModel.createProject(title: title) {
            onProjectCreated?()
            dismiss()
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}

@MainActor
@Observable
final class CreateProjectViewModel {
    @ObservationIgnored
    private var projectRepository: ProjectRepositoryProtocol?

    var errorMessage: String?

    func configure(projectRepository: ProjectRepositoryProtocol?) {
        guard self.projectRepository == nil else { return }
        self.projectRepository = projectRepository
    }

    func createProject(title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "プロジェクト名を入力してください"
            return false
        }

        guard let projectRepository else {
            errorMessage = "保存先が初期化されていません"
            return false
        }

        do {
            let project = Project(title: trimmedTitle)
            try projectRepository.save(project)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "保存エラー: \(error.localizedDescription)"
            return false
        }
    }
}
