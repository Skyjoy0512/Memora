import Testing
import Security
import Foundation
import SwiftData
@testable import Memora

struct LocalDataDeletionServiceCoverageTests {
    private enum InjectedError: Error { case removalFailed }
    @Test
    @MainActor
    func 削除対象はSwiftDataスキーマの全22モデルを網羅する() {
        let expected: Set<String> = [
            "AudioFile", "Transcript", "Project", "MeetingNote", "MeetingMemo", "PhotoAttachment",
            "KnowledgeChunk", "AskAISession", "AskAIMessage", "MemoryProfile", "MemoryFact", "TodoItem",
            "ProcessingJob", "WebhookSettings", "PlaudSettings", "CalendarEventLink", "GoogleMeetSettings",
            "NotionSettings", "CustomSummaryTemplate", "OnlineMeetingCapture", "BotMeetingConfig", "ScheduledBotMeeting"
        ]
        #expect(Set(LocalDataDeletionService.swiftDataModelNames) == expected)
        #expect(LocalDataDeletionService.swiftDataModelNames.count == 22)
    }

    @Test
    func Keychain削除は未登録を成功として扱い実エラーを報告可能にする() {
        #expect(LocalDataDeletionService.isSuccessfulKeychainDeletion(errSecSuccess))
        #expect(LocalDataDeletionService.isSuccessfulKeychainDeletion(errSecItemNotFound))
        #expect(!LocalDataDeletionService.isSuccessfulKeychainDeletion(errSecAuthFailed))
    }

    @Test
    func 管理対象ディレクトリ内だけをファイル削除対象にする() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalDataDeletionTests-\(UUID().uuidString)", isDirectory: true)
        let managed = root.appendingPathComponent("Documents/recording.m4a")
        let outside = root.appendingPathComponent("DocumentsBackup/keep.m4a")

        #expect(LocalDataDeletionService.isManagedFile(managed, allowedRootPaths: [root.appendingPathComponent("Documents").path]))
        #expect(!LocalDataDeletionService.isManagedFile(outside, allowedRootPaths: [root.appendingPathComponent("Documents").path]))
        #expect(!LocalDataDeletionService.isManagedFile(root.appendingPathComponent("Documents"), allowedRootPaths: [root.appendingPathComponent("Documents").path]))
    }

    @Test
    func 一時ディレクトリのメディアとJSONを削除し対象外ファイルを保持する() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let appSupport = root.appendingPathComponent("ApplicationSupport", isDirectory: true)
        let audio = documents.appendingPathComponent("recording.m4a")
        let photo = documents.appendingPathComponent("photo.jpg")
        let json = appSupport.appendingPathComponent("TranscriptionCheckpoints", isDirectory: true)
        let outside = root.appendingPathComponent("outside.m4a")
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: json, withIntermediateDirectories: true)
        try Data().write(to: audio); try Data().write(to: photo)
        try Data().write(to: json.appendingPathComponent("checkpoint.json")); try Data().write(to: outside)

        let result = LocalDataFileDeletionService(allowedRootPaths: [documents.path, appSupport.path])
            .delete(paths: [audio.path, photo.path], jsonDirectories: [json])
        #expect(result.isComplete)
        #expect(!FileManager.default.fileExists(atPath: audio.path))
        #expect(!FileManager.default.fileExists(atPath: photo.path))
        #expect(!FileManager.default.fileExists(atPath: json.path))
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test
    func 削除失敗を部分失敗として返す() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Documents/recording.m4a")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        let result = LocalDataFileDeletionService(
            allowedRootPaths: [root.appendingPathComponent("Documents").path],
            removeItem: { _ in throw InjectedError.removalFailed }
        ).delete(paths: [file.path], jsonDirectories: [])
        #expect(!result.isComplete)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test @MainActor
    func 全22SwiftDataモデルを削除する() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: MemoraSchemaV3.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let id = UUID()
        context.insert(AudioFile(title: "fixture", audioURL: "")); context.insert(Transcript(audioFileID: id, text: "t")); context.insert(Project(title: "p")); context.insert(MeetingNote(audioFileID: id)); context.insert(MeetingMemo(audioFileID: id)); context.insert(PhotoAttachment(ownerType: .audioFile, ownerID: id, localPath: "")); context.insert(KnowledgeChunk(scopeType: .global, sourceType: .memo, text: "k")); context.insert(AskAISession(scopeType: .global, title: "a")); context.insert(AskAIMessage(sessionID: id, role: .user, content: "m")); context.insert(MemoryProfile()); context.insert(MemoryFact(profileID: id, key: "k", value: "v", source: "t")); context.insert(TodoItem(title: "todo")); context.insert(ProcessingJob(audioFileID: id, jobType: "t")); context.insert(WebhookSettings()); context.insert(PlaudSettings()); context.insert(CalendarEventLink(provider: "p", externalID: "e", title: "t", startAt: .now, endAt: .now)); context.insert(GoogleMeetSettings()); context.insert(NotionSettings()); context.insert(CustomSummaryTemplate(name: "n", prompt: "p", outputSections: [])); context.insert(OnlineMeetingCapture(platform: "p", meetingTitle: "m")); context.insert(BotMeetingConfig()); context.insert(ScheduledBotMeeting(platform: "p", meetingURL: "u", meetingTitle: "m", scheduledTime: .now))
        try context.save()
        let result = LocalDataDeletionService(context: context).deleteAll()
        #expect(!result.failures.contains { $0.hasPrefix("SwiftData:") })
        #expect(try context.fetchCount(FetchDescriptor<AudioFile>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ScheduledBotMeeting>()) == 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
