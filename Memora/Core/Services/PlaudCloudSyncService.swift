import Foundation
import SwiftData

@MainActor
final class PlaudCloudSyncService {
    struct Result: Sendable, Equatable {
        let importedCount: Int
        let skippedCount: Int
        let failedCount: Int
    }

    private let modelContext: ModelContext
    private let authService: PlaudMCPOAuthService
    private let ledger: PlaudCloudSyncLedger

    init(
        modelContext: ModelContext,
        authService: PlaudMCPOAuthService? = nil,
        ledger: PlaudCloudSyncLedger = .init()
    ) {
        self.modelContext = modelContext
        self.authService = authService ?? PlaudMCPOAuthService()
        self.ledger = ledger
    }

    func sync() async throws -> Result {
        try await authService.refreshIfNeeded()
        let accessToken = KeychainService.load(key: .plaudMCPAccessToken)
        guard !accessToken.isEmpty else {
            throw PlaudMCPToolError(message: "PLAUDに接続してから同期してください")
        }

        let client = PlaudMCPClient(accessToken: accessToken)
        let lastSyncAt = ledger.lastSuccessfulSyncAt
        let files = try await client.listFiles(since: Self.overlapStart(lastSyncAt))
        var importedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for file in files {
            try Task.checkCancellation()
            guard !ledger.contains(remoteID: file.id) else {
                skippedCount += 1
                continue
            }
            do {
                let detailedFile = try await client.getFile(id: file.id)
                let audioFile = try await importFile(detailedFile)
                ledger.recordSuccess(
                    remoteID: detailedFile.id,
                    localAudioFileID: audioFile.id.uuidString,
                    createdAt: detailedFile.createdAt ?? detailedFile.startAt
                )
                importedCount += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                ledger.recordFailure(remoteID: file.id, message: error.localizedDescription)
                failedCount += 1
            }
        }
        ledger.markSuccessfulSync(at: Date())
        try ledger.save()
        return Result(importedCount: importedCount, skippedCount: skippedCount, failedCount: failedCount)
    }

    private func importFile(_ file: PlaudMCPFile) async throws -> AudioFile {
        guard let presignedURL = file.presignedURL else {
            throw PlaudMCPToolError(message: "「\(file.name)」の音声ダウンロードURLがありません")
        }
        let temporaryURL = try await downloadAudio(from: presignedURL, remoteID: file.id)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let audioFile = try AudioFileImportService.importAudio(
            from: temporaryURL,
            suggestedTitle: file.name,
            modelContext: modelContext
        )
        audioFile.sourceType = .plaudCloud
        audioFile.createdAt = file.createdAt ?? file.startAt ?? audioFile.createdAt
        if let duration = file.durationMilliseconds, duration > 0 {
            audioFile.duration = duration / 1_000
        }
        let transcript = file.sourceList
            .map(\.formattedLine)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        if !transcript.isEmpty {
            audioFile.referenceTranscript = transcript
            audioFile.referenceSpeakerCount = Set(file.sourceList.compactMap(\.speaker)).count
        }
        let note = file.noteList.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            audioFile.summary = note
            audioFile.isSummarized = true
        }
        try modelContext.save()
        return audioFile
    }

    private func downloadAudio(from url: URL, remoteID: String) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        let (temporaryURL, response) = try await URLSession.plaudAudioDownload.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PlaudMCPToolError(message: "PLAUD音声のダウンロードに失敗しました")
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("plaud-\(remoteID)-\(UUID().uuidString).m4a")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private static func overlapStart(_ date: Date?) -> Date? {
        date.map { Calendar.current.date(byAdding: .hour, value: -24, to: $0) ?? $0 }
    }
}

private extension URLSession {
    static let plaudAudioDownload: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
}

final class PlaudCloudSyncLedger {
    private struct Storage: Codable {
        var lastSuccessfulSyncAt: Date?
        var records: [Record]
    }

    struct Record: Codable, Equatable {
        let remoteID: String
        let localAudioFileID: String?
        let createdAt: Date?
        let lastError: String?
        let updatedAt: Date
    }

    private let storageURL: URL
    private var storage: Storage

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        self.storage = (try? Self.load(from: self.storageURL)) ?? Storage(lastSuccessfulSyncAt: nil, records: [])
    }

    var lastSuccessfulSyncAt: Date? { storage.lastSuccessfulSyncAt }

    func contains(remoteID: String) -> Bool {
        storage.records.contains { $0.remoteID == remoteID && $0.localAudioFileID != nil }
    }

    func recordSuccess(remoteID: String, localAudioFileID: String, createdAt: Date?) {
        upsert(.init(remoteID: remoteID, localAudioFileID: localAudioFileID, createdAt: createdAt, lastError: nil, updatedAt: Date()))
    }

    func recordFailure(remoteID: String, message: String) {
        upsert(.init(remoteID: remoteID, localAudioFileID: nil, createdAt: nil, lastError: message, updatedAt: Date()))
    }

    func markSuccessfulSync(at date: Date) {
        storage.lastSuccessfulSyncAt = date
    }

    func save() throws {
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(storage)
        try data.write(to: storageURL, options: .atomic)
    }

    private func upsert(_ record: Record) {
        if let index = storage.records.firstIndex(where: { $0.remoteID == record.remoteID }) {
            storage.records[index] = record
        } else {
            storage.records.append(record)
        }
    }

    private static func defaultStorageURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("Memora", isDirectory: true)
            .appendingPathComponent("PlaudCloudSync", isDirectory: true)
            .appendingPathComponent("ledger.json")
    }

    private static func load(from url: URL) throws -> Storage {
        try JSONDecoder().decode(Storage.self, from: Data(contentsOf: url))
    }
}
