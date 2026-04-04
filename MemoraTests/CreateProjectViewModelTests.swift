import Testing
import Foundation
@testable import Memora

@MainActor
struct CreateProjectViewModelTests {

    @Test("正常なタイトルでプロジェクトを作成できる")
    func createProjectWithValidTitle() {
        let repository = MockCreateProjectRepository()
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: repository)

        let result = viewModel.createProject(title: "新規プロジェクト")

        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
        #expect(repository.savedProjects.count == 1)
        #expect(repository.savedProjects.first?.title == "新規プロジェクト")
    }

    @Test("前後の空白をトリムしてプロジェクトを作成する")
    func createProjectTrimsWhitespace() {
        let repository = MockCreateProjectRepository()
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: repository)

        let result = viewModel.createProject(title: "  プロジェクトA  ")

        #expect(result == true)
        #expect(repository.savedProjects.first?.title == "プロジェクトA")
    }

    @Test("空文字のタイトルはエラーメッセージを返す")
    func createProjectWithEmptyTitle() {
        let repository = MockCreateProjectRepository()
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: repository)

        let result = viewModel.createProject(title: "")

        #expect(result == false)
        #expect(viewModel.errorMessage == "プロジェクト名を入力してください")
        #expect(repository.savedProjects.isEmpty)
    }

    @Test("空白のみのタイトルはエラーメッセージを返す")
    func createProjectWithWhitespaceOnlyTitle() {
        let repository = MockCreateProjectRepository()
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: repository)

        let result = viewModel.createProject(title: "   ")

        #expect(result == false)
        #expect(viewModel.errorMessage == "プロジェクト名を入力してください")
        #expect(repository.savedProjects.isEmpty)
    }

    @Test("repository 未設定時はエラーメッセージを返す")
    func createProjectWithoutRepository() {
        let viewModel = CreateProjectViewModel()

        let result = viewModel.createProject(title: "テスト")

        #expect(result == false)
        #expect(viewModel.errorMessage == "保存先が初期化されていません")
    }

    @Test("repository の save がエラーの場合はエラーメッセージを返す")
    func createProjectWithSaveError() {
        let repository = MockCreateProjectRepository(shouldFail: true)
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: repository)

        let result = viewModel.createProject(title: "失敗テスト")

        #expect(result == false)
        #expect(viewModel.errorMessage?.contains("保存エラー") == true)
    }

    @Test("configure は複数回呼ばれても最初の repository を維持する")
    func configureIsIdempotent() {
        let first = MockCreateProjectRepository()
        let second = MockCreateProjectRepository()
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: first)
        viewModel.configure(projectRepository: second)

        _ = viewModel.createProject(title: "テスト")

        #expect(first.savedProjects.count == 1)
        #expect(second.savedProjects.isEmpty)
    }

    @Test("成功後に errorMessage がクリアされる")
    func errorMessageClearedOnSuccess() {
        let repository = MockCreateProjectRepository()
        let viewModel = CreateProjectViewModel()

        viewModel.configure(projectRepository: repository)

        _ = viewModel.createProject(title: "")
        #expect(viewModel.errorMessage != nil)

        _ = viewModel.createProject(title: "有効タイトル")
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - Mock

private final class MockCreateProjectRepository: ProjectRepositoryProtocol {
    var savedProjects: [Project] = []
    let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func fetchAll() throws -> [Project] {
        savedProjects
    }

    func fetch(id: UUID) throws -> Project? {
        savedProjects.first(where: { $0.id == id })
    }

    func save(_ project: Project) throws {
        if shouldFail {
            throw NSError(domain: "TestError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "テスト用エラー"
            ])
        }
        savedProjects.append(project)
    }

    func delete(_ project: Project) throws {
        savedProjects.removeAll(where: { $0.id == project.id })
    }

    func fileCount(for projectId: UUID) throws -> Int {
        0
    }
}
