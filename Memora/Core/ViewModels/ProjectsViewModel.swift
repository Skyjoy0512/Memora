import Foundation
import Observation

@MainActor
@Observable
final class ProjectsViewModel {
    @ObservationIgnored
    private var projectRepository: ProjectRepositoryProtocol?

    var projects: [Project] = []
    var lastErrorMessage: String?

    func configure(projectRepository: ProjectRepositoryProtocol?) {
        guard self.projectRepository == nil else { return }
        self.projectRepository = projectRepository
    }

    func loadProjects() {
        guard let projectRepository else { return }

        do {
            projects = try projectRepository.fetchAll().sorted { $0.updatedAt > $1.updatedAt }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteProjects(at offsets: IndexSet, from visibleProjects: [Project]) {
        for index in offsets {
            let project = visibleProjects[index]
            delete(project)
        }
    }

    private func delete(_ project: Project) {
        guard let projectRepository else { return }

        do {
            try projectRepository.delete(project)
            projects.removeAll(where: { $0.id == project.id })
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
