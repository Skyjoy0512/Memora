import Foundation
import Observation

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

    @discardableResult
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
            try projectRepository.save(Project(title: trimmedTitle))
            errorMessage = nil
            return true
        } catch {
            errorMessage = "保存エラー: \(error.localizedDescription)"
            return false
        }
    }
}
