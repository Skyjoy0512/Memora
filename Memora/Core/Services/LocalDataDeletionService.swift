import Foundation
import SwiftData
import Security
import MemoraSharedData

struct LocalDataFileDeletionService {
    struct Result {
        var failures: [String] = []
        var isComplete: Bool { failures.isEmpty }
    }

    let fileManager: FileManager
    let allowedRootPaths: [String]
    let removeItem: (URL) throws -> Void

    init(
        fileManager: FileManager = .default,
        allowedRootPaths: [String],
        removeItem: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) {
        self.fileManager = fileManager
        self.allowedRootPaths = allowedRootPaths
        self.removeItem = removeItem
    }

    func delete(paths: [String], jsonDirectories: [URL]) -> Result {
        var result = Result()
        for path in Set(paths) where !path.isEmpty {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard LocalDataDeletionService.isManagedFile(url, allowedRootPaths: allowedRootPaths) else {
                result.failures.append("対象外ファイルを保護: \(url.lastPathComponent)")
                continue
            }
            removeIfPresent(url, result: &result)
        }
        for directory in jsonDirectories where fileManager.fileExists(atPath: directory.path) {
            removeIfPresent(directory, result: &result)
        }
        return result
    }

    private func removeIfPresent(_ url: URL, result: inout Result) {
        do { try removeItem(url) }
        catch { result.failures.append("ファイル \(url.lastPathComponent): \(error.localizedDescription)") }
    }
}

@MainActor
struct LocalDataDeletionService {
    /// 削除対象は `MemoraSchemaV3.models` と同期させる。テストでも網羅性を検証する。
    static let swiftDataModelNames = [
        "AudioFile", "Transcript", "Project", "MeetingNote", "MeetingMemo", "PhotoAttachment",
        "KnowledgeChunk", "AskAISession", "AskAIMessage", "MemoryProfile", "MemoryFact", "TodoItem",
        "ProcessingJob", "WebhookSettings", "PlaudSettings", "CalendarEventLink", "GoogleMeetSettings",
        "NotionSettings", "CustomSummaryTemplate", "OnlineMeetingCapture", "BotMeetingConfig", "ScheduledBotMeeting"
    ]

    struct Result {
        var deletedCategories: [String] = []
        var failures: [String] = []
        var isComplete: Bool { failures.isEmpty }
    }

    let context: ModelContext
    let fileManager: FileManager

    init(context: ModelContext, fileManager: FileManager = .default) {
        self.context = context
        self.fileManager = fileManager
    }

    func deleteAll() -> Result {
        var result = Result()
        let mediaPaths = collectedMediaPaths()
        deleteModels(into: &result)
        deleteFiles(mediaPaths, into: &result)
        clearSettings(into: &result)
        clearKeychain(into: &result)
        return result
    }

    private func deleteModels(into result: inout Result) {
        do {
            // 子・連携・設定を先に削除し、関係制約を安全に解除する。
            try context.delete(model: Transcript.self); try context.delete(model: PhotoAttachment.self)
            try context.delete(model: KnowledgeChunk.self); try context.delete(model: ProcessingJob.self)
            try context.delete(model: CalendarEventLink.self); try context.delete(model: AskAIMessage.self)
            try context.delete(model: AskAISession.self); try context.delete(model: MemoryFact.self)
            try context.delete(model: MemoryProfile.self); try context.delete(model: MeetingNote.self)
            try context.delete(model: MeetingMemo.self); try context.delete(model: TodoItem.self)
            try context.delete(model: WebhookSettings.self); try context.delete(model: PlaudSettings.self)
            try context.delete(model: GoogleMeetSettings.self); try context.delete(model: NotionSettings.self)
            try context.delete(model: CustomSummaryTemplate.self); try context.delete(model: OnlineMeetingCapture.self)
            try context.delete(model: BotMeetingConfig.self); try context.delete(model: ScheduledBotMeeting.self)
            try context.delete(model: AudioFile.self); try context.delete(model: Project.self)
            try context.save()
            result.deletedCategories.append("SwiftDataの全22モデル")
        } catch { result.failures.append("SwiftData: \(error.localizedDescription)") }
    }

    private func collectedMediaPaths() -> [String] {
        let audio = (try? context.fetch(FetchDescriptor<AudioFile>())) ?? []
        let photos = (try? context.fetch(FetchDescriptor<PhotoAttachment>())) ?? []
        return audio.flatMap { [$0.audioURL] + $0.segmentPaths }
            + photos.flatMap { [$0.localPath, $0.thumbnailPath].compactMap { $0 } }
    }

    private func deleteFiles(_ paths: [String], into result: inout Result) {
        let allowedRoots = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ].compactMap { $0?.standardizedFileURL.path }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let jsonDirectories = ["Memora/TranscriptionCheckpoints", "Memora/PlaudCloudSync"]
            .compactMap { appSupport?.appendingPathComponent($0) }
        let fileResult = LocalDataFileDeletionService(
            fileManager: fileManager,
            allowedRootPaths: allowedRoots,
            removeItem: { try fileManager.removeItem(at: $0) }
        ).delete(paths: paths, jsonDirectories: jsonDirectories)
        result.failures.append(contentsOf: fileResult.failures)
        result.deletedCategories.append("音声・写真・ネイティブJSON")
    }

    private func clearSettings(into result: inout Result) {
        if let bundleID = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundleID) }
        if let group = UserDefaults(suiteName: MemoraSharedStoreLocation.primaryAppGroupIdentifier) { group.removePersistentDomain(forName: MemoraSharedStoreLocation.primaryAppGroupIdentifier) }
        result.deletedCategories.append("このアプリとApp Groupの設定")
    }

    private func clearKeychain(into result: inout Result) {
        var failures = [String]()
        for key in KeychainService.Key.allCases {
            let status = KeychainService.delete(key: key)
            guard Self.isSuccessfulKeychainDeletion(status) else {
                failures.append("\(key.rawValue) (OSStatus \(status))")
                continue
            }
        }
        if failures.isEmpty {
            result.deletedCategories.append("Keychain認証情報")
        } else {
            result.failures.append("Keychain: \(failures.joined(separator: ", "))")
        }
    }

    nonisolated static func isSuccessfulKeychainDeletion(_ status: OSStatus) -> Bool {
        status == errSecSuccess || status == errSecItemNotFound
    }

    nonisolated static func isManagedFile(_ url: URL, allowedRootPaths: [String]) -> Bool {
        let path = url.standardizedFileURL.path
        return allowedRootPaths.contains { root in
            let normalizedRoot = URL(fileURLWithPath: root).standardizedFileURL.path
            return path.hasPrefix(normalizedRoot + "/")
        }
    }
}
