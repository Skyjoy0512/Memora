import Foundation

/// 永続ストアの明示的なリセットだけを扱う。起動失敗時には使用しない。
struct PersistentStoreSafetyService {
    enum ResetError: LocalizedError {
        case backupFailed(Error)

        var errorDescription: String? {
            switch self {
            case .backupFailed(let error):
                "バックアップを作成できなかったため、データは削除されませんでした: \(error.localizedDescription)"
            }
        }
    }

    let fileManager: FileManager
    let backupRootURL: URL

    init(fileManager: FileManager = .default, backupRootURL: URL) {
        self.fileManager = fileManager
        self.backupRootURL = backupRootURL
    }

    /// store, WAL, SHM を退避できた場合に限り削除する。
    @discardableResult
    func backupThenRemoveStore(at storeURL: URL) throws -> URL? {
        let files = storeFiles(for: storeURL).filter { fileManager.fileExists(atPath: $0.path) }
        guard !files.isEmpty else { return nil }

        let backupURL = backupRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
            for source in files {
                try fileManager.copyItem(at: source, to: backupURL.appendingPathComponent(source.lastPathComponent))
            }
        } catch {
            try? fileManager.removeItem(at: backupURL)
            throw ResetError.backupFailed(error)
        }

        for file in files {
            try fileManager.removeItem(at: file)
        }
        return backupURL
    }

    func storeFiles(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
    }
}

/// 子タスクのキャンセル完了を待たず、期限到達時に呼び出し元へ戻すための競合ヘルパー。
enum ModelContainerLoadTimeout {
    static func race<Value: Sendable>(
        operation: @escaping @Sendable () async -> Value,
        timeoutNanoseconds: UInt64
    ) async -> Value? {
        await withCheckedContinuation { continuation in
            let gate = ContinuationGate(continuation)
            Task {
                gate.resume(await operation())
            }
            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                gate.resume(nil)
            }
        }
    }

    private final class ContinuationGate<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Value?, Never>?

        init(_ continuation: CheckedContinuation<Value?, Never>) {
            self.continuation = continuation
        }

        func resume(_ value: Value?) {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(returning: value)
        }
    }
}
