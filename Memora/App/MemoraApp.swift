import SwiftUI
import SwiftData

@main
struct MemoraApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var isLoading = true
    @State private var isUsingTemporaryStore = false
    @State private var showDebugLog = false
    @State private var errorMessage: String?
    @State private var loadingMessage = "データを準備中..."
    @State private var canResetPersistentStore = false
    @State private var hasLoggedStart = false
    @State private var hasStartedInitialLoad = false
    @State private var loadAttemptToken = UUID()

    private static let tempStoreFlagKey = "didUseTemporaryStoreLastSession"

    nonisolated private static let schema = Schema([
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self
    ])

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    loadingView
                } else if let container = modelContainer {
                    ZStack {
                        ContentView()
                            .modelContainer(container)

                        if isUsingTemporaryStore {
                            temporaryStoreBanner
                        }
                    }
                } else if let error = errorMessage {
                    errorView(error)
                }
            }
            .task {
                // アプリ起動開始を記録
                if !hasLoggedStart {
                    DebugLogger.shared.markAppStart()
                    hasLoggedStart = true

                    // 前回セッションが一時ストアだった場合、データ消失の可能性を警告
                    if UserDefaults.standard.bool(forKey: Self.tempStoreFlagKey) {
                        DebugLogger.shared.addLog("ModelContainer", "前回セッションは一時ストアで起動していました。前回の変更は保持されていません。", level: .warning)
                        UserDefaults.standard.set(false, forKey: Self.tempStoreFlagKey)
                    }
                }
                guard !hasStartedInitialLoad else { return }
                hasStartedInitialLoad = true
                await loadModelContainer()
            }
            .sheet(isPresented: $showDebugLog) {
                NavigationStack {
                    DebugLogView()
                }
            }
        }
    }

    private var temporaryStoreBanner: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                Text("一時モードで起動中です。この起動中の変更は保持されません。")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .padding(.top, 8)

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 21) {
            ProgressView()
                .tint(.blue)

            Text(loadingMessage)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("初回起動時は時間がかかる場合があります")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: {
                showDebugLog = true
            }) {
                Text("デバッグログ")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 21) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundStyle(.red)

            Text("起動エラー")
                .font(.headline)
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                Task {
                    await loadModelContainer()
                }
            }) {
                Text("再試行")
            }
            .buttonStyle(.borderedProminent)

            if canResetPersistentStore {
                Button(action: {
                    Task {
                        await loadModelContainer(resetStore: true)
                    }
                }) {
                    Text("ローカルデータをリセット")
                }
                .buttonStyle(.bordered)
            }

            Button(action: {
                Task {
                    await loadModelContainer(useInMemoryStore: true)
                }
            }) {
                Text("一時モードで開く")
            }
            .buttonStyle(.bordered)

            Button(action: {
                showDebugLog = true
            }) {
                Text("デバッグログ")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
    }

    private func loadModelContainer(resetStore: Bool = false, useInMemoryStore: Bool = false) async {
        let alreadyLoaded = await MainActor.run {
            modelContainer != nil
        }
        if alreadyLoaded && !resetStore && !useInMemoryStore {
            return
        }

        let attemptToken = UUID()
        await MainActor.run {
            loadAttemptToken = attemptToken
            isLoading = true
            errorMessage = nil
            if !useInMemoryStore {
                isUsingTemporaryStore = false
            }
            canResetPersistentStore = !useInMemoryStore
            loadingMessage = useInMemoryStore
                ? "一時モードを準備しています..."
                : (resetStore ? "ローカルデータをリセットして再初期化しています..." : "データを準備中...")
        }

        let storeMode = useInMemoryStore ? "一時ストア" : (resetStore ? "永続ストア(リセット)" : "永続ストア")
        DebugLogger.shared.addLog("ModelContainer", "\(storeMode) 初期化開始", level: .info)

        let loadTask = Task.detached(priority: .userInitiated) { () -> Result<(container: ModelContainer, recovered: Bool), Error> in
            do {
                return Result.success((try Self.createModelContainer(resetStore: resetStore, inMemoryOnly: useInMemoryStore), false))
            } catch {
                guard !resetStore, !useInMemoryStore else {
                    return Result.failure(error)
                }

                do {
                    return Result.success((try Self.createModelContainer(resetStore: true), true))
                } catch {
                    return Result.failure(error)
                }
            }
        }

        let outcome = await Self.awaitModelContainerOutcome(
            from: loadTask,
            timeoutNanoseconds: useInMemoryStore ? nil : 5_000_000_000
        )

        let shouldApplyResult = await MainActor.run {
            loadAttemptToken == attemptToken
        }
        guard shouldApplyResult else { return }

        switch outcome {
        case .completed(let result):
            switch result {
            case .success(let success):
                await MainActor.run {
                    self.modelContainer = success.container
                    self.isUsingTemporaryStore = useInMemoryStore
                    self.isLoading = false
                    self.loadingMessage = "データを準備中..."
                }
                if useInMemoryStore {
                    DebugLogger.shared.addLog("ModelContainer", "一時ストアで起動 — このセッションの変更は保存されません", level: .warning)
                    UserDefaults.standard.set(true, forKey: Self.tempStoreFlagKey)
                } else {
                    DebugLogger.shared.markModelContainerReady()
                    DebugLogger.shared.markAppReady()
                }
                if success.recovered {
                    DebugLogger.shared.addLog("ModelContainer", "ストアを再作成して復旧しました", level: .warning)
                } else if !useInMemoryStore {
                    DebugLogger.shared.addLog("ModelContainer", "準備完了", level: .info)
                }
            case .failure(let error):
                DebugLogger.shared.addLog("ModelContainer", "\(storeMode) 初期化失敗: \(error.localizedDescription)", level: .error)
                await MainActor.run {
                    self.errorMessage = useInMemoryStore
                        ? "一時ストアの作成に失敗しました: \(error.localizedDescription)"
                        : "ModelContainer の作成に失敗しました: \(error.localizedDescription)"
                    self.canResetPersistentStore = !useInMemoryStore
                    self.isLoading = false
                }
            }
        case .timedOut:
            loadTask.cancel()
            DebugLogger.shared.addLog("ModelContainer", "初期化タイムアウト（5秒）", level: .warning)
            DebugLogger.shared.addLog("ModelContainer", "永続ストアを諦めて一時ストアへフォールバックします", level: .warning)

            let fallbackResult = await Task.detached(priority: .userInitiated) {
                Result { try Self.createModelContainer(inMemoryOnly: true) }
            }.value

            switch fallbackResult {
            case .success(let fallbackContainer):
                await MainActor.run {
                    self.modelContainer = fallbackContainer
                    self.isUsingTemporaryStore = true
                    self.canResetPersistentStore = true
                    self.errorMessage = nil
                    self.isLoading = false
                    self.loadingMessage = "データを準備中..."
                }
                DebugLogger.shared.addLog("ModelContainer", "一時ストアで自動復旧しました — このセッションの変更は保存されません", level: .warning)
                UserDefaults.standard.set(true, forKey: Self.tempStoreFlagKey)
                DebugLogger.shared.markAppReady()
            case .failure(let error):
                DebugLogger.shared.addLog("ModelContainer", "一時ストアへのフォールバック失敗: \(error.localizedDescription)", level: .error)
                await MainActor.run {
                    self.errorMessage = "データベースの初期化が完了しません。一時モードにも切り替えられませんでした: \(error.localizedDescription)"
                    self.canResetPersistentStore = true
                    self.isLoading = false
                }
            }
        }
    }

    nonisolated private static func createModelContainer(resetStore: Bool = false, inMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemoryOnly {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true, cloudKitDatabase: .none)
        } else {
            let storeURL = try persistentStoreURL()
            if resetStore {
                try removePersistentStore(at: storeURL)
            }
            configuration = ModelConfiguration(url: storeURL, allowsSave: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    nonisolated private static func persistentStoreURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("Memora", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        return directoryURL.appendingPathComponent("Memora.store")
    }

    nonisolated private static func removePersistentStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let sidecars = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        for url in sidecars where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private enum ModelContainerLoadOutcome {
        case completed(Result<(container: ModelContainer, recovered: Bool), Error>)
        case timedOut
    }

    nonisolated private static func awaitModelContainerOutcome(
        from loadTask: Task<Result<(container: ModelContainer, recovered: Bool), Error>, Never>,
        timeoutNanoseconds: UInt64?
    ) async -> ModelContainerLoadOutcome {
        guard let timeoutNanoseconds else {
            return .completed(await loadTask.value)
        }

        return await withTaskGroup(of: ModelContainerLoadOutcome.self) { group in
            group.addTask {
                .completed(await loadTask.value)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return .timedOut
            }

            let firstOutcome = await group.next() ?? .timedOut
            group.cancelAll()
            return firstOutcome
        }
    }
}
