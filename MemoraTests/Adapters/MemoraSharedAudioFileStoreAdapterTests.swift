import Foundation
import Testing
@testable import Memora
@testable import MemoraSharedData

@Suite("Memora shared audio file adapter")
struct MemoraSharedAudioFileStoreAdapterTests {
    @Test("AudioFile の全フィールドを共有レコードへ変換する")
    func mapsAudioFileToSharedRecord() throws {
        let id = UUID()
        let projectID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_234)
        let file = AudioFile(title: "週次レビュー", audioURL: "/tmp/review.m4a", projectID: projectID)
        file.id = id
        file.createdAt = createdAt
        file.duration = 98.5
        file.isTranscribed = true
        file.isSummarized = true
        file.summary = "決定事項を確認した"

        let repository = AdapterTestAudioFileRepository(files: [file])
        let adapter = MemoraSharedAudioFileStoreAdapter(repository: repository)

        let fetched = try adapter.fetch(id: id)
        let record = try #require(fetched)
        #expect(record.id == id)
        #expect(record.title == "週次レビュー")
        #expect(record.projectID == projectID)
        #expect(record.createdAt == createdAt)
        #expect(record.duration == 98.5)
        #expect(record.audioURL == "/tmp/review.m4a")
        #expect(record.isTranscribed)
        #expect(record.isSummarized)
        #expect(record.summary == "決定事項を確認した")
    }

    @Test("共有レコードの保存は既存更新と新規作成を分ける")
    func savesExistingAndNewRecords() throws {
        let existingID = UUID()
        let existing = AudioFile(title: "旧タイトル", audioURL: "/tmp/old.m4a")
        existing.id = existingID
        let repository = AdapterTestAudioFileRepository(files: [existing])
        let adapter = MemoraSharedAudioFileStoreAdapter(repository: repository)

        let fetched = try adapter.fetch(id: existingID)
        var updated = try #require(fetched)
        updated.title = "新タイトル"
        updated.isSummarized = true
        updated.summary = "更新済み"
        try adapter.save(updated)

        #expect(repository.files.count == 1)
        #expect(repository.files[0].id == existingID)
        #expect(repository.files[0].title == "新タイトル")
        #expect(repository.files[0].isSummarized)
        #expect(repository.files[0].summary == "更新済み")

        let newID = UUID()
        let newRecord = MemoraSharedAudioFileRecord(
            id: newID,
            title: "新規録音",
            createdAt: Date(timeIntervalSince1970: 2_000),
            duration: 12,
            audioURL: "/tmp/new.m4a"
        )
        try adapter.save(newRecord)

        #expect(repository.files.count == 2)
        #expect(repository.files.contains { $0.id == newID && $0.title == "新規録音" })
    }

    @Test("共有ストアの削除は対象 ID を repository に渡す")
    func deletesByID() throws {
        let id = UUID()
        let file = AudioFile(title: "削除対象", audioURL: "/tmp/delete.m4a")
        file.id = id
        let repository = AdapterTestAudioFileRepository(files: [file])
        let adapter = MemoraSharedAudioFileStoreAdapter(repository: repository)

        try adapter.delete(id: id)

        #expect(repository.deletedIDs == [id])
        #expect(repository.files.isEmpty)
    }
}

private final class AdapterTestAudioFileRepository: AudioFileRepositoryProtocol {
    var files: [AudioFile]
    var deletedIDs: [UUID] = []

    init(files: [AudioFile]) {
        self.files = files
    }

    func fetchAll() throws -> [AudioFile] { files }

    func fetchPage(offset: Int, limit: Int) throws -> [AudioFile] {
        Array(files.dropFirst(max(0, offset)).prefix(max(0, limit)))
    }

    func fetch(id: UUID) throws -> AudioFile? {
        files.first { $0.id == id }
    }

    func save(_ file: AudioFile) throws {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
        } else {
            files.append(file)
        }
    }

    func delete(_ file: AudioFile) throws {
        try delete(id: file.id)
    }

    func delete(id: UUID) throws {
        deletedIDs.append(id)
        files.removeAll { $0.id == id }
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
