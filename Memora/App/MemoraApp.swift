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
    @State private var temporaryStoreReason: String?

    private static let tempStoreFlagKey = "didUseTemporaryStoreLastSession"

    nonisolated private static let schema = Schema([
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        KnowledgeChunk.self,
        AskAISession.self,
        AskAIMessage.self,
        MemoryProfile.self,
        MemoryFact.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self,
        CalendarEventLink.self,
        GoogleMeetSettings.self,
        NotionSettings.self
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
                DebugLogger.shared.markLaunchStep("loadModelContainer 開始")
                await loadModelContainer()
                DebugLogger.shared.markLaunchStep("loadModelContainer 完了")
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
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("一時モードで起動中")
                        .font(.subheadline.bold())
                    Text(temporaryStoreReason ?? "このセッションの変更は保存されません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await loadModelContainer() }
                } label: {
                    Text("再試行")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
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
            DebugLogger.shared.markLaunchStep("Task.detached: ModelContainer 生成開始")
            do {
                let container = try Self.createModelContainer(resetStore: resetStore, inMemoryOnly: useInMemoryStore)
                DebugLogger.shared.markLaunchStep("Task.detached: ModelContainer 生成成功")
                return Result.success((container, false))
            } catch {
                guard !resetStore, !useInMemoryStore else {
                    return Result.failure(error)
                }

                do {
                    let container = try Self.createModelContainer(resetStore: true)
                    DebugLogger.shared.markLaunchStep("Task.detached: ModelContainer リセット生成成功")
                    return Result.success((container, true))
                } catch {
                    return Result.failure(error)
                }
            }
        }

        // ストアファイル有無でタイムアウトを適応化
        // 初回起動（ファイルなし）は DB 新規作成に時間がかかるため長めに設定
        let storeExists = (try? Self.persistentStoreURL()).flatMap { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let adaptiveTimeout: UInt64 = storeExists ? 8_000_000_000 : 15_000_000_000
        let timeoutNanoseconds = useInMemoryStore ? nil as UInt64? : adaptiveTimeout
        DebugLogger.shared.addLog("ModelContainer", "タイムアウト設定: \(storeExists ? "8s（既存ストア）" : "15s（初回/新規）")", level: .info)

        DebugLogger.shared.markLaunchStep("awaitModelContainerOutcome 開始")
        let outcome = await Self.awaitModelContainerOutcome(
            from: loadTask,
            timeoutNanoseconds: timeoutNanoseconds
        )
        DebugLogger.shared.markLaunchStep("awaitModelContainerOutcome 完了")

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
                    self.temporaryStoreReason = useInMemoryStore ? "一時モードで起動しています" : nil
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
            DebugLogger.shared.addLog("ModelContainer", "初期化タイムアウト（\(storeExists ? "8秒" : "15秒")）", level: .warning)
            DebugLogger.shared.addLog("ModelContainer", "永続ストアを諦めて一時ストアへフォールバックします", level: .warning)
            DebugLogger.shared.markLaunchStep("タイムアウト → 一時ストアフォールバック開始")

            let fallbackResult = await Task.detached(priority: .userInitiated) {
                Result { try Self.createModelContainer(inMemoryOnly: true) }
            }.value
            DebugLogger.shared.markLaunchStep("一時ストアフォールバック完了")

            switch fallbackResult {
            case .success(let fallbackContainer):
                await MainActor.run {
                    self.modelContainer = fallbackContainer
                    self.isUsingTemporaryStore = true
                    self.temporaryStoreReason = "初期化タイムアウトのため一時モードに切り替わりました"
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
        let containerStart = ContinuousClock.now

        let configuration: ModelConfiguration
        if inMemoryOnly {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true, cloudKitDatabase: .none)
        } else {
            let storeURL = try persistentStoreURL()
            if resetStore {
                try removePersistentStore(at: storeURL)
                DebugLogger.shared.addLog("ModelContainer", "既存ストアを削除して再作成", level: .warning)
            }
            configuration = ModelConfiguration(url: storeURL, allowsSave: true, cloudKitDatabase: .none)
        }

        DebugLogger.shared.markLaunchStep("ModelConfiguration 生成完了")

        let container = try ModelContainer(for: schema, configurations: [configuration])

        let elapsed = containerStart.duration(to: ContinuousClock.now)
        let ms = Double(elapsed.components.seconds) * 1000.0
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0
        DebugLogger.shared.addLog("ModelContainer", "createModelContainer 完了 (\(String(format: "%.0f", ms))ms)", level: .info)

        return container
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
