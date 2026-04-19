import Testing
import Foundation
import SwiftData
@testable import Memora

@MainActor
struct ProjectsViewModelTests {

    @Test("loadProjects が updatedAt 降順で結果を保持する")
    func loadProjects() {
        let older = makeProject(title: "A", createdDaysFromNow: -10, updatedDaysFromNow: -5)
        let newer = makeProject(title: "B", createdDaysFromNow: -20, updatedDaysFromNow: -1)
        let repository = MockProjectRepository(projects: [older, newer])
        let viewModel = ProjectsViewModel()

        viewModel.configure(projectRepository: repository)
        viewModel.loadProjects()

        #expect(viewModel.projects.map(\.id) == [newer.id, older.id])
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test("deleteProjects が repository とローカル状態を更新する")
    func deleteProjects() {
        let first = makeProject(title: "最初", createdDaysFromNow: -1, updatedDaysFromNow: -1)
        let second = makeProject(title: "次", createdDaysFromNow: 0, updatedDaysFromNow: 0)
        let repository = MockProjectRepository(projects: [first, second])
        let viewModel = ProjectsViewModel()

        viewModel.configure(projectRepository: repository)
        viewModel.loadProjects()
        viewModel.deleteProjects(at: IndexSet(integer: 1), from: [first, second])

        #expect(repository.deletedIDs == [second.id])
        #expect(viewModel.projects.map(\.id) == [first.id])
    }

    @Test("loadProjects が repository エラーを保持する")
    func loadProjectsFailure() {
        let repository = MockProjectRepository(projects: [], fetchError: NSError(domain: "ProjectFetch", code: 1))
        let viewModel = ProjectsViewModel()

        viewModel.configure(projectRepository: repository)
        viewModel.loadProjects()

        #expect(viewModel.projects.isEmpty)
        #expect(viewModel.lastErrorMessage?.contains("ProjectFetch") == true)
    }

    @Test("deleteProjects が repository エラーを保持する")
    func deleteProjectsFailure() {
        let first = makeProject(title: "最初", createdDaysFromNow: -1, updatedDaysFromNow: -1)
        let second = makeProject(title: "次", createdDaysFromNow: 0, updatedDaysFromNow: 0)
        let repository = MockProjectRepository(
            projects: [first, second],
            deleteError: NSError(domain: "ProjectDelete", code: 1)
        )
        let viewModel = ProjectsViewModel()

        viewModel.configure(projectRepository: repository)
        viewModel.loadProjects()
        viewModel.deleteProjects(at: IndexSet(integer: 0), from: [second, first])

        #expect(viewModel.projects.map(\.id) == [second.id, first.id])
        #expect(viewModel.lastErrorMessage?.contains("ProjectDelete") == true)
    }

    private func makeProject(title: String, createdDaysFromNow: Int, updatedDaysFromNow: Int) -> Project {
        let project = Project(title: title)
        project.createdAt = Calendar.current.date(byAdding: .day, value: createdDaysFromNow, to: Date()) ?? Date()
        project.updatedAt = Calendar.current.date(byAdding: .day, value: updatedDaysFromNow, to: Date()) ?? Date()
        return project
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    var projects: [Project]
    var deletedIDs: [UUID] = []
    let saveError: Error?
    let fetchError: Error?
    let deleteError: Error?

    init(
        projects: [Project],
        saveError: Error? = nil,
        fetchError: Error? = nil,
        deleteError: Error? = nil
    ) {
        self.projects = projects
        self.saveError = saveError
        self.fetchError = fetchError
        self.deleteError = deleteError
    }

    func fetchAll() throws -> [Project] {
        if let fetchError {
            throw fetchError
        }
        return projects
    }

    func fetch(id: UUID) throws -> Project? {
        projects.first(where: { $0.id == id })
    }

    func save(_ project: Project) throws {
        if let saveError {
            throw saveError
        }
        projects.append(project)
    }

    func delete(_ project: Project) throws {
        if let deleteError {
            throw deleteError
        }
        deletedIDs.append(project.id)
        projects.removeAll(where: { $0.id == project.id })
    }

    func fileCount(for projectId: UUID) throws -> Int {
        0
    }
}

@MainActor
struct ProjectDetailViewModelTests {

    /// in-memory ModelContext をテスト用に作成する。
    /// 注: ホストアプリと同じスキーマを含むと EXC_BREAKPOINT が起きる可能性があるため、
    /// AudioFile のみを登録した最小スキーマを使用する。
    private func makeTestContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AudioFile.self, configurations: config)
        return ModelContext(container)
    }

    @Test("loadProjectFiles が指定プロジェクトのファイルを保持する")
    func loadProjectFiles() {
        let targetProjectID = UUID()
        let first = makeAudioFile(title: "議事録A", projectID: targetProjectID, daysFromNow: -1)
        let second = makeAudioFile(title: "議事録B", projectID: targetProjectID, daysFromNow: 0)
        let other = makeAudioFile(title: "別プロジェクト", projectID: UUID(), daysFromNow: -2)
        let repository = MockProjectDetailAudioFileRepository(files: [first, second, other])
        let viewModel = ProjectDetailViewModel()

        viewModel.configure(modelContext: makeTestContext(), audioFileRepository: repository)
        viewModel.loadProjectFiles(projectID: targetProjectID)

        #expect(viewModel.projectFiles.map(\.id) == [second.id, first.id])
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test("loadProjectFiles が repository エラーを保持する")
    func loadProjectFilesFailure() {
        let repository = MockProjectDetailAudioFileRepository(files: [], fetchError: NSError(domain: "Test", code: 1))
        let viewModel = ProjectDetailViewModel()

        viewModel.configure(modelContext: makeTestContext(), audioFileRepository: repository)
        viewModel.loadProjectFiles(projectID: UUID())

        #expect(viewModel.projectFiles.isEmpty)
        #expect(viewModel.lastErrorMessage?.contains("Test") == true)
    }

    @Test("deleteAudioFiles が repository とローカル状態を更新する")
    func deleteProjectFiles() {
        let projectID = UUID()
        let first = makeAudioFile(title: "議事録A", projectID: projectID, daysFromNow: -1)
        let second = makeAudioFile(title: "議事録B", projectID: projectID, daysFromNow: 0)
        let repository = MockProjectDetailAudioFileRepository(files: [first, second])
        let viewModel = ProjectDetailViewModel()

        viewModel.configure(modelContext: makeTestContext(), audioFileRepository: repository)
        viewModel.loadProjectFiles(projectID: projectID)
        viewModel.deleteAudioFiles(at: IndexSet(integer: 0), from: [second, first])

        #expect(repository.deletedIDs == [second.id])
        #expect(viewModel.projectFiles.map(\.id) == [first.id])
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test("deleteAudioFiles が repository エラーを保持する")
    func deleteProjectFilesFailure() {
        let projectID = UUID()
        let first = makeAudioFile(title: "議事録A", projectID: projectID, daysFromNow: -1)
        let second = makeAudioFile(title: "議事録B", projectID: projectID, daysFromNow: 0)
        let repository = MockProjectDetailAudioFileRepository(
            files: [first, second],
            deleteError: NSError(domain: "AudioDelete", code: 1)
        )
        let viewModel = ProjectDetailViewModel()

        viewModel.configure(modelContext: makeTestContext(), audioFileRepository: repository)
        viewModel.loadProjectFiles(projectID: projectID)
        viewModel.deleteAudioFiles(at: IndexSet(integer: 0), from: [second, first])

        #expect(viewModel.projectFiles.map(\.id) == [second.id, first.id])
        #expect(viewModel.lastErrorMessage?.contains("AudioDelete") == true)
    }

    private func makeAudioFile(title: String, projectID: UUID?, daysFromNow: Int) -> AudioFile {
        let file = AudioFile(title: title, audioURL: "/tmp/\(title).m4a", projectID: projectID)
        file.createdAt = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        return file
    }
}

private final class MockProjectDetailAudioFileRepository: AudioFileRepositoryProtocol {
    var files: [AudioFile]
    let fetchError: Error?
    let deleteError: Error?
    var deletedIDs: [UUID] = []

    init(files: [AudioFile], fetchError: Error? = nil, deleteError: Error? = nil) {
        self.files = files
        self.fetchError = fetchError
        self.deleteError = deleteError
    }

    func fetchAll() throws -> [AudioFile] {
        files
    }

    func fetch(id: UUID) throws -> AudioFile? {
        files.first(where: { $0.id == id })
    }

    func save(_ file: AudioFile) throws {
        files.append(file)
    }

    func delete(_ file: AudioFile) throws {
        if let deleteError {
            throw deleteError
        }
        deletedIDs.append(file.id)
        files.removeAll(where: { $0.id == file.id })
    }

    func delete(id: UUID) throws {
        files.removeAll(where: { $0.id == id })
    }

    func fetchByProject(_ projectId: UUID) throws -> [AudioFile] {
        if let fetchError {
            throw fetchError
        }

        return files
            .filter { $0.projectID == projectId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchTranscribed() throws -> [AudioFile] {
        files.filter(\.isTranscribed)
    }

    func search(query: String) throws -> [AudioFile] {
        files.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
