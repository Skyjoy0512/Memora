import Testing
import Foundation
@testable import Memora

@MainActor
struct HomeViewModelTests {

    @Test("loadAudioFiles が repository の結果を保持する")
    func loadAudioFiles() {
        let first = makeAudioFile(title: "B会議", daysFromNow: 0)
        let second = makeAudioFile(title: "A会議", daysFromNow: -1)
        let repository = MockAudioFileRepository(files: [first, second])
        let viewModel = HomeViewModel()

        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        #expect(viewModel.audioFiles.map(\.id) == [first.id, second.id])
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test("loadAudioFiles は初回ページのみを読み込む")
    func loadAudioFilesUsesFirstPage() {
        let files = (0..<55).map { makeAudioFile(title: "file-\($0)", daysFromNow: -$0) }
        let repository = MockAudioFileRepository(files: files)
        let viewModel = HomeViewModel()

        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        #expect(viewModel.audioFiles.count == HomeViewModel.pageSize)
        #expect(viewModel.hasMoreAudioFiles)
    }

    @Test("loadMoreAudioFilesIfNeeded は次ページを追加する")
    func loadMoreAudioFilesAppendsNextPage() {
        let files = (0..<55).map { makeAudioFile(title: "file-\($0)", daysFromNow: -$0) }
        let repository = MockAudioFileRepository(files: files)
        let viewModel = HomeViewModel()

        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()
        viewModel.loadMoreAudioFilesIfNeeded()

        #expect(viewModel.audioFiles.count == 55)
        #expect(!viewModel.hasMoreAudioFiles)
    }

    @Test("filteredFiles が検索と状態フィルタを適用する")
    func filteredFilesAppliesFilters() {
        let meeting = makeAudioFile(title: "会議メモ", daysFromNow: -2)
        meeting.isTranscribed = true
        meeting.isSummarized = true
        meeting.isLifeLog = true
        meeting.lifeLogTags = ["仕事", "会議"]

        let interview = makeAudioFile(title: "インタビュー", daysFromNow: -1)
        interview.isTranscribed = true

        let privateNote = makeAudioFile(title: "個人メモ", daysFromNow: 0)
        privateNote.isLifeLog = true
        privateNote.lifeLogTags = ["個人"]

        let repository = MockAudioFileRepository(files: [meeting, interview, privateNote])
        let viewModel = HomeViewModel()
        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        let filtered = viewModel.filteredFiles(
            searchText: "会議",
            filterTranscribed: true,
            filterSummarized: true,
            filterLifeLog: true,
            selectedTag: "仕事",
            sortOption: .dateDesc
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == meeting.id)
    }

    @Test("filteredFiles はファイル属性変更後にキャッシュを更新する")
    func filteredFilesRefreshesCacheAfterFileMutation() {
        let file = makeAudioFile(title: "LifeLog", daysFromNow: 0)
        let repository = MockAudioFileRepository(files: [file])
        let viewModel = HomeViewModel()
        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        let initial = viewModel.filteredFiles(
            searchText: "",
            filterTranscribed: nil,
            filterSummarized: nil,
            filterLifeLog: true,
            selectedTag: "仕事",
            sortOption: .dateDesc
        )
        #expect(initial.isEmpty)

        file.isLifeLog = true
        file.lifeLogTags = ["仕事"]

        let updated = viewModel.filteredFiles(
            searchText: "",
            filterTranscribed: nil,
            filterSummarized: nil,
            filterLifeLog: true,
            selectedTag: "仕事",
            sortOption: .dateDesc
        )

        #expect(updated.map(\.id) == [file.id])
    }

    @Test("filteredFiles がタイトル降順で並べ替える")
    func filteredFilesSortsByTitleDescending() {
        let alpha = makeAudioFile(title: "Alpha", daysFromNow: -1)
        let charlie = makeAudioFile(title: "Charlie", daysFromNow: -2)
        let bravo = makeAudioFile(title: "Bravo", daysFromNow: 0)

        let repository = MockAudioFileRepository(files: [alpha, charlie, bravo])
        let viewModel = HomeViewModel()
        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        let sorted = viewModel.filteredFiles(
            searchText: "",
            filterTranscribed: nil,
            filterSummarized: nil,
            filterLifeLog: nil,
            selectedTag: nil,
            sortOption: .titleDesc
        )

        #expect(sorted.map(\.title) == ["Charlie", "Bravo", "Alpha"])
    }

    @Test("deleteAudioFiles が repository とローカル状態を更新する")
    func deleteAudioFiles() {
        let first = makeAudioFile(title: "最初", daysFromNow: -1)
        let second = makeAudioFile(title: "次", daysFromNow: 0)
        let repository = MockAudioFileRepository(files: [first, second])
        let viewModel = HomeViewModel()
        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        viewModel.deleteAudioFiles(at: IndexSet(integer: 0), from: [second, first])

        #expect(repository.deletedIDs == [second.id])
        #expect(viewModel.audioFiles.map(\.id) == [first.id])
    }

    @Test("audioFile(id:) が一致するファイルを返す")
    func audioFileLookup() {
        let target = makeAudioFile(title: "対象", daysFromNow: 0)
        let repository = MockAudioFileRepository(files: [target])
        let viewModel = HomeViewModel()
        viewModel.configure(audioFileRepository: repository)
        viewModel.loadAudioFiles()

        #expect(viewModel.audioFile(id: target.id)?.title == "対象")
        #expect(viewModel.audioFile(id: UUID()) == nil)
        #expect(viewModel.audioFile(id: nil) == nil)
    }

    private func makeAudioFile(title: String, daysFromNow: Int) -> AudioFile {
        let file = AudioFile(title: title, audioURL: "/tmp/\(title).m4a")
        file.createdAt = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        return file
    }
}

private final class MockAudioFileRepository: AudioFileRepositoryProtocol {
    var files: [AudioFile]
    var deletedIDs: [UUID] = []

    init(files: [AudioFile]) {
        self.files = files
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
        deletedIDs.append(file.id)
        files.removeAll(where: { $0.id == file.id })
    }

    func delete(id: UUID) throws {
        deletedIDs.append(id)
        files.removeAll(where: { $0.id == id })
    }

    func fetchByProject(_ projectId: UUID) throws -> [AudioFile] {
        files.filter { $0.projectID == projectId }
    }

    func fetchTranscribed() throws -> [AudioFile] {
        files.filter(\.isTranscribed)
    }

    func search(query: String) throws -> [AudioFile] {
        files.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

@MainActor
struct RecordingViewModelTests {

    @Test("saveRecording が repository に録音ファイルを保存する")
    func saveRecording() {
        let repository = MockRecordingAudioFileRepository()
        let viewModel = RecordingViewModel()
        let url = URL(fileURLWithPath: "/tmp/recording.m4a")

        viewModel.configure(audioFileRepository: repository)
        let savedAudioFile = viewModel.saveRecording(
            title: "録音 2026年04月03日 19:00",
            fileURL: url,
            duration: 125,
            projectID: UUID()
        )

        #expect(savedAudioFile != nil)
        #expect(repository.savedFiles.count == 1)
        #expect(repository.savedFiles[0].title == "録音 2026年04月03日 19:00")
        #expect(repository.savedFiles[0].audioURL == url.path)
        #expect(repository.savedFiles[0].duration == 125)
        #expect(savedAudioFile?.id == repository.savedFiles[0].id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("saveRecording が repository エラーを画面表示用メッセージに変換する")
    func saveRecordingFailure() {
        let repository = MockRecordingAudioFileRepository(saveError: NSError(domain: "SaveTest", code: 1))
        let viewModel = RecordingViewModel()

        viewModel.configure(audioFileRepository: repository)
        let savedAudioFile = viewModel.saveRecording(
            title: "失敗",
            fileURL: URL(fileURLWithPath: "/tmp/fail.m4a"),
            duration: 10,
            projectID: nil
        )

        #expect(savedAudioFile == nil)
        #expect(viewModel.errorMessage?.contains("保存エラー") == true)
        #expect(viewModel.errorMessage?.contains("SaveTest") == true)
    }
}

private final class MockRecordingAudioFileRepository: AudioFileRepositoryProtocol {
    var files: [AudioFile] = []
    var savedFiles: [AudioFile] = []
    let saveError: Error?

    init(saveError: Error? = nil) {
        self.saveError = saveError
    }

    func fetchAll() throws -> [AudioFile] {
        files
    }

    func fetch(id: UUID) throws -> AudioFile? {
        files.first(where: { $0.id == id })
    }

    func save(_ file: AudioFile) throws {
        if let saveError {
            throw saveError
        }

        savedFiles.append(file)
        files.append(file)
    }

    func delete(_ file: AudioFile) throws {
        files.removeAll(where: { $0.id == file.id })
    }

    func delete(id: UUID) throws {
        files.removeAll(where: { $0.id == id })
    }

    func fetchByProject(_ projectId: UUID) throws -> [AudioFile] {
        files.filter { $0.projectID == projectId }
    }

    func fetchTranscribed() throws -> [AudioFile] {
        files.filter(\.isTranscribed)
    }

    func search(query: String) throws -> [AudioFile] {
        files.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
